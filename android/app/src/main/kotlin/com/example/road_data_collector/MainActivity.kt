package com.example.road_data_collector

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Handler
import android.os.Looper
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private lateinit var vision: RoadVisionEngine
    @Volatile private var destroyed = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        vision = RoadVisionEngine(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,"road_collector/vision")
            .setMethodCallHandler { call,result ->
                if (call.method !in listOf("initialize","reset","analyze")) {
                    result.notImplemented()
                } else worker.execute {
                    try {
                        val value = when(call.method) {
                            "initialize" -> vision.initialize()
                            "reset" -> { vision.reset();null }
                            else -> vision.analyze(call.arguments as Map<*, *>)
                        }
                        main.post { if (!destroyed) result.success(value) }
                    } catch (error: Throwable) {
                        main.post { if (!destroyed) result.error("vision_error",error.message,null) }
                    }
                }
            }
    }

    override fun onDestroy() {
        destroyed=true
        if (::vision.isInitialized) worker.execute { vision.close() }
        worker.shutdown()
        super.onDestroy()
    }
}
