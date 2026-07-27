import 'package:flutter/material.dart';

import '../camera/camera_page.dart';
import '../gps/gps_page.dart';
import '../recording/recording_page.dart';
import '../sensors/sensors_page.dart';
import '../sessions/sessions_page.dart';
import '../settings/settings_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void open(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  Widget tile(
    BuildContext context,
    IconData icon,
    String title,
    Widget page,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => open(context, page),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Road Data Collector"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.fiber_manual_record,
                color: Colors.red,
              ),
              title: const Text("Start Recording"),
              subtitle: const Text(
                "Collect synchronized video, GPS and IMU data",
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => open(
                context,
                const RecordingPage(),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: ListTile(
              leading: const Icon(Icons.folder),
              title: const Text("Recorded Sessions"),
              subtitle: const Text(
                "Browse previous recordings",
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => open(
                context,
                const SessionsPage(),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: ListTile(
              leading: const Icon(Icons.settings),
              title: const Text("Settings"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => open(
                context,
                const SettingsPage(),
              ),
            ),
          ),

          const SizedBox(height: 24),

          Text(
            "Developer Tools",
            style: Theme.of(context).textTheme.titleMedium,
          ),

          const SizedBox(height: 8),

          tile(
            context,
            Icons.camera_alt,
            "Camera Test",
            const CameraPage(),
          ),

          tile(
            context,
            Icons.location_on,
            "GPS Test",
            const GpsPage(),
          ),

          tile(
            context,
            Icons.sensors,
            "Sensor Test",
            const SensorsPage(),
          ),
        ],
      ),
    );
  }
}