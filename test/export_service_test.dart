import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:road_data_collector/core/services/export_service.dart';
import 'package:road_data_collector/features/sessions/session_model.dart';

void main() {
  group('ExportService', () {
    test('creates ZIP for session without video', () async {
      final root = await Directory.systemTemp.createTemp();

      final sessionDir = Directory(
        p.join(root.path, 'Session_Test'),
      )..createSync();

      File(p.join(sessionDir.path, 'gps.csv'))
          .writeAsStringSync('gps');

      File(p.join(sessionDir.path, 'imu.csv'))
          .writeAsStringSync('imu');

      File(p.join(sessionDir.path, 'metadata.json'))
          .writeAsStringSync('{}');

      final session = SessionModel(
        id: 'Session_Test',
        path: sessionDir.path,
        startTime: DateTime.now(),
        duration: const Duration(seconds: 5),
      );

      final exportService = ExportService();

      final zip = await exportService.createZip(
        session,
        outputDirectory: root,
      );

      expect(zip.existsSync(), isTrue);

      expect(
        zip.path.endsWith('.zip'),
        isTrue,
      );
    });
  });
}