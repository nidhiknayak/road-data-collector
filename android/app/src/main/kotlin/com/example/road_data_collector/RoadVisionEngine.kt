package com.example.road_data_collector

import android.content.Context
import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import org.json.JSONObject
import org.opencv.android.OpenCVLoader
import org.opencv.core.Core
import org.opencv.core.CvType
import org.opencv.core.Mat
import org.opencv.core.Scalar
import org.opencv.core.Size
import org.opencv.imgproc.Imgproc
import java.io.File
import java.nio.FloatBuffer
import kotlin.math.exp
import kotlin.math.min
import kotlin.math.sqrt

/** Runs on one worker thread. Frames never leave the phone. */
class RoadVisionEngine(private val context: Context) : AutoCloseable {
    private val environment by lazy {
        android.system.Os.setenv("ORT_DISABLE_TELEMETRY", "1", true)
        OrtEnvironment.getEnvironment().also { it.setTelemetry(false) }
    }
    private var maskSession: OrtSession? = null
    private var embeddingSession: OrtSession? = null
    private lateinit var metadata: JSONObject
    private lateinit var labels: List<String>
    private lateinit var coefficients: Array<DoubleArray>
    private lateinit var intercepts: DoubleArray
    private data class Sample(val elapsedMs: Long, val vector: FloatArray)
    private val history = ArrayDeque<Sample>()

    fun initialize(): Map<String, Any> {
        if (maskSession == null || embeddingSession == null) {
            check(OpenCVLoader.initLocal()) { "Could not initialize road image processing" }
            Core.setNumThreads(1)
            metadata = JSONObject(context.assets.open("road_models/classifier.json").bufferedReader().use { it.readText() })
            val classes = metadata.getJSONArray("labels")
            labels = List(classes.length()) { classes.getString(it) }
            val weights = metadata.getJSONArray("coefficients")
            coefficients = Array(weights.length()) { c ->
                val row = weights.getJSONArray(c)
                DoubleArray(row.length()) { row.getDouble(it) }
            }
            val bias = metadata.getJSONArray("intercepts")
            intercepts = DoubleArray(bias.length()) { bias.getDouble(it) }
            require(coefficients.all { it.size == 1536 } && coefficients.size == labels.size)
            try {
                maskSession = createSession("road_mask.onnx")
                embeddingSession = createSession("road_embedding.onnx")
            } catch (error: Throwable) {
                close()
                throw error
            }
        }
        return mapOf("model_id" to metadata.getString("model_id"),
            "test_accuracy" to metadata.getDouble("test_video_accuracy"),
            "test_videos" to metadata.getInt("test_videos"), "experimental" to true)
    }

    private fun createSession(name: String): OrtSession {
        val entry = metadata.getJSONObject("export_checks").getJSONObject(name)
        val folder = File(context.cacheDir, "road_models/${entry.getString("sha256").take(20)}")
        folder.mkdirs()
        val destination = File(folder, name)
        if (!destination.exists() || destination.length() != entry.getLong("bytes")) {
            val temporary = File(folder, "$name.tmp")
            context.assets.open("road_models/$name").use { input -> temporary.outputStream().use { input.copyTo(it) } }
            check(temporary.renameTo(destination)) { "Could not prepare model storage" }
        }
        return OrtSession.SessionOptions().use { options ->
            options.setIntraOpNumThreads(2)
            options.setInterOpNumThreads(1)
            options.setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT)
            environment.createSession(destination.absolutePath, options)
        }
    }

    fun reset() { history.clear() }

    fun analyze(arguments: Map<*, *>): Map<String, Any> {
        check(maskSession != null && embeddingSession != null) { "Road model is not ready" }
        val elapsed = (arguments["elapsed_ms"] as Number).toLong()
        val view = arguments["view"] as String
        require(metadata.getJSONObject("camera_cutoffs").has(view)) { "Unknown camera position" }
        if (history.isNotEmpty() && (elapsed <= history.last().elapsedMs || elapsed-history.last().elapsedMs > 8000)) reset()
        val started = System.nanoTime()
        val bgr = decodeFrame(arguments)
        val vector = try { extract(bgr, view) } finally { bgr.release() }
        val duration = (System.nanoTime()-started)/1_000_000
        if (vector == null) {
            reset()
            return mapOf("status" to "road_not_visible", "window_start_ms" to elapsed,
                "window_end_ms" to elapsed, "valid_frames" to 0, "processing_ms" to duration)
        }
        history.addLast(Sample(elapsed, vector))
        while (history.size > 5) history.removeFirst()
        val beginning = history.first().elapsedMs
        if (history.size < 3) return mapOf("status" to "warming_up",
            "window_start_ms" to beginning, "window_end_ms" to elapsed,
            "valid_frames" to history.size, "processing_ms" to duration)
        val feature = DoubleArray(1536)
        for (j in 0 until 768) {
            val mean = history.sumOf { it.vector[j].toDouble() } / history.size
            val variance = history.sumOf { val d = it.vector[j]-mean; d*d } / history.size
            feature[j] = mean
            feature[768+j] = sqrt(variance.coerceAtLeast(0.0))
        }
        val norm = sqrt(feature.sumOf { it*it }).coerceAtLeast(1e-12)
        for (j in feature.indices) feature[j] /= norm
        val logits = DoubleArray(labels.size) { c ->
            intercepts[c] + feature.indices.sumOf { j -> feature[j]*coefficients[c][j] }
        }
        val largest = logits.maxOrNull()!!
        val probabilities = logits.map { exp(it-largest) }
        val total = probabilities.sum()
        val scores = labels.indices.associate { labels[it] to probabilities[it]/total }
        val best = labels.indices.maxBy { probabilities[it] }
        val score = probabilities[best]/total
        return mapOf("status" to if (score >= .5) "prediction" else "uncertain",
            "predicted_class" to labels[best], "score" to score, "scores" to scores,
            "window_start_ms" to beginning, "window_end_ms" to elapsed,
            "valid_frames" to history.size, "processing_ms" to duration,
            "model_id" to metadata.getString("model_id"))
    }

    private fun decodeFrame(args: Map<*, *>): Mat {
        val width = (args["width"] as Number).toInt()
        val height = (args["height"] as Number).toInt()
        require(width in 2..4096 && height in 2..4096 && width%2 == 0 && height%2 == 0)
        val planes = args["planes"] as List<*>
        val nv21 = ByteArray(width*height*3/2)
        if (planes.size == 1) {
            val bytes = (planes[0] as Map<*, *>)["bytes"] as ByteArray
            require(bytes.size >= nv21.size)
            bytes.copyInto(nv21, endIndex=nv21.size)
        } else {
            require(planes.size == 3)
            val y = planes[0] as Map<*, *>; val u = planes[1] as Map<*, *>; val v = planes[2] as Map<*, *>
            val yBytes = y["bytes"] as ByteArray
            val uBytes = u["bytes"] as ByteArray; val vBytes = v["bytes"] as ByteArray
            val yStride = (y["row_stride"] as Number).toInt()
            val uStride = (u["row_stride"] as Number).toInt(); val vStride = (v["row_stride"] as Number).toInt()
            val uPixel = (u["pixel_stride"] as Number).toInt(); val vPixel = (v["pixel_stride"] as Number).toInt()
            for (row in 0 until height) yBytes.copyInto(nv21,row*width,row*yStride,row*yStride+width)
            var cursor = width*height
            for (row in 0 until height/2) for (col in 0 until width/2) {
                nv21[cursor++] = vBytes[row*vStride+col*vPixel]
                nv21[cursor++] = uBytes[row*uStride+col*uPixel]
            }
        }
        val yuv = Mat(height+height/2,width,CvType.CV_8UC1)
        val bgr = Mat()
        try {
            yuv.put(0,0,nv21)
            Imgproc.cvtColor(yuv,bgr,Imgproc.COLOR_YUV2BGR_NV21)
            when ((args["rotation"] as Number).toInt()) {
                90 -> Core.rotate(bgr,bgr,Core.ROTATE_90_CLOCKWISE)
                180 -> Core.rotate(bgr,bgr,Core.ROTATE_180)
                270 -> Core.rotate(bgr,bgr,Core.ROTATE_90_COUNTERCLOCKWISE)
            }
            return bgr
        } catch (error: Throwable) { bgr.release(); throw error }
        finally { yuv.release() }
    }

    private fun normalize(images: List<Mat>): FloatArray {
        val height=images.first().rows(); val width=images.first().cols(); val count=height*width
        val result=FloatArray(images.size*3*count)
        val mean=floatArrayOf(.485f,.456f,.406f);val std=floatArrayOf(.229f,.224f,.225f)
        images.forEachIndexed { batch,image ->
            val bytes=ByteArray(count*3);image.get(0,0,bytes)
            for (i in 0 until count) for (channel in 0..2) {
                val pixel=(bytes[i*3+(2-channel)].toInt() and 255)/255f
                result[batch*3*count+channel*count+i]=(pixel-mean[channel])/std[channel]
            }
        }
        return result
    }

    private fun run(session: OrtSession, data: FloatArray, shape: LongArray): FloatArray {
        return OnnxTensor.createTensor(environment,FloatBuffer.wrap(data),shape).use { tensor ->
            session.run(mapOf("pixels" to tensor)).use { outputs ->
                val buffer=(outputs[0] as OnnxTensor).floatBuffer
                FloatArray(buffer.remaining()).also { buffer.get(it) }
            }
        }
    }

    private fun extract(source: Mat,view: String): FloatArray? {
        // Release all OpenCV native allocations even if an inference fails.
        val mats=mutableListOf<Mat>()
        fun mat()=Mat().also { mats.add(it) }
        try {
            val factor=min(1.0,960.0/maxOf(source.rows(),source.cols()))
            val image=mat()
            Imgproc.resize(source,image,Size(Math.rint(source.cols()*factor),Math.rint(source.rows()*factor)),0.0,0.0,Imgproc.INTER_AREA)
            val h=image.rows();val w=image.cols()
            val inferWidth=maxOf(32,Math.rint(512.0*w/maxOf(h,w)).toInt())
            val scale=min(1.0,inferWidth.toDouble()/w)
            val iw=maxOf(32,Math.rint(w*scale/32).toInt()*32)
            val ih=maxOf(32,Math.rint(h*scale/32).toInt()*32)
            val small=mat();Imgproc.resize(image,small,Size(iw.toDouble(),ih.toDouble()),0.0,0.0,Imgproc.INTER_AREA)
            val values=run(maskSession!!,normalize(listOf(small)),longArrayOf(1,3,ih.toLong(),iw.toLong()))
            require(values.size == iw*ih)
            val probability=Mat(ih,iw,CvType.CV_32FC1).also { mats.add(it) };probability.put(0,0,values)
            val full=mat();Imgproc.resize(probability,full,Size(w.toDouble(),h.toDouble()),0.0,0.0,Imgproc.INTER_LINEAR)
            val mask=mat();Core.compare(full,Scalar(.55),mask,Core.CMP_GE)
            val kernel=Mat.ones(7,7,CvType.CV_8U).also { mats.add(it) }
            Imgproc.morphologyEx(mask,mask,Imgproc.MORPH_CLOSE,kernel)
            val componentLabels=mat();val stats=mat();val centroids=mat()
            val components=Imgproc.connectedComponentsWithStats(mask,componentLabels,stats,centroids,8,CvType.CV_32S)
            val kept=Mat.zeros(h,w,CvType.CV_8U).also { mats.add(it) };val temporary=mat()
            for (c in 1 until components) if (stats.get(c,Imgproc.CC_STAT_AREA)[0]>=.002*h*w) {
                Core.compare(componentLabels,Scalar(c.toDouble()),temporary,Core.CMP_EQ)
                Core.bitwise_or(kept,temporary,kept)
            }
            val cutoff=(h*metadata.getJSONObject("camera_cutoffs").getDouble(view)).toInt()
            if (cutoff<h) kept.rowRange(cutoff,h).also { it.setTo(Scalar(0.0));it.release() }
            if (Core.countNonZero(kept)<.02*h*w) return null
            val distance=mat();Imgproc.distanceTransform(kept,distance,Imgproc.DIST_L2,5)
            var maximum=Core.minMaxLoc(distance).maxLoc
            var cx=maximum.x.toInt();var cy=maximum.y.toInt()
            fun cropRadius(): Int = minOf((distance.get(cy,cx)[0]/sqrt(2.0)).toInt(),cx,cy,w-cx-1,h-cy-1)
            var radius=cropRadius()
            if (radius<8) {
                val padded=mat();Core.copyMakeBorder(kept,padded,1,1,1,1,Core.BORDER_CONSTANT,Scalar(0.0))
                val paddedDistance=mat();Imgproc.distanceTransform(padded,paddedDistance,Imgproc.DIST_L2,5)
                paddedDistance.submat(1,h+1,1,w+1).also { it.copyTo(distance);it.release() }
                maximum=Core.minMaxLoc(distance).maxLoc;cx=maximum.x.toInt();cy=maximum.y.toInt();radius=cropRadius()
            }
            if (radius<8) return null
            val tile=mat()
            image.submat(cy-radius,cy+radius,cx-radius,cx+radius).also {
                Imgproc.resize(it,tile,Size(224.0,224.0),0.0,0.0,Imgproc.INTER_AREA);it.release()
            }
            val gray=mat();Imgproc.cvtColor(tile,gray,Imgproc.COLOR_BGR2GRAY)
            val contrast=mat();val clahe=Imgproc.createCLAHE(2.0,Size(8.0,8.0))
            try { clahe.apply(gray,contrast) } finally { clahe.collectGarbage();clahe.clear() }
            val grayRgb=mat();Imgproc.cvtColor(contrast,grayRgb,Imgproc.COLOR_GRAY2BGR)
            return run(embeddingSession!!,normalize(listOf(tile,grayRgb)),longArrayOf(2,3,224,224)).also {
                require(it.size==768 && it.all { v -> v.isFinite() })
            }
        } finally { mats.forEach { it.release() } }
    }

    override fun close() {
        reset();maskSession?.close();embeddingSession?.close();maskSession=null;embeddingSession=null
    }
}
