import 'dart:convert';
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
import 'session_clock.dart';
import 'settings_service.dart';

class CollectionService {
  
  late final RecordingService _recordingService;

  final GpsService _gpsService;
  final GpsLogger _gpsLogger = GpsLogger();

  final ImuService _imuService = ImuService();
  final ImuLogger _imuLogger = ImuLogger();

  final SettingsService _settingsService = SettingsService();

  final SessionClock _clock = SessionClock();

  bool get gpsConnected => _gpsLogger.hasFix;

  Directory? _sessionDirectory;

  DateTime? _sessionStartTime;
  DateTime? _sessionEndTime;

  // Owns the "is a collection session active" state. This is intentionally
  // independent of the camera/RecordingService, since a session can run
  // with GPS + IMU only (camera disabled in settings).
  bool _isRecording = false;

  bool _lastCameraEnabled = false;

  CollectionService({
    required CameraService cameraService,
    required this._gpsService,
  }) {
    
    _recordingService = RecordingService(cameraService);
  }

  Directory get sessionDirectory {
    if (_sessionDirectory == null) {
      throw Exception("No active session.");
    }
    return _sessionDirectory!;
  }

  bool get hasActiveSession => _sessionDirectory != null;

  /// True whenever a collection session (GPS/IMU/optionally camera) is active.
  bool get isRecording => _isRecording;

  /// True only when the camera itself is actively recording as part of the
  /// current session (false if camera was disabled in settings).
  bool get cameraRecording =>
      _lastCameraEnabled && _recordingService.isRecording;

  bool get imuActive => _imuLogger.isActive;

  SessionClock get clock => _clock;

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
    _sessionStartTime = null;
    _sessionEndTime = null;
  }

  Future<void> startRecordingSession() async {
    // Start common session clock.
    _clock.start();

    // Create session folder.
    await startSession();

    _sessionStartTime = DateTime.now();

    final gpsFile = getGpsFile();
    final imuFile = getImuFile();

    try {
      // Start GPS logging.
      await _gpsLogger.start(
        _gpsService.getPositionStream(),
        gpsFile,
        _clock,
      );

      // Start IMU logging.
      await _imuLogger.start(
        _imuService,
        imuFile,
        _clock,
      );

      // Start video recording (only if camera is enabled in settings).
      final cameraEnabled = await _settingsService.isCameraEnabled();
      _lastCameraEnabled = cameraEnabled;

      if (cameraEnabled) {
        await _recordingService.startRecording();
      }

      // Only flip to "recording" once everything that should have started
      // has actually started.
      _isRecording = true;
    } catch (e, stackTrace) {
      debugPrint("START RECORDING ERROR: $e");
      debugPrintStack(stackTrace: stackTrace);

      // Best-effort teardown of whatever did start so we don't leak
      // dangling GPS/IMU subscriptions.
      await _gpsLogger.stop();
      await _imuLogger.stop();
      _clock.stop();

      rethrow;
    }
  }

  Future<File?> stopRecordingSession() async {
    XFile? video;

    final cameraEnabled = _lastCameraEnabled;

    if (cameraEnabled) {
      video = await _recordingService.stopRecording();
    }

    _sessionEndTime = DateTime.now();

    // Stop common session clock.
    _clock.stop();

    // Stop sensor logging.
    await _gpsLogger.stop();
    await _imuLogger.stop();

    // Flip regardless of whether the camera path ran.
    _isRecording = false;

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

    await writeMetadata();

    await endSession();

    return savedVideo;
  }

  Future<void> writeMetadata() async {
    final metadata = {
      "session_id": path.basename(sessionDirectory.path),
      "start_time": _sessionStartTime?.toIso8601String(),
      "end_time": _sessionEndTime?.toIso8601String(),
      "duration_ms": _clock.elapsedMilliseconds,
      "video_file": "video.mp4",
      "gps_file": "gps.csv",
      "imu_file": "imu.csv",
    };

    final file = getMetadataFile();

    await file.writeAsString(
      const JsonEncoder.withIndent("  ").convert(metadata),
    );
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