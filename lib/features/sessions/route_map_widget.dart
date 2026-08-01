import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RouteMapWidget extends StatelessWidget {
  final List<LatLng> route;

  const RouteMapWidget({
    super.key,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    if (route.isEmpty) {
      return const Card(
        child: SizedBox(
          height: 250,
          child: Center(
            child: Text("No GPS data available."),
          ),
        ),
      );
    }

    return SizedBox(
      height: 300,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: route.first,
          initialZoom: 16,
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.road_data_collector',
          ),

          PolylineLayer(
            polylines: [
              Polyline(
                points: route,
                strokeWidth: 4,
                color: Colors.blue,
              ),
            ],
          ),

          MarkerLayer(
            markers: [
              Marker(
                point: route.first,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.play_circle_fill,
                  color: Colors.green,
                  size: 32,
                ),
              ),

              Marker(
                point: route.last,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 32,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}