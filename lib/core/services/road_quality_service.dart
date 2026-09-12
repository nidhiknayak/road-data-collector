import 'dart:io';
import 'dart:math';

import 'package:latlong2/latlong.dart';

enum RoadQuality { good, moderateGood, moderateBad, bad }

class RoadQualitySegment {
  final List<LatLng> points;
  final double avgRoughness;
  final RoadQuality quality;

  RoadQualitySegment({
    required this.points,
    required this.avgRoughness,
    required this.quality,
  });
}

/// Splits a session's GPS route into ~250m segments and scores each one's
/// road quality from the average accelerometer deviation-from-gravity
/// recorded during that stretch.
class RoadQualityService {
  static const double segmentLengthMeters = 250;

  // First-pass thresholds (m/s^2 avg deviation from gravity), not
  // field-validated — same caveat as CorrelationService.potholeThreshold.
  // Tune once real recordings are available.
  static const double goodThreshold = 1.0;
  static const double moderateGoodThreshold = 2.0;
  static const double moderateBadThreshold = 3.0;

  static const double _gravity = 9.81;

  final Distance _distance = const Distance();

  Future<List<RoadQualitySegment>> generate({
    required String gpsPath,
    required String imuPath,
  }) async {
    final gpsFile = File(gpsPath);
    final imuFile = File(imuPath);

    if (!await gpsFile.exists() || !await imuFile.exists()) return [];

    final gpsRows = await _parseGps(gpsFile);
    final imuRows = await _parseImu(imuFile);

    if (gpsRows.length < 2) return [];

    final segments = <RoadQualitySegment>[];

    var points = [LatLng(gpsRows.first.lat, gpsRows.first.lon)];
    var accDistance = 0.0;
    var segmentStartMs = gpsRows.first.elapsedMs;
    var imuCursor = 0;

    for (var i = 1; i < gpsRows.length; i++) {
      final prev = gpsRows[i - 1];
      final curr = gpsRows[i];

      accDistance += _distance.as(
        LengthUnit.Meter,
        LatLng(prev.lat, prev.lon),
        LatLng(curr.lat, curr.lon),
      );
      points.add(LatLng(curr.lat, curr.lon));

      final isLast = i == gpsRows.length - 1;
      if (accDistance >= segmentLengthMeters || isLast) {
        final segmentEndMs = curr.elapsedMs;

        while (imuCursor < imuRows.length &&
            imuRows[imuCursor].elapsedMs < segmentStartMs) {
          imuCursor++;
        }

        var sum = 0.0;
        var count = 0;
        var scan = imuCursor;
        while (scan < imuRows.length && imuRows[scan].elapsedMs <= segmentEndMs) {
          final r = imuRows[scan];
          final magnitude = sqrt(r.ax * r.ax + r.ay * r.ay + r.az * r.az);
          sum += (magnitude - _gravity).abs();
          count++;
          scan++;
        }

        final avgRoughness = count > 0 ? sum / count : 0.0;

        segments.add(RoadQualitySegment(
          points: List.of(points),
          avgRoughness: avgRoughness,
          quality: _classify(avgRoughness),
        ));

        // Next segment starts where this one ended, so the drawn route
        // has no gaps.
        points = [LatLng(curr.lat, curr.lon)];
        accDistance = 0;
        segmentStartMs = curr.elapsedMs;
        imuCursor = scan;
      }
    }

    return segments;
  }

  RoadQuality _classify(double avg) {
    if (avg < goodThreshold) return RoadQuality.good;
    if (avg < moderateGoodThreshold) return RoadQuality.moderateGood;
    if (avg < moderateBadThreshold) return RoadQuality.moderateBad;
    return RoadQuality.bad;
  }

  Future<List<_GpsRow>> _parseGps(File file) async {
    final lines = await file.readAsLines();
    final rows = <_GpsRow>[];
    for (final line in lines.skip(1)) {
      if (line.trim().isEmpty) continue;
      final p = line.split(",");
      if (p.length < 3) continue;
      final ms = int.tryParse(p[0]);
      final lat = double.tryParse(p[1]);
      final lon = double.tryParse(p[2]);
      if (ms == null || lat == null || lon == null) continue;
      rows.add(_GpsRow(elapsedMs: ms, lat: lat, lon: lon));
    }
    return rows;
  }

  Future<List<_ImuRow>> _parseImu(File file) async {
    final lines = await file.readAsLines();
    final rows = <_ImuRow>[];
    for (final line in lines.skip(1)) {
      if (line.trim().isEmpty) continue;
      final p = line.split(",");
      if (p.length < 4) continue;
      final ms = int.tryParse(p[0]);
      final ax = double.tryParse(p[1]);
      final ay = double.tryParse(p[2]);
      final az = double.tryParse(p[3]);
      if (ms == null || ax == null || ay == null || az == null) continue;
      rows.add(_ImuRow(elapsedMs: ms, ax: ax, ay: ay, az: az));
    }
    return rows;
  }
}

class _GpsRow {
  final int elapsedMs;
  final double lat, lon;
  _GpsRow({required this.elapsedMs, required this.lat, required this.lon});
}

class _ImuRow {
  final int elapsedMs;
  final double ax, ay, az;
  _ImuRow({required this.elapsedMs, required this.ax, required this.ay, required this.az});
}