import 'package:flutter_test/flutter_test.dart';
import 'package:road_data_collector/core/services/camera_service.dart';
import 'package:road_data_collector/core/services/collection_service.dart';
import 'package:road_data_collector/core/services/gps_service.dart';

void main() {
  group('Session Name Generation', () {
    test('generates correctly formatted session name', () {
      final service = CollectionService(
        cameraService: CameraService(),
        gpsService: GpsService(),
      );

      final name = service.generateSessionName(
        DateTime(2026, 8, 3, 18, 30, 45),
      );

      expect(
        name,
        'Session_20260803_183045',
      );
    });

    test('pads single digit values with zero', () {
      final service = CollectionService(
        cameraService: CameraService(),
        gpsService: GpsService(),
      );

      final name = service.generateSessionName(
        DateTime(2026, 1, 2, 3, 4, 5),
      );

      expect(
        name,
        'Session_20260102_030405',
      );
    });
  });
}