import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/services/camera_service.dart';
import '../../core/services/collection_service.dart';
import '../../core/services/gps_service.dart';

class RecordingPage extends StatefulWidget {
  const RecordingPage({super.key});

  @override
  State<RecordingPage> createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage> {
  final CameraService _cameraService = CameraService();
  late final CollectionService _collectionService;

  final GpsService _gpsService = GpsService();

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      await _cameraService.initialize();
      await _gpsService.initialize();

      _collectionService = CollectionService(
        cameraService: _cameraService,
        gpsService: _gpsService,
      );

      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint("Initialization Error: $e");
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Initialization failed: $e"),
        ),
      );
    }
  }

  Future<void> _toggleRecording() async {
    try {
      if (_collectionService.isRecording) {
        final File? video =
            await _collectionService.stopRecordingSession();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              video != null
                  ? "Saved: ${video.path}"
                  : "Recording stopped.",
            ),
          ),
        );
      } else {
        await _collectionService.startRecordingSession();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Recording started."),
          ),
        );
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e, stackTrace) {
      debugPrint("Recording Error: $e");
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Recording failed: $e"),
        ),
      );
    }
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Recording"),
      ),
      body: Column(
        children: [
          Expanded(
            child: CameraPreview(
              _cameraService.controller!,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: FilledButton.icon(
                onPressed: _toggleRecording,
                icon: Icon(
                  _collectionService.isRecording
                      ? Icons.stop
                      : Icons.fiber_manual_record,
                ),
                label: Text(
                  _collectionService.isRecording
                      ? "Stop Recording"
                      : "Start Recording",
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}