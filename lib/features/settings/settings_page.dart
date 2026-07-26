import 'package:flutter/material.dart';
import '../../core/services/permission_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final permissionService = PermissionService();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await permissionService.requestAllPermissions();

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Permissions requested"),
                ),
              );
            }
          },
          child: const Text("Request Permissions"),
        ),
      ),
    );
  }
}