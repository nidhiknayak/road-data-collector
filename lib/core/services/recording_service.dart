import 'package:camera/camera.dart';

import 'camera_service.dart';

class RecordingService {
  final CameraService cameraService;

  bool isRecording = false;

  RecordingService(this.cameraService);

  Future<void> startRecording() async {
    if (isRecording) return;

    await cameraService.controller?.startVideoRecording();

    isRecording = true;
  }

  Future<XFile?> stopRecording() async {
    if (!isRecording) return null;

    final file = await cameraService.controller?.stopVideoRecording();

    isRecording = false;

    return file;
  }
}