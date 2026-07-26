import 'package:camera/camera.dart';

import 'camera_service.dart';

class RecordingService {
  final CameraService _cameraService;

  bool _isRecording = false;

  RecordingService(this._cameraService);

  bool get isRecording => _isRecording;

  Future<void> startRecording() async {
    if (_isRecording) return;

    await _cameraService.controller!.startVideoRecording();

    _isRecording = true;
  }

  Future<XFile?> stopRecording() async {
    if (!_isRecording) return null;

    final XFile file =
        await _cameraService.controller!.stopVideoRecording();

    _isRecording = false;

    return file;
  }
}