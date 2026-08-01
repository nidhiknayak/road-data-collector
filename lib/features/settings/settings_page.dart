import 'package:flutter/material.dart';

import '../../core/services/permission_service.dart';
import '../../core/services/settings_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final PermissionService _permissionService = PermissionService();
  final SettingsService _settingsService = SettingsService();

  bool _cameraEnabled = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _cameraEnabled = await _settingsService.isCameraEnabled();

    if (!mounted) return;

    setState(() {
      _loading = false;
    });
  }

  Future<void> _toggleCamera(bool value) async {
    await _settingsService.setCameraEnabled(value);

    setState(() {
      _cameraEnabled = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text("Enable Camera"),
            subtitle: const Text(
              "Record rear camera video during data collection",
            ),
            value: _cameraEnabled,
            onChanged: _toggleCamera,
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.security),
            title: const Text("Request Permissions"),
            onTap: () async {
              await _permissionService.requestAllPermissions();

              if (!context.mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Permissions requested"),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}