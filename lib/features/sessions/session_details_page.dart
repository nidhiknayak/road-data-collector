import 'dart:io';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'session_model.dart';
import 'video_player_page.dart';

import '../../core/services/export_service.dart';
import '../../core/services/gps_route_service.dart';
import '../../core/services/session_delete_service.dart';
import 'route_map_widget.dart';

class SessionDetailsPage extends StatefulWidget {
  final SessionModel session;

  const SessionDetailsPage({
    super.key,
    required this.session,
  });

  @override
  State<SessionDetailsPage> createState() =>
      _SessionDetailsPageState();
}

class _SessionDetailsPageState
    extends State<SessionDetailsPage> {
  final GpsRouteService _routeService =
      GpsRouteService();

  List<LatLng> _route = [];

  bool _loadingRoute = true;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    _route = await _routeService.loadRoute(
      widget.session.gpsPath,
    );

    if (!mounted) return;

    setState(() {
      _loadingRoute = false;
    });
  }

  Widget fileTile(
    IconData icon,
    String name,
    String filePath,
  ) {
    final exists = File(filePath).existsSync();

    return ListTile(
      leading: Icon(icon),
      title: Text(name),
      trailing: Icon(
        exists ? Icons.check_circle : Icons.error,
        color: exists ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Session Details"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.session.id,
            style: Theme.of(context).textTheme.headlineSmall,
          ),

          const SizedBox(height: 16),

          Text(
            "Started",
            style: Theme.of(context).textTheme.titleMedium,
          ),

          Text(
            widget.session.startTime?.toString() ?? "-",
          ),

          const SizedBox(height: 16),

          Text(
            "Duration",
            style: Theme.of(context).textTheme.titleMedium,
          ),

          Text(widget.session.duration.toString()),

          const Divider(height: 32),

          fileTile(
            Icons.videocam,
            "video.mp4",
            widget.session.videoPath,
          ),

          fileTile(
            Icons.location_on,
            "gps.csv",
            widget.session.gpsPath,
          ),

          fileTile(
            Icons.sensors,
            "imu.csv",
            widget.session.imuPath,
          ),

          fileTile(
            Icons.description,
            "metadata.json",
            widget.session.metadataPath,
          ),

          const SizedBox(height: 24),

          Text(
            "Route",
            style: Theme.of(context).textTheme.titleMedium,
          ),

          const SizedBox(height: 12),

          _loadingRoute
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : RouteMapWidget(
                  route: _route,
                ),

          const SizedBox(height: 24),

          const Divider(height: 32),

          FilledButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VideoPlayerPage(
                    videoPath: widget.session.videoPath,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text("Play Video"),
          ),

          const SizedBox(height: 12),

          FilledButton.icon(
            onPressed: () async {
              final exporter = ExportService();

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              try {
                await exporter.shareSession(widget.session);
              } finally {
                if (context.mounted) {
                  Navigator.pop(context); // Close loading dialog
                }
              }
            },
            icon: const Icon(Icons.share),
            label: const Text("Share Session"),
          ),

          const SizedBox(height: 12),

          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Delete Session"),
                  content: const Text(
                    "Are you sure you want to permanently delete this session?",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Cancel"),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("Delete"),
                    ),
                  ],
                ),
              );

              if (confirm != true) return;

              final service = SessionDeleteService();

              await service.delete(widget.session);

              if (!context.mounted) return;

              Navigator.pop(context, true);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Session deleted."),
                ),
              );
            },
            icon: const Icon(Icons.delete),
            label: const Text("Delete Session"),
          ),
        ],
      ),
    );
  }
}