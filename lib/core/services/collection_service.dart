import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'camera_service.dart';
import 'gps_logger.dart';
import 'gps_service.dart';
import 'imu_logger.dart';
import 'imu_service.dart';
import 'logger_service.dart';
import 'recording_service.dart';
import 'session_clock.dart';
import 'settings_service.dart';

class CollectionService {
  static const String _component = "CollectionService";

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
  int? _cameraStartOffsetMs;

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

  /// Builds the session folder name from a given timestamp. Pulled out as
  /// its own method so it can be tested without touching the file system.
  String generateSessionName(DateTime now) {
    return "Session_${now.year}"
        "${now.month.toString().padLeft(2, '0')}"
        "${now.day.toString().padLeft(2, '0')}_"
        "${now.hour.toString().padLeft(2, '0')}"
        "${now.minute.toString().padLeft(2, '0')}"
        "${now.second.toString().padLeft(2, '0')}";
  }

  Future<Directory> startSession() async {
    final appDir = await getExternalStorageDirectory();

    if (appDir == null) {
      throw Exception("External storage directory is not available.");
    }

    final now = DateTime.now();

    final sessionName = generateSessionName(now);

    _sessionDirectory = Directory(
      path.join(appDir.path, sessionName),
    );

    if (!await _sessionDirectory!.exists()) {
      await _sessionDirectory!.create(recursive: true);
    }

    // Tag every subsequent log entry with this session ID until the
    // session ends.
    LoggerService.setSession(sessionName);

    return _sessionDirectory!;
  }

  Future<void> endSession() async {
    _sessionDirectory = null;
    _sessionStartTime = null;
    _sessionEndTime = null;

    LoggerService.setSession(null);
  }

  Future<void> startRecordingSession() async {
    // Start common session clock.
    _clock.start();

    // Create session folder.
    await startSession();

    _sessionStartTime = DateTime.now();
    _cameraStartOffsetMs = null;

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

        // Record the elapsed_ms at which video actually started, so
        // frames can later be correlated against GPS/IMU elapsed_ms.
        // This is captured right after startVideoRecording() returns;
        // it's an approximation, not a frame-exact timestamp (there can
        // be a small additional codec-startup lag on the device).
        _cameraStartOffsetMs = _clock.elapsedMilliseconds;
      }

      // Only flip to "recording" once everything that should have started
      // has actually started.
      _isRecording = true;

      LoggerService.info(
        component: _component,
        operation: "startRecordingSession",
        message: "Recording session started (camera: $cameraEnabled)",
      );

      // Keep the screen on for the duration of the session. Non-fatal if
      // it fails — GPS/IMU/camera are already running at this point, so we
      // don't want a wakelock hiccup to tear down an otherwise-good session.
      try {
        await WakelockPlus.enable();
      } catch (e, stackTrace) {
        LoggerService.error(
          component: _component,
          operation: "startRecordingSession.wakelockEnable",
          message: "Failed to enable wakelock",
          error: e,
          stackTrace: stackTrace,
        );
      }
    } catch (e, stackTrace) {
      LoggerService.error(
        component: _component,
        operation: "startRecordingSession",
        message: "Failed to start recording session",
        error: e,
        stackTrace: stackTrace,
      );

      // Best-effort teardown of whatever did start so we don't leak
      // dangling GPS/IMU subscriptions.
      await _gpsLogger.stop();
      await _imuLogger.stop();
      _clock.stop();

      rethrow;
    }
  }

  /// Stops the current recording session.
  ///
  /// Fault-tolerant by design (see issue #6): each cleanup step below is
  /// isolated in its own try/catch so a failure in one component (e.g. the
  /// camera throwing on stop) can never prevent the remaining components
  /// from shutting down, and can never prevent metadata from being written
  /// or the session from being closed out. Every step logs its own failure
  /// via LoggerService and continues rather than rethrowing.
  Future<File?> stopRecordingSession() async {
    // Release the screen wakelock first so it's not left on if anything
    // below throws.
    try {
      await WakelockPlus.disable();
    } catch (e, stackTrace) {
      LoggerService.error(
        component: _component,
        operation: "stopRecordingSession.wakelockDisable",
        message: "Failed to disable wakelock",
        error: e,
        stackTrace: stackTrace,
      );
    }

    final cameraEnabled = _lastCameraEnabled;

    // 1. Stop camera. A camera failure must not block GPS/IMU shutdown.
    XFile? video;
    if (cameraEnabled) {
      try {
        video = await _recordingService.stopRecording();
      } catch (e, stackTrace) {
        LoggerService.error(
          component: _component,
          operation: "stopRecordingSession.cameraStop",
          message: "Camera failed to stop recording",
          error: e,
          stackTrace: stackTrace,
        );
        video = null;
      }
    }

    _sessionEndTime = DateTime.now();

    // 2. Stop common session clock.
    try {
      _clock.stop();
    } catch (e, stackTrace) {
      LoggerService.error(
        component: _component,
        operation: "stopRecordingSession.clockStop",
        message: "Failed to stop session clock",
        error: e,
        stackTrace: stackTrace,
      );
    }

    // 3. Stop GPS logging. A GPS failure must not block IMU shutdown.
    try {
      await _gpsLogger.stop();
    } catch (e, stackTrace) {
      LoggerService.error(
        component: _component,
        operation: "stopRecordingSession.gpsStop",
        message: "GPS logger failed to stop",
        error: e,
        stackTrace: stackTrace,
      );
    }

    // 4. Stop IMU logging.
    try {
      await _imuLogger.stop();
    } catch (e, stackTrace) {
      LoggerService.error(
        component: _component,
        operation: "stopRecordingSession.imuStop",
        message: "IMU logger failed to stop",
        error: e,
        stackTrace: stackTrace,
      );
    }

    // Resources are considered released at this point regardless of the
    // outcome of any individual step above.
    _isRecording = false;

    // 5. Copy the recorded video into the session directory, if we have one.
    File? savedVideo;
    if (video != null) {
      final destination = getVideoFile();

      LoggerService.info(
        component: _component,
        operation: "stopRecordingSession.videoCopy",
        message: "Copying ${video.path} to ${destination.path}",
      );

      try {
        savedVideo = await File(video.path).copy(destination.path);
        LoggerService.info(
          component: _component,
          operation: "stopRecordingSession.videoCopy",
          message: "Video copied successfully",
        );
      } catch (e, stackTrace) {
        LoggerService.error(
          component: _component,
          operation: "stopRecordingSession.videoCopy",
          message: "Failed to copy recorded video into session directory",
          error: e,
          stackTrace: stackTrace,
        );
      }
    } else if (cameraEnabled) {
      LoggerService.warning(
        component: _component,
        operation: "stopRecordingSession.videoCopy",
        message: "Camera was enabled but returned no video",
      );
    }

    // 6. Write metadata. Must happen before endSession() clears the session
    // directory, and must be attempted even if earlier steps failed, so we
    // still get a record of whatever data did make it to disk.
    try {
      await writeMetadata();
    } catch (e, stackTrace) {
      LoggerService.error(
        component: _component,
        operation: "stopRecordingSession.writeMetadata",
        message: "Failed to write session metadata",
        error: e,
        stackTrace: stackTrace,
      );
    }

    // 7. Always close out the session so the app doesn't get stuck
    // believing a session is still active.
    try {
      await endSession();
    } catch (e, stackTrace) {
      LoggerService.error(
        component: _component,
        operation: "stopRecordingSession.endSession",
        message: "Failed to close out session",
        error: e,
        stackTrace: stackTrace,
      );
    }

    return savedVideo;
  }

  /// Builds the metadata map for the current session. Pulled out from
  /// writeMetadata() so the shape of the metadata can be tested without
  /// touching the file system.
  Map<String, dynamic> buildMetadata() {
    return {
      "session_id": path.basename(sessionDirectory.path),
      "start_time": _sessionStartTime?.toIso8601String(),
      "end_time": _sessionEndTime?.toIso8601String(),
      "duration_ms": _clock.elapsedMilliseconds,
      "video_file": "video.mp4",
      "gps_file": "gps.csv",
      "imu_file": "imu.csv",
      "camera_start_offset_ms": _cameraStartOffsetMs,
    };
  }

  Future<void> writeMetadata() async {
    final file = getMetadataFile();

    await file.writeAsString(
      const JsonEncoder.withIndent("  ").convert(buildMetadata()),
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