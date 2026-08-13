import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Structured logging for the app.
///
/// Every entry is written to the console (debugPrint, same as before) AND
/// appended to a log file on disk, so failures during field recordings
/// (no ADB attached) can still be diagnosed after the fact.
///
/// The public API stays synchronous on purpose — most call sites are
/// inside catch blocks, and requiring `await` everywhere there would be a
/// bigger, riskier change than this issue calls for. Disk writes happen
/// fire-and-forget internally. Any failure to persist to disk is caught
/// and disables further disk persistence for the run — logging must never
/// be able to crash the app or interfere with an active recording.
class LoggerService {
  LoggerService._();

  static String? _sessionId;
  static IOSink? _sink;
  static File? _logFile;
  static bool _diskLoggingDisabled = false;

  /// Roughly caps the log file size before rotating. Generous since this
  /// is error/warning-level logging, not per-sensor-event logging.
  static const int _maxLogFileBytes = 2 * 1024 * 1024; // 2 MB

  /// Associates subsequent log entries with a recording session ID (the
  /// session folder name, e.g. "Session_20260813_164500"). Call with null
  /// when no session is active. Safe to call at any time.
  static void setSession(String? sessionId) {
    _sessionId = sessionId;
  }

  /// Path to the current on-disk log file, once disk logging has
  /// initialized. Useful later for bundling logs into an export/support
  /// flow. Null if disk logging hasn't started yet or failed to init.
  static String? get currentLogFilePath => _logFile?.path;

  static void info({
    required String component,
    required String message,
    String? operation,
  }) {
    _write(
      "INFO",
      component: component,
      message: message,
      operation: operation,
    );
  }

  static void warning({
    required String component,
    required String message,
    String? operation,
  }) {
    _write(
      "WARNING",
      component: component,
      message: message,
      operation: operation,
    );
  }

  static void error({
    required String component,
    required String message,
    String? operation,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _write(
      "ERROR",
      component: component,
      message: message,
      operation: operation,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void _write(
    String level, {
    required String component,
    required String message,
    String? operation,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final timestamp = DateTime.now().toIso8601String();

    final header = StringBuffer()
      ..write("[$timestamp] $level [$component]");

    if (operation != null) {
      header.write(" [op=$operation]");
    }

    if (_sessionId != null) {
      header.write(" [session=$_sessionId]");
    }

    header.write(" $message");

    final headerLine = header.toString();
    debugPrint(headerLine);

    final persisted = StringBuffer(headerLine);

    if (error != null) {
      final errorLine = "  Error: $error";
      debugPrint(errorLine);
      persisted.write("\n$errorLine");
    }

    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
      persisted.write("\n$stackTrace");
    }

    unawaited(_persist(persisted.toString()));
  }

  static Future<void> _persist(String entry) async {
    if (_diskLoggingDisabled) return;

    try {
      final sink = await _ensureSink();
      if (sink == null) return;

      sink.writeln(entry);
      await sink.flush();

      await _rotateIfNeeded();
    } catch (e) {
      // Logging must never crash the app or a recording. Disable further
      // disk persistence for this run rather than retrying repeatedly.
      _diskLoggingDisabled = true;
      debugPrint("LOGGER PERSIST ERROR (disk logging disabled): $e");
    }
  }

  static Future<IOSink?> _ensureSink() async {
    if (_sink != null) return _sink;

    final baseDir = await getExternalStorageDirectory();
    if (baseDir == null) {
      _diskLoggingDisabled = true;
      return null;
    }

    final logsDir = Directory(path.join(baseDir.path, "logs"));
    if (!await logsDir.exists()) {
      await logsDir.create(recursive: true);
    }

    _logFile = File(path.join(logsDir.path, "app_log.txt"));
    _sink = _logFile!.openWrite(mode: FileMode.append);

    return _sink;
  }

  static Future<void> _rotateIfNeeded() async {
    final file = _logFile;
    if (file == null) return;
    if (!await file.exists()) return;

    final size = await file.length();
    if (size <= _maxLogFileBytes) return;

    // Simple single-backup rotation: app_log.txt -> app_log.old.txt
    await _sink?.flush();
    await _sink?.close();
    _sink = null;

    final backup = File(path.join(file.parent.path, "app_log.old.txt"));
    if (await backup.exists()) {
      await backup.delete();
    }
    await file.rename(backup.path);

    _logFile = File(path.join(file.parent.path, "app_log.txt"));
    _sink = _logFile!.openWrite(mode: FileMode.append);
  }
}