import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import '../models/live_road_quality.dart';

class LiveVisionService {
  static const _channel = MethodChannel('road_collector/vision');

  Future<Map<String, dynamic>> initialize() async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Live road estimates currently support Android.');
    }
    return Map<String, dynamic>.from(
      await _channel.invokeMapMethod('initialize') ?? {},
    );
  }

  Future<void> reset() => _channel.invokeMethod<void>('reset');

  Future<VisionEstimate> analyze(
    CameraImage image,
    CameraController camera,
    String view,
    int elapsedMs,
  ) async {
    final orientation = switch (camera.value.deviceOrientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
    final rotation =
        (camera.description.sensorOrientation - orientation + 360) % 360;
    final result = await _channel.invokeMapMethod<String, dynamic>('analyze', {
      'width': image.width,
      'height': image.height,
      'rotation': rotation,
      'view': view,
      'elapsed_ms': elapsedMs,
      'planes': [
        for (final plane in image.planes)
          {
            'bytes': Uint8List.fromList(plane.bytes),
            'row_stride': plane.bytesPerRow,
            'pixel_stride': plane.bytesPerPixel ?? 1,
          },
      ],
    });
    return VisionEstimate.fromMap(Map<String, dynamic>.from(result!));
  }
}
