import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../core/services/road_quality_service.dart';

extension RoadQualityColor on RoadQuality {
  Color get mapColor {
    switch (this) {
      case RoadQuality.good:
        return Colors.green;
      case RoadQuality.moderateGood:
        return Colors.yellow.shade700;
      case RoadQuality.moderateBad:
        return Colors.orange;
      case RoadQuality.bad:
        return Colors.red;
    }
  }

  String get label {
    switch (this) {
      case RoadQuality.good:
        return "Good";
      case RoadQuality.moderateGood:
        return "Moderately Good";
      case RoadQuality.moderateBad:
        return "Moderately Bad";
      case RoadQuality.bad:
        return "Bad";
    }
  }
}

class RoadQualityMapWidget extends StatelessWidget {
  final List<RoadQualitySegment> segments;

  const RoadQualityMapWidget({super.key, required this.segments});

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) {
      return const Card(
        child: SizedBox(
          height: 250,
          child: Center(child: Text("No road quality data available.")),
        ),
      );
    }

    final allPoints = segments.expand((s) => s.points).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 300,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: allPoints.first,
              initialZoom: 16,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.road_data_collector',
              ),
              PolylineLayer(
                polylines: [
                  for (final segment in segments)
                    Polyline(
                      points: segment.points,
                      strokeWidth: 5,
                      color: segment.quality.mapColor,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: allPoints.first,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.play_circle_fill, color: Colors.blue, size: 32),
                  ),
                  Marker(
                    point: allPoints.last,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.flag, color: Colors.black, size: 32),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: RoadQuality.values
              .map((q) => Chip(
                    avatar: CircleAvatar(backgroundColor: q.mapColor),
                    label: Text(q.label),
                  ))
              .toList(),
        ),
      ],
    );
  }
}