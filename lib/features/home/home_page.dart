import 'package:flutter/material.dart';

import '../camera/camera_page.dart';
import '../gps/gps_page.dart';
import '../recording/recording_page.dart';
import '../sensors/sensors_page.dart';
import '../sessions/sessions_page.dart';
import '../settings/settings_page.dart';
import '../live_map/live_map_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _liveBusy = false;

  void open(BuildContext context, Widget page) {
    if (_liveBusy && (page is RecordingPage || page is CameraPage)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stop live mapping before opening another camera.'),
        ),
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Widget tile(BuildContext context, IconData icon, String title, Widget page) {
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
    return DefaultTabController(
      length: 2,
      child: PopScope(
        canPop: !_liveBusy,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _liveBusy) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Stop and save live mapping before leaving.'),
              ),
            );
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text("Road Data Collector"),
            bottom: const TabBar(
              tabs: [
                Tab(
                  icon: Icon(Icons.video_camera_back_outlined),
                  text: 'Collect',
                ),
                Tab(icon: Icon(Icons.map_outlined), text: 'Live road map'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              ListView(
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
                      onTap: () => open(context, const RecordingPage()),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.folder),
                      title: const Text("Recorded Sessions"),
                      subtitle: const Text("Browse previous recordings"),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => open(context, const SessionsPage()),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.settings),
                      title: const Text("Settings"),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => open(context, const SettingsPage()),
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

                  tile(context, Icons.location_on, "GPS Test", const GpsPage()),

                  tile(
                    context,
                    Icons.sensors,
                    "Sensor Test",
                    const SensorsPage(),
                  ),
                ],
              ),
              LiveMapPage(
                onBusyChanged: (busy) {
                  if (mounted) setState(() => _liveBusy = busy);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
