import 'package:camera/camera.dart';

class CameraService {
  CameraController? controller;

  Future<void> initialize() async {
    final cameras = await availableCameras();

    controller = CameraController(
      cameras.first,
      ResolutionPreset.veryHigh,
      enableAudio: false,
    );

    await controller!.initialize();
  }

  Future<XFile?> startRecording() async {
    if (controller == null || !controller!.value.isInitialized) {
      return null;
    }

    await controller!.startVideoRecording();
    return null;
  }

  Future<XFile?> stopRecording() async {
    if (controller == null) return null;

    return await controller!.stopVideoRecording();
  }

  void dispose() {
    controller?.dispose();
  }
}