import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/models/live_road_quality.dart';
import '../../core/models/road_rating.dart';

const pendingRouteColor = Color(0xFF8B929C);

List<Polyline> routePolylines(List<LiveRouteEdge> edges) {
  final lines = <Polyline>[];
  var points = <LatLng>[];
  RoadRating? rating;
  int? previousEnd;
  void finish() {
    if (points.length < 2) return;
    lines.add(
      Polyline(
        points: points,
        strokeWidth: rating == null ? 5 : 7,
        color: rating?.color ?? pendingRouteColor,
        borderStrokeWidth: 1.5,
        borderColor: Colors.white,
      ),
    );
  }

  for (final edge in edges) {
    if (points.isEmpty ||
        rating != edge.rating ||
        previousEnd != edge.start.elapsedMs) {
      finish();
      points = [edge.start.position];
      rating = edge.rating;
    }
    points.add(edge.end.position);
    previousEnd = edge.end.elapsedMs;
  }
  finish();
  return lines;
}

class LiveRouteMap extends StatelessWidget {
  final MapController controller;
  final List<LiveRouteEdge> edges;
  final LatLng? location;
  final VoidCallback? onReady;
  final VoidCallback? onGesture;
  const LiveRouteMap({
    super.key,
    required this.controller,
    required this.edges,
    this.location,
    this.onReady,
    this.onGesture,
  });

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      FlutterMap(
        mapController: controller,
        options: MapOptions(
          initialCenter:
              location ??
              (edges.isEmpty
                  ? const LatLng(12.9716, 77.5946)
                  : edges.first.start.position),
          initialZoom: location == null && edges.isEmpty ? 11 : 17,
          onMapReady: onReady,
          onPositionChanged: (_, gesture) {
            if (gesture) onGesture?.call();
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.road_data_collector',
          ),
          PolylineLayer(polylines: routePolylines(edges)),
          if (location != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: location!,
                  width: 30,
                  height: 30,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: const [
                        BoxShadow(blurRadius: 5, color: Colors.black26),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      const Positioned(
        right: 4,
        bottom: 4,
        child: ColoredBox(
          color: Colors.white,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            child: Text(
              '© OpenStreetMap contributors',
              style: TextStyle(fontSize: 10, color: Colors.black87),
            ),
          ),
        ),
      ),
    ],
  );
}

class RoadMapLegend extends StatelessWidget {
  const RoadMapLegend({super.key});
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 6,
    children: [
      for (final rating in RoadRating.values.reversed)
        _entry(rating.color, rating.label),
      _entry(pendingRouteColor, 'Pending / uncertain'),
    ],
  );
  Widget _entry(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 5,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11)),
    ],
  );
}

class RecordedLiveRoutePage extends StatefulWidget {
  final String geoJsonPath;
  const RecordedLiveRoutePage({super.key, required this.geoJsonPath});
  @override
  State<RecordedLiveRoutePage> createState() => _RecordedLiveRoutePageState();
}

class _RecordedLiveRoutePageState extends State<RecordedLiveRoutePage> {
  final _controller = MapController();
  List<LiveRouteEdge>? _edges;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final json =
          jsonDecode(await File(widget.geoJsonPath).readAsString())
              as Map<String, dynamic>;
      final edges = LiveRouteTracker.fromGeoJson(json);
      if (mounted) setState(() => _edges = edges);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'The saved road map could not be read.');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Recorded road map')),
    body: _error != null
        ? Center(child: Text(_error!))
        : _edges == null
        ? const Center(child: CircularProgressIndicator())
        : _edges!.isEmpty
        ? const Center(child: Text('No usable GPS route was recorded.'))
        : Column(
            children: [
              Expanded(
                child: LiveRouteMap(
                  controller: _controller,
                  edges: _edges!,
                  onReady: () {
                    _controller.fitCamera(
                      CameraFit.bounds(
                        bounds: LatLngBounds.fromPoints([
                          _edges!.first.start.position,
                          ..._edges!.map((e) => e.end.position),
                        ]),
                        padding: const EdgeInsets.all(36),
                        maxZoom: 18,
                      ),
                    );
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  children: [
                    RoadMapLegend(),
                    SizedBox(height: 8),
                    Text(
                      'Experimental camera estimates',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
  );
}
