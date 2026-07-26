import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/services/camera_service.dart';
import '../../core/services/collection_service.dart';
import '../../core/services/recording_service.dart';

class RecordingPage extends StatefulWidget {
  const RecordingPage({super.key});

  @override
  State<RecordingPage> createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage> {
  final CameraService _cameraService = CameraService();
  final CollectionService _collectionService = CollectionService();

  RecordingService? _recordingService;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    await _cameraService.initialize();

    _recordingService = RecordingService(_cameraService);

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_recordingService == null) return;

    if (!_recordingService!.isRecording) {
      // Create a new session folder
      final folder = await _collectionService.createSession();

      debugPrint("====================================");
      debugPrint("Session Folder Created:");
      debugPrint(folder.path);
      debugPrint("====================================");

      // Start recording
      await _recordingService!.startRecording();

      if (mounted) {
        setState(() {});
      }
    } else {
      // Stop recording
      final XFile? file = await _recordingService!.stopRecording();

      if (mounted) {
        setState(() {});
      }

      if (file != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Video saved:\n${file.path}",
            ),
          ),
        );
      }
    }
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
                  _recordingService!.isRecording
                      ? Icons.stop
                      : Icons.fiber_manual_record,
                ),
                label: Text(
                  _recordingService!.isRecording
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