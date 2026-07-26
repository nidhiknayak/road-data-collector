import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Widget tile(IconData icon, String title) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Road Data Collector'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            tile(Icons.camera_alt, 'Camera'),
            tile(Icons.location_on, 'GPS'),
            tile(Icons.sensors, 'Sensors'),
            tile(Icons.fiber_manual_record, 'Start Recording'),
            tile(Icons.settings, 'Settings'),
          ],
        ),
      ),
    );
  }
}