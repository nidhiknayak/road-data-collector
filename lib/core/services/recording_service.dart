import 'package:camera/camera.dart';

import 'camera_service.dart';
import 'logger_service.dart';

class RecordingService {
  final CameraService _cameraService;

  bool _isRecording = false;

  RecordingService(this._cameraService);

  bool get isRecording => _isRecording;

  Future<void> startRecording({void Function(CameraImage)? onFrame}) async {
    if (_isRecording) return;

    LoggerService.info(
      component: "RecordingService",
      message: "Starting video recording",
    );

    // Keep the SDK's persistent-recording default so removing the preview
    // surface does not end the video or the analysis stream.
    await _cameraService.controller!.startVideoRecording(onAvailable: onFrame);

    LoggerService.info(
      component: "RecordingService",
      message: "Video recording started",
    );

    _isRecording = true;
  }

  Future<XFile?> stopRecording() async {
    if (!_isRecording) return null;

    LoggerService.info(
      component: "RecordingService",
      message: "Stopping video recording",
    );

    try {
      final XFile file = await _cameraService.controller!.stopVideoRecording();

      _isRecording = false;

      LoggerService.info(
        component: "RecordingService",
        message: "Video recording stopped",
      );

      return file;
    } catch (e, stackTrace) {
      LoggerService.error(
        component: "RecordingService",
        message: "Failed to stop video recording",
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
