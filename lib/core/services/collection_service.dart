import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'camera_service.dart';
import 'gps_logger.dart';
import 'gps_service.dart';
import 'imu_logger.dart';
import 'imu_service.dart';
import 'recording_service.dart';

class CollectionService {
  late final CameraService _cameraService;
  late final RecordingService _recordingService;

  final GpsService _gpsService;
  final GpsLogger _gpsLogger = GpsLogger();

  final ImuService _imuService = ImuService();
  final ImuLogger _imuLogger = ImuLogger();

  Directory? _sessionDirectory;

  CollectionService({
    required CameraService cameraService,
    required GpsService gpsService,
  }) : _gpsService = gpsService {
    _cameraService = cameraService;
    _recordingService = RecordingService(cameraService);
  }

  Directory get sessionDirectory {
    if (_sessionDirectory == null) {
      throw Exception("No active session.");
    }
    return _sessionDirectory!;
  }

  bool get hasActiveSession => _sessionDirectory != null;

  bool get isRecording => _recordingService.isRecording;

  Future<Directory> startSession() async {
    final appDir = await getExternalStorageDirectory();

    if (appDir == null) {
      throw Exception("External storage directory is not available.");
    }

    final now = DateTime.now();

    final sessionName =
        "Session_${now.year}"
        "${now.month.toString().padLeft(2, '0')}"
        "${now.day.toString().padLeft(2, '0')}_"
        "${now.hour.toString().padLeft(2, '0')}"
        "${now.minute.toString().padLeft(2, '0')}"
        "${now.second.toString().padLeft(2, '0')}";

    _sessionDirectory = Directory(
      path.join(appDir.path, sessionName),
    );

    if (!await _sessionDirectory!.exists()) {
      await _sessionDirectory!.create(recursive: true);
    }

    return _sessionDirectory!;
  }

  Future<void> endSession() async {
    _sessionDirectory = null;
  }

  Future<void> startRecordingSession() async {
    await startSession();

    final gpsFile = getGpsFile();
    final imuFile = getImuFile();

    // Start GPS logging.
    await _gpsLogger.start(
      _gpsService.getPositionStream(),
      gpsFile,
    );

    // Start IMU logging.
    await _imuLogger.start(
      _imuService,
      imuFile,
    );

    // Start video recording.
    await _recordingService.startRecording();
  }

  Future<File?> stopRecordingSession() async {
    final XFile? video = await _recordingService.stopRecording();

    // Stop sensor logging.
    await _gpsLogger.stop();
    await _imuLogger.stop();

    File? savedVideo;

    if (video != null) {
      debugPrint("Camera returned: ${video.path}");

      final destination = getVideoFile();

      debugPrint("Copying to: ${destination.path}");

      try {
        savedVideo = await File(video.path).copy(destination.path);

        debugPrint("Video copied successfully.");
      } catch (e, stackTrace) {
        debugPrint("VIDEO COPY ERROR: $e");
        debugPrintStack(stackTrace: stackTrace);
      }
    } else {
      debugPrint("Camera returned null video.");
    }

    await endSession();

    return savedVideo;
  }

  File getGpsFile() {
    return File(
      path.join(
        sessionDirectory.path,
        "gps.csv",
      ),
    );
  }

  File getImuFile() {
    return File(
      path.join(
        sessionDirectory.path,
        "imu.csv",
      ),
    );
  }

  File getVideoFile() {
    return File(
      path.join(
        sessionDirectory.path,
        "video.mp4",
      ),
    );
  }

  File getMetadataFile() {
    return File(
      path.join(
        sessionDirectory.path,
        "metadata.json",
      ),
    );
  }
}