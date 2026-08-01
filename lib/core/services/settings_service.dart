import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _cameraEnabledKey = 'camera_enabled';

  Future<bool> isCameraEnabled() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool(_cameraEnabledKey) ?? true;
  }

  Future<void> setCameraEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(
      _cameraEnabledKey,
      enabled,
    );
  }
}