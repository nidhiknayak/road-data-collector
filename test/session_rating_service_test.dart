import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_data_collector/core/models/road_rating.dart';
import 'package:road_data_collector/core/services/correlation_service.dart';
import 'package:road_data_collector/core/services/export_service.dart';
import 'package:road_data_collector/core/services/session_rating_service.dart';
import 'package:road_data_collector/features/sessions/session_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory session;
  final service = SessionRatingService();
  const expectedScores = {
    RoadRating.veryGood: 1,
    RoadRating.good: 2,
    RoadRating.bad: 3,
    RoadRating.veryBad: 4,
  };
  const gps =
      'elapsed_ms,latitude,longitude,altitude,speed\n'
      '200,12.9,77.5,900,10\n700,12.91,77.51,900,12\n';
  const imu = 'elapsed_ms,ax,ay,az\n200,0,0,9.81\n700,0,0,15\n';

  Future<Map<String, dynamic>> readJson(String filename) async =>
      jsonDecode(await File('${session.path}/$filename').readAsString())
          as Map<String, dynamic>;

  void expectLabels(Map<String, dynamic> data, RoadRating? rating) {
    expect(data['road_rating'], rating?.value);
    expect(data['road_rating_score'], expectedScores[rating]);
    final buckets = data['buckets'] as List;
    expect(buckets, hasLength(2));
    for (final bucket in buckets) {
      expect(bucket['road_rating'], rating?.value);
      expect(bucket['road_rating_score'], expectedScores[rating]);
    }
    expect(buckets[0]['pothole'], false);
    expect(buckets[1]['pothole'], true);
  }

  setUp(() async {
    session = await Directory.systemTemp.createTemp('session_rating_');
    await File('${session.path}/metadata.json').writeAsString(
      jsonEncode({
        'session_id': 'Session_Test',
        'start_time': '2026-11-01T16:45:00',
        'duration_ms': 1200,
        'camera_start_offset_ms': 200,
      }),
    );
    await File('${session.path}/gps.csv').writeAsString(gps);
    await File('${session.path}/imu.csv').writeAsString(imu);
  });

  tearDown(() => session.delete(recursive: true));

  for (final rating in RoadRating.values) {
    test(
      'persists ${rating.value} and labels newly generated buckets',
      () async {
        await service.setRating(session.path, rating);
        final metadata = await readJson('metadata.json');
        expect(metadata['road_rating'], rating.value);
        expect(metadata['road_rating_score'], expectedScores[rating]);
        expect(DateTime.tryParse(metadata['rated_at'] as String), isNotNull);
        expect(metadata['session_id'], 'Session_Test');
        expect(metadata['duration_ms'], 1200);
        expect(metadata['camera_start_offset_ms'], 200);
        expect(
          await File('${session.path}/correlation.json').exists(),
          isFalse,
        );

        await CorrelationService().generate(sessionPath: session.path);
        expectLabels(await readJson('correlation.json'), rating);
        expect(await File('${session.path}/gps.csv').readAsString(), gps);
        expect(await File('${session.path}/imu.csv').readAsString(), imu);
      },
    );
  }

  test(
    'old sessions start unrated and existing buckets follow rating changes',
    () async {
      await CorrelationService().generate(sessionPath: session.path);
      expectLabels(await readJson('correlation.json'), null);
      await service.setRating(session.path, RoadRating.veryBad);
      expectLabels(await readJson('correlation.json'), RoadRating.veryBad);
      await service.setRating(session.path, RoadRating.veryGood);
      expectLabels(await readJson('correlation.json'), RoadRating.veryGood);
      expect((await readJson('metadata.json'))['road_rating'], 'very_good');

      await CorrelationService().generate(sessionPath: session.path);
      expectLabels(await readJson('correlation.json'), RoadRating.veryGood);
    },
  );

  test('malformed correlation does not prevent saving metadata', () async {
    await File(
      '${session.path}/correlation.json',
    ).writeAsString('invalid json');
    await service.setRating(session.path, RoadRating.bad);
    expect((await readJson('metadata.json'))['road_rating'], 'bad');
    expect(
      await File('${session.path}/correlation.json').readAsString(),
      'invalid json',
    );
  });

  test('missing metadata fails without creating it', () async {
    await File('${session.path}/metadata.json').delete();
    await expectLater(
      service.setRating(session.path, RoadRating.good),
      throwsA(isA<Exception>()),
    );
    expect(await File('${session.path}/metadata.json').exists(), isFalse);
  });

  test('export includes updated metadata and correlation labels', () async {
    await CorrelationService().generate(sessionPath: session.path);
    await service.setRating(session.path, RoadRating.bad);
    final output = await Directory.systemTemp.createTemp('rating_export_');
    addTearDown(() => output.delete(recursive: true));
    final zip = await ExportService().createZip(
      SessionModel(
        id: 'Session_Test',
        path: session.path,
        startTime: null,
        duration: const Duration(milliseconds: 1200),
      ),
      outputDirectory: output,
    );
    final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
    Map<String, dynamic> exportedJson(String name) =>
        jsonDecode(utf8.decode(archive.findFile(name)!.content))
            as Map<String, dynamic>;
    expect(exportedJson('metadata.json')['road_rating'], 'bad');
    expectLabels(exportedJson('correlation.json'), RoadRating.bad);
    expect(utf8.decode(archive.findFile('gps.csv')!.content), gps);
    expect(utf8.decode(archive.findFile('imu.csv')!.content), imu);
  });

  test('missing and unknown rating values remain unrated', () {
    expect(RoadRating.fromValue(null), isNull);
    expect(RoadRating.fromValue('unknown'), isNull);
    for (final rating in RoadRating.values) {
      expect(RoadRating.fromValue(rating.value), rating);
    }
  });
}
