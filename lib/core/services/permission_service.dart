import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<void> requestAllPermissions() async {
    await [
      Permission.camera,
      Permission.location,
    ].request();
  }

  Future<bool> hasAllPermissions() async {
    final camera = await Permission.camera.isGranted;
    final location = await Permission.location.isGranted;

    return camera && location;
  }
}