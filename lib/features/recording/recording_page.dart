import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/services/camera_service.dart';
import '../../core/services/collection_service.dart';
import '../../core/services/gps_service.dart';
import '../../core/services/settings_service.dart';

class RecordingPage extends StatefulWidget {
  const RecordingPage({super.key});

  @override
  State<RecordingPage> createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage> {
  final CameraService _cameraService = CameraService();
  late final CollectionService _collectionService;

  final GpsService _gpsService = GpsService();

  final SettingsService _settingsService = SettingsService();

  bool _cameraEnabled = true;

  bool _loading = true;

  Timer? _timer;
  Duration _elapsed = Duration.zero;

  String get formattedTime {
    String twoDigits(int n) => n.toString().padLeft(2, '0');

    final minutes = twoDigits(_elapsed.inMinutes.remainder(60));
    final seconds = twoDigits(_elapsed.inSeconds.remainder(60));

    return "$minutes:$seconds";
  }

  void _startTimer() {
    _elapsed = Duration.zero;

    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) return;

        setState(() {
          _elapsed += const Duration(seconds: 1);
        });
      },
    );
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  Widget _buildStatusTile({
    required IconData icon,
    required String title,
    required bool active,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.circle,
              size: 12,
              color: active ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(
              active ? "Active" : "Inactive",
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameraEnabled = await _settingsService.isCameraEnabled();

      if (_cameraEnabled) {
        await _cameraService.initialize();
      }

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

        _stopTimer();

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

        _startTimer();

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
    _timer?.cancel();

    if (_cameraEnabled) {
      _cameraService.dispose();
    }

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
            child: _cameraEnabled
                ? CameraPreview(
                    _cameraService.controller!,
                  )
                : Container(
                    color: Colors.black12,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.videocam_off,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            "Camera Recording Disabled",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "GPS and IMU data will still be recorded.",
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
          ),

          if (_collectionService.isRecording) ...[
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.fiber_manual_record,
                  color: Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  "Recording",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              formattedTime,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),
          ],

          Column(
            children: [
              _buildStatusTile(
                icon: Icons.location_on,
                title: "GPS",
                active: _collectionService.gpsConnected,
              ),

              _buildStatusTile(
                icon: Icons.sensors,
                title: "IMU",
                active: _collectionService.imuActive,
              ),

              _buildStatusTile(
                icon: Icons.videocam,
                title: "Camera",
                active: _collectionService.cameraRecording,
              ),
            ],
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