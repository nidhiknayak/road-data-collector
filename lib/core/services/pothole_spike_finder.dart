import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import 'logger_service.dart';

/// Finds moments in a session's IMU log where accelerometer deviation
/// spiked. Frame extraction itself happens offline in
/// scripts/extract_candidates.py.
class PotholeSpikeFinder {
  static const String _component = "PotholeSpikeFinder";

  static const double spikeThreshold = 2.0;
  static const int minGapMs = 1000;
  static const double _gravity = 9.81;

  Future<List<int>> findSpikes({required String sessionPath}) async {
    final imuFile = File(p.join(sessionPath, "imu.csv"));

    if (!await imuFile.exists()) {
      throw Exception("imu.csv not found for this session.");
    }

    final lines = await imuFile.readAsLines();
    final spikes = <int>[];
    int? lastAcceptedMs;

    for (final line in lines.skip(1)) {
      if (line.trim().isEmpty) continue;
      final parts = line.split(",");
      if (parts.length < 4) continue;

      final ms = int.tryParse(parts[0]);
      final ax = double.tryParse(parts[1]);
      final ay = double.tryParse(parts[2]);
      final az = double.tryParse(parts[3]);
      if (ms == null || ax == null || ay == null || az == null) continue;

      final magnitude = sqrt(ax * ax + ay * ay + az * az);
      final deviation = (magnitude - _gravity).abs();

      if (deviation < spikeThreshold) continue;
      if (lastAcceptedMs != null && (ms - lastAcceptedMs) < minGapMs) {
        continue;
      }

      spikes.add(ms);
      lastAcceptedMs = ms;
    }

    LoggerService.info(
      component: _component,
      operation: "findSpikes",
      message: "Found ${spikes.length} IMU spikes above threshold",
    );

    final outFile = File(p.join(sessionPath, "spike_timestamps.json"));
    await outFile.writeAsString(
      const JsonEncoder.withIndent("  ").convert({
        "spike_threshold": spikeThreshold,
        "min_gap_ms": minGapMs,
        "spike_elapsed_ms": spikes,
      }),
    );

    return spikes;
  }
}
