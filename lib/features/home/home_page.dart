import 'package:flutter/material.dart';

import '../camera/camera_page.dart';
import '../gps/gps_page.dart';
import '../recording/recording_page.dart';
import '../sensors/sensors_page.dart';
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            tile(context, Icons.camera_alt, "Camera", const CameraPage()),
            tile(context, Icons.location_on, "GPS", const GpsPage()),
            tile(context, Icons.sensors, "Sensors", const SensorsPage()),
            tile(context, Icons.fiber_manual_record,
                "Start Recording", const RecordingPage()),
            tile(context, Icons.settings, "Settings", const SettingsPage()),
          ],
        ),
      ),
    );
  }
}