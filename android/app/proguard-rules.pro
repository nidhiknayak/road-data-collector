# JNI bindings must retain their Java names in the release APK.
# https://onnxruntime.ai/docs/build/android.html
-keep class ai.onnxruntime.** { *; }
-keep class org.opencv.** { *; }
