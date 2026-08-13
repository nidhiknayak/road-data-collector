import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Correlates GPS + IMU data against video time, in fixed-size buckets,
/// and produces a simple pothole signal from accelerometer magnitude.
///
/// This is a post-processing step, run on-demand from the Session
/// Details screen after a recording is complete. It does not touch the
/// recording path.
class CorrelationService {
  static const int _component = 500; // bucket size, ms — see bucketMs below

  /// Bucket width in milliseconds. 500ms was chosen as a reasonable
  /// starting granularity; tune based on typical driving speed / how
  /// short potholes are relative to frame rate.
  static const int bucketMs = 500;

  /// Threshold (m/s^2) of deviation from gravity (9.81) in accelerometer
  /// magnitude before a bucket is flagged as a likely pothole. This is a
  /// first-pass guess, NOT field-validated — expect to tune this once you
  /// have real recordings to compare against.
  static const double potholeThreshold = 3.5;

  static const double _gravity = 9.81;

  Future<File> generate({required String sessionPath}) async {
    final metadataFile = File("$sessionPath/metadata.json");
    final gpsFile = File("$sessionPath/gps.csv");
    final imuFile = File("$sessionPath/imu.csv");

    if (!await metadataFile.exists()) {
      throw Exception("metadata.json not found for this session.");
    }

    final metadata =
        jsonDecode(await metadataFile.readAsString()) as Map<String, dynamic>;

    final cameraOffsetMs = metadata["camera_start_offset_ms"] as int?;
    if (cameraOffsetMs == null) {
      throw Exception(
        "This session has no video (camera was disabled), so there is "
        "nothing to correlate against.",
      );
    }

    final durationMs = metadata["duration_ms"] as int?;
    if (durationMs == null) {
      throw Exception("Session metadata is missing duration_ms.");
    }

    final videoDurationMs = durationMs - cameraOffsetMs;
    if (videoDurationMs <= 0) {
      throw Exception(
        "Computed video duration ($videoDurationMs ms) is not positive — "
        "session data looks inconsistent.",
      );
    }

    if (!await gpsFile.exists()) {
      throw Exception("gps.csv not found for this session.");
    }
    if (!await imuFile.exists()) {
      throw Exception("imu.csv not found for this session.");
    }

    final gpsRows = await _parseGpsCsv(gpsFile);
    final imuRows = await _parseImuCsv(imuFile);

    final bucketCount = (videoDurationMs / bucketMs).ceil();
    final buckets = <Map<String, dynamic>>[];

    int imuCursor = 0;
    int gpsCursor = 0;

    for (int i = 0; i < bucketCount; i++) {
      final videoTimeMs = i * bucketMs;
      final windowStart = cameraOffsetMs + videoTimeMs;
      final windowEnd = windowStart + bucketMs;

      // Advance the IMU cursor past rows before this window, then scan
      // forward through rows inside it. Rows are written in increasing
      // elapsed_ms order during recording, so a single forward sweep
      // across all buckets is enough — no need to rescan from the start.
      while (imuCursor < imuRows.length &&
          imuRows[imuCursor].elapsedMs < windowStart) {
        imuCursor++;
      }

      double? accelPeak;
      int scan = imuCursor;
      while (scan < imuRows.length && imuRows[scan].elapsedMs < windowEnd) {
        final row = imuRows[scan];
        final magnitude =
            sqrt(row.ax * row.ax + row.ay * row.ay + row.az * row.az);
        final deviation = (magnitude - _gravity).abs();
        if (accelPeak == null || deviation > accelPeak) {
          accelPeak = deviation;
        }
        scan++;
      }

      // Nearest GPS row to the bucket midpoint.
      final midpoint = windowStart + (bucketMs ~/ 2);
      while (gpsCursor < gpsRows.length - 1 &&
          (gpsRows[gpsCursor + 1].elapsedMs - midpoint).abs() <=
              (gpsRows[gpsCursor].elapsedMs - midpoint).abs()) {
        gpsCursor++;
      }
      final gpsRow = gpsRows.isNotEmpty ? gpsRows[gpsCursor] : null;

      buckets.add({
        "bucket_index": i,
        "video_time_ms": videoTimeMs,
        "elapsed_ms": windowStart,
        "latitude": gpsRow?.latitude,
        "longitude": gpsRow?.longitude,
        "speed": gpsRow?.speed,
        "accel_peak_deviation": accelPeak,
        "pothole": (accelPeak ?? 0) >= potholeThreshold,
      });
    }

    final outFile = File("$sessionPath/correlation.json");
    await outFile.writeAsString(
      const JsonEncoder.withIndent("  ").convert({
        "bucket_ms": bucketMs,
        "pothole_threshold": potholeThreshold,
        "camera_start_offset_ms": cameraOffsetMs,
        "buckets": buckets,
      }),
    );

    return outFile;
  }

  Future<List<_ImuRow>> _parseImuCsv(File file) async {
    final lines = await file.readAsLines();
    if (lines.isEmpty) return [];

    final rows = <_ImuRow>[];
    for (final line in lines.skip(1)) {
      if (line.trim().isEmpty) continue;
      final parts = line.split(",");
      if (parts.length < 4) continue;
      rows.add(_ImuRow(
        elapsedMs: int.parse(parts[0]),
        ax: double.parse(parts[1]),
        ay: double.parse(parts[2]),
        az: double.parse(parts[3]),
      ));
    }
    return rows;
  }

  Future<List<_GpsRow>> _parseGpsCsv(File file) async {
    final lines = await file.readAsLines();
    if (lines.isEmpty) return [];

    final rows = <_GpsRow>[];
    for (final line in lines.skip(1)) {
      if (line.trim().isEmpty) continue;
      final parts = line.split(",");
      if (parts.length < 5) continue;
      rows.add(_GpsRow(
        elapsedMs: int.parse(parts[0]),
        latitude: double.parse(parts[1]),
        longitude: double.parse(parts[2]),
        speed: double.parse(parts[4]),
      ));
    }
    return rows;
  }
}

class _ImuRow {
  final int elapsedMs;
  final double ax, ay, az;

  _ImuRow({
    required this.elapsedMs,
    required this.ax,
    required this.ay,
    required this.az,
  });
}

class _GpsRow {
  final int elapsedMs;
  final double latitude;
  final double longitude;
  final double speed;

  _GpsRow({
    required this.elapsedMs,
    required this.latitude,
    required this.longitude,
    required this.speed,
  });
}