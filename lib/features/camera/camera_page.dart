import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/services/camera_service.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  final CameraService _cameraService = CameraService();

  @override
  void initState() {
    super.initState();
    _cameraService.initialize().then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraService.controller;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Camera"),
      ),
      body: controller == null || !controller.value.isInitialized
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : CameraPreview(controller),
    );
  }
}