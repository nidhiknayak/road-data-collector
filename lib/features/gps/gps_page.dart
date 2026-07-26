import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/services/gps_service.dart';

class GpsPage extends StatelessWidget {
  const GpsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final gps = GpsService();

    return Scaffold(
      appBar: AppBar(
        title: const Text("GPS"),
      ),
      body: StreamBuilder<Position>(
        stream: gps.getPositionStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final p = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [

              ListTile(
                title: const Text("Latitude"),
                subtitle: Text("${p.latitude}"),
              ),

              ListTile(
                title: const Text("Longitude"),
                subtitle: Text("${p.longitude}"),
              ),

              ListTile(
                title: const Text("Speed"),
                subtitle: Text("${p.speed} m/s"),
              ),

              ListTile(
                title: const Text("Accuracy"),
                subtitle: Text("${p.accuracy} m"),
              ),

              ListTile(
                title: const Text("Timestamp"),
                subtitle: Text(
                  p.timestamp?.toString() ?? "Unavailable",
                ),
              ),

            ],
          );
        },
      ),
    );
  }
}