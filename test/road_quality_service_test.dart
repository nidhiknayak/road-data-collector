import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:road_data_collector/core/services/road_quality_service.dart';

void main() {
  group('RoadQualityService', () {
    late Directory tempDir;
    late String gpsPath;
    late String imuPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('road_quality_test');
      gpsPath = p.join(tempDir.path, 'gps.csv');
      imuPath = p.join(tempDir.path, 'imu.csv');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('returns empty list when files do not exist', () async {
      final service = RoadQualityService();

      final segments = await service.generate(
        gpsPath: gpsPath,
        imuPath: imuPath,
      );

      expect(segments, isEmpty);
    });

    test('returns empty list with fewer than 2 GPS rows', () async {
      File(gpsPath).writeAsStringSync(
        'elapsed_ms,latitude,longitude,altitude,speed,speed_accuracy,heading,accuracy\n'
        '0,12.9716,77.5946,0,0,0,0,0\n',
      );
      File(imuPath).writeAsStringSync(
        'elapsed_ms,ax,ay,az,gx,gy,gz,mx,my,mz\n'
        '0,0,0,9.81,0,0,0,0,0,0\n',
      );

      final service = RoadQualityService();

      final segments = await service.generate(
        gpsPath: gpsPath,
        imuPath: imuPath,
      );

      expect(segments, isEmpty);
    });

    test('creates a single segment for a short route under 250m', () async {
      // Two points ~11m apart (0.0001 deg lat ~ 11.1m), well under the
      // 250m segment threshold, so this should collapse to one segment
      // covering the "isLast" flush path.
      File(gpsPath).writeAsStringSync(
        'elapsed_ms,latitude,longitude,altitude,speed,speed_accuracy,heading,accuracy\n'
        '0,12.9716,77.5946,0,0,0,0,0\n'
        '1000,12.9717,77.5946,0,0,0,0,0\n',
      );
      File(imuPath).writeAsStringSync(
        'elapsed_ms,ax,ay,az,gx,gy,gz,mx,my,mz\n'
        '0,0,0,9.81,0,0,0,0,0,0\n'
        '1000,0,0,9.81,0,0,0,0,0,0\n',
      );

      final service = RoadQualityService();

      final segments = await service.generate(
        gpsPath: gpsPath,
        imuPath: imuPath,
      );

      expect(segments.length, 1);
      expect(segments.first.quality, RoadQuality.good);
      expect(segments.first.avgRoughness, closeTo(0, 0.001));
    });

    test('splits into multiple segments once 250m is exceeded', () async {
      // Roughly 0.0027 deg of latitude ~= 300m per step, so each step on
      // its own should trigger a new segment.
      final buffer = StringBuffer(
        'elapsed_ms,latitude,longitude,altitude,speed,speed_accuracy,heading,accuracy\n',
      );
      for (var i = 0; i < 4; i++) {
        final lat = 12.9716 + (i * 0.0027);
        buffer.writeln('${i * 1000},$lat,77.5946,0,0,0,0,0');
      }
      File(gpsPath).writeAsStringSync(buffer.toString());

      final imuBuffer = StringBuffer(
        'elapsed_ms,ax,ay,az,gx,gy,gz,mx,my,mz\n',
      );
      for (var i = 0; i < 4; i++) {
        imuBuffer.writeln('${i * 1000},0,0,9.81,0,0,0,0,0,0');
      }
      File(imuPath).writeAsStringSync(imuBuffer.toString());

      final service = RoadQualityService();

      final segments = await service.generate(
        gpsPath: gpsPath,
        imuPath: imuPath,
      );

      // 3 hops of ~300m each should produce 3 segments, one per hop.
      expect(segments.length, 3);
    });

    test('classifies high accelerometer deviation as bad', () async {
      File(gpsPath).writeAsStringSync(
        'elapsed_ms,latitude,longitude,altitude,speed,speed_accuracy,heading,accuracy\n'
        '0,12.9716,77.5946,0,0,0,0,0\n'
        '1000,12.9717,77.5946,0,0,0,0,0\n',
      );
      // az deviates far from gravity (9.81) on every sample, so
      // avgRoughness should land well above bad threshold (3.0).
      File(imuPath).writeAsStringSync(
        'elapsed_ms,ax,ay,az,gx,gy,gz,mx,my,mz\n'
        '0,0,0,20.0,0,0,0,0,0,0\n'
        '1000,0,0,20.0,0,0,0,0,0,0\n',
      );

      final service = RoadQualityService();

      final segments = await service.generate(
        gpsPath: gpsPath,
        imuPath: imuPath,
      );

      expect(segments.length, 1);
      expect(segments.first.quality, RoadQuality.bad);
    });

    test('malformed rows are skipped rather than throwing', () async {
      File(gpsPath).writeAsStringSync(
        'elapsed_ms,latitude,longitude,altitude,speed,speed_accuracy,heading,accuracy\n'
        '0,12.9716,77.5946,0,0,0,0,0\n'
        'garbage,row,here\n'
        '1000,12.9717,77.5946,0,0,0,0,0\n',
      );
      File(imuPath).writeAsStringSync(
        'elapsed_ms,ax,ay,az,gx,gy,gz,mx,my,mz\n'
        '0,0,0,9.81,0,0,0,0,0,0\n'
        'nope\n'
        '1000,0,0,9.81,0,0,0,0,0,0\n',
      );

      final service = RoadQualityService();

      final segments = await service.generate(
        gpsPath: gpsPath,
        imuPath: imuPath,
      );

      expect(segments.length, 1);
    });
  });
}
