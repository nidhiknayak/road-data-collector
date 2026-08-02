import 'package:flutter_test/flutter_test.dart';
import 'package:road_data_collector/features/sessions/session_model.dart';

void main() {
  group('SessionModel', () {
    const session = SessionModel(
      id: 'Session_20260802_120000',
      path: '/storage/emulated/0/RoadData/Session_20260802_120000',
      startTime: null,
      duration: Duration(seconds: 10),
    );

    test('video path is generated correctly', () {
      expect(
        session.videoPath,
        '/storage/emulated/0/RoadData/Session_20260802_120000/video.mp4',
      );
    });

    test('gps path is generated correctly', () {
      expect(
        session.gpsPath,
        '/storage/emulated/0/RoadData/Session_20260802_120000/gps.csv',
      );
    });

    test('imu path is generated correctly', () {
      expect(
        session.imuPath,
        '/storage/emulated/0/RoadData/Session_20260802_120000/imu.csv',
      );
    });

    test('metadata path is generated correctly', () {
      expect(
        session.metadataPath,
        '/storage/emulated/0/RoadData/Session_20260802_120000/metadata.json',
      );
    });

    test('stores metadata correctly', () {
      expect(session.id, 'Session_20260802_120000');
      expect(
        session.duration,
        const Duration(seconds: 10),
      );
    });
  });
}