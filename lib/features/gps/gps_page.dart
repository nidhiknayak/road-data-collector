import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/services/gps_service.dart';

class GpsPage extends StatefulWidget {
  const GpsPage({super.key});

  @override
  State<GpsPage> createState() => _GpsPageState();
}

class _GpsPageState extends State<GpsPage> {
  final GpsService _gpsService = GpsService();
  late Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _gpsService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("GPS")),
      body: FutureBuilder<void>(
        future: _initialization,
        builder: (context, initSnapshot) {
          if (initSnapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (initSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  initSnapshot.error.toString(),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return StreamBuilder<Position>(
            stream: _gpsService.getPositionStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
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
          );
        },
      ),
    );
  }
}