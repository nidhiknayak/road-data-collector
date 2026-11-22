import 'package:camera/camera.dart';

class CameraService {
  CameraController? controller;
  final ResolutionPreset resolutionPreset;
  final ImageFormatGroup? imageFormatGroup;

  CameraService({
    this.resolutionPreset = ResolutionPreset.veryHigh,
    this.imageFormatGroup,
  });

  Future<void> initialize() async {
    final cameras = await availableCameras();

    controller = CameraController(
      cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      ),
      resolutionPreset,
      enableAudio: false,
      imageFormatGroup: imageFormatGroup,
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

  Future<void> dispose() async {
    final previous = controller;
    controller = null;
    await previous?.dispose();
  }
}
