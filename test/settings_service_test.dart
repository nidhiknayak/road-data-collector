import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:road_data_collector/core/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('camera is enabled by default', () async {
      final settings = SettingsService();

      expect(
        await settings.isCameraEnabled(),
        true,
      );
    });

    test('camera setting can be disabled', () async {
      final settings = SettingsService();

      await settings.setCameraEnabled(false);

      expect(
        await settings.isCameraEnabled(),
        false,
      );
    });

    test('camera setting can be enabled again', () async {
      final settings = SettingsService();

      await settings.setCameraEnabled(false);
      await settings.setCameraEnabled(true);

      expect(
        await settings.isCameraEnabled(),
        true,
      );
    });
  });
}