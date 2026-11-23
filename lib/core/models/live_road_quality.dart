import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'road_rating.dart';

class VisionEstimate {
  final String status;
  final RoadRating? rawRating;
  final double? score;
  final Map<String, double> scores;
  final int startMs, endMs, frames, processingMs;
  final String? modelId;

  const VisionEstimate({
    required this.status,
    required this.startMs,
    required this.endMs,
    this.rawRating,
    this.score,
    this.scores = const {},
    this.frames = 0,
    this.processingMs = 0,
    this.modelId,
  });

  factory VisionEstimate.fromMap(Map<String, dynamic> map) => VisionEstimate(
    status: map['status'] as String? ?? 'unavailable',
    startMs: (map['window_start_ms'] as num).toInt(),
    endMs: (map['window_end_ms'] as num).toInt(),
    rawRating: RoadRating.fromValue(map['predicted_class'] as String?),
    score: (map['score'] as num?)?.toDouble(),
    scores:
        (map['scores'] as Map?)?.map(
          (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
        ) ??
        {},
    frames: (map['valid_frames'] as num?)?.toInt() ?? 0,
    processingMs: (map['processing_ms'] as num?)?.toInt() ?? 0,
    modelId: map['model_id'] as String?,
  );

  RoadRating? get rating => status == 'prediction' ? rawRating : null;

  String get label => switch (status) {
    'prediction' => rawRating?.label ?? 'Uncertain',
    'warming_up' => 'Reading the road…',
    'road_not_visible' => 'Road not visible',
    'uncertain' => 'Uncertain',
    _ => 'Model unavailable',
  };

  Map<String, dynamic> toJson() => {
    'status': status,
    'predicted_class': rawRating?.value,
    'score': score,
    'scores': scores,
    'window_start_ms': startMs,
    'window_end_ms': endMs,
    'valid_frames': frames,
    'processing_ms': processingMs,
    'model_id': modelId,
  };
}

class LiveRoutePoint {
  final LatLng position;
  final int elapsedMs;
  final double accuracy;
  const LiveRoutePoint(this.position, this.elapsedMs, this.accuracy);
}

class LiveRouteEdge {
  final LiveRoutePoint start, end;
  VisionEstimate? estimate;
  RoadRating? manualRating;
  LiveRouteEdge(this.start, this.end, {this.estimate, this.manualRating});
  RoadRating? get rating => manualRating ?? estimate?.rating;
}

/// Delayed results can colour only GPS edges covered by their capture window.
/// Unknown data, poor GPS and gaps never inherit the last "good" result.
class LiveRouteTracker {
  final List<LiveRoutePoint> points = [];
  final List<LiveRouteEdge> edges = [];
  LiveRoutePoint? _previous;
  bool _breakRoute = false;
  int _lastResultMs = -1;
  double distanceMeters = 0;
  static const _distance = Distance();

  void breakTracking() => _breakRoute = true;

  static int? elapsedAtGpsFix({
    required DateTime fixTime,
    required DateTime now,
    required int callbackElapsedMs,
  }) {
    final age = now.difference(fixTime).inMilliseconds;
    final elapsed = callbackElapsedMs - math.max(0, age).toInt();
    if (age > 5000 || age < -1000 || elapsed < 0) return null;
    return elapsed;
  }

  bool addPosition({
    required double latitude,
    required double longitude,
    required double accuracy,
    required int elapsedMs,
    bool moving = true,
  }) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180 ||
        !accuracy.isFinite ||
        accuracy <= 0 ||
        accuracy > 25 ||
        elapsedMs < 0) {
      _breakRoute = true;
      return false;
    }
    final point = LiveRoutePoint(
      LatLng(latitude, longitude),
      elapsedMs,
      accuracy,
    );
    final previous = _previous;
    if (previous != null) {
      final delta = elapsedMs - previous.elapsedMs;
      if (delta <= 0) return false;
      final meters = _distance(previous.position, point.position);
      if (meters / (delta / 1000) > 60) {
        _breakRoute = true;
        return false;
      }
      if (!moving) {
        _previous = point;
        _breakRoute = true;
        points.add(point);
        return true;
      }
      if (!_breakRoute && delta <= 5000) {
        edges.add(LiveRouteEdge(previous, point));
        distanceMeters += meters;
      }
    }
    _breakRoute = false;
    _previous = point;
    points.add(point);
    return true;
  }

  void apply(VisionEstimate result) {
    if (result.endMs <= _lastResultMs || result.endMs < result.startMs) return;
    final start =
        result.status == 'road_not_visible' || result.status == 'unavailable'
        ? math.max(0, _lastResultMs)
        : result.startMs;
    for (final edge in edges) {
      if (edge.end.elapsedMs < start || edge.end.elapsedMs > result.endMs) {
        continue;
      }
      // First complete window may replace warm-up; later rolling windows may
      // not rewrite a completed segment or hide an earlier uncertainty.
      if (edge.estimate == null || edge.estimate!.status == 'warming_up') {
        edge.estimate = result;
      }
    }
    _lastResultMs = result.endMs;
  }

  int correct(VisionEstimate estimate, RoadRating rating) {
    var changed = 0;
    for (final edge in edges) {
      if (edge.end.elapsedMs >= estimate.startMs &&
          edge.end.elapsedMs <= estimate.endMs &&
          (edge.estimate == null || identical(edge.estimate, estimate))) {
        edge.manualRating = rating;
        changed++;
      }
    }
    return changed;
  }

  Map<String, dynamic> toGeoJson() => {
    'type': 'FeatureCollection',
    'source': 'experimental_camera_vision',
    'features': [
      for (final edge in edges)
        {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [edge.start.position.longitude, edge.start.position.latitude],
              [edge.end.position.longitude, edge.end.position.latitude],
            ],
          },
          'properties': {
            'start_elapsed_ms': edge.start.elapsedMs,
            'end_elapsed_ms': edge.end.elapsedMs,
            'start_accuracy_m': edge.start.accuracy,
            'end_accuracy_m': edge.end.accuracy,
            'road_rating': edge.rating?.value,
            'manual_road_rating': edge.manualRating?.value,
            'status': edge.estimate?.status ?? 'pending',
            if (edge.estimate != null) ...edge.estimate!.toJson(),
          },
        },
    ],
  };

  static List<LiveRouteEdge> fromGeoJson(Map<String, dynamic> json) {
    final result = <LiveRouteEdge>[];
    for (final feature in (json['features'] as List)) {
      final coordinates = feature['geometry']['coordinates'] as List;
      final p = Map<String, dynamic>.from(feature['properties'] as Map);
      final a = coordinates.first as List, b = coordinates.last as List;
      final start = LiveRoutePoint(
        LatLng((a[1] as num).toDouble(), (a[0] as num).toDouble()),
        (p['start_elapsed_ms'] as num).toInt(),
        (p['start_accuracy_m'] as num).toDouble(),
      );
      final end = LiveRoutePoint(
        LatLng((b[1] as num).toDouble(), (b[0] as num).toDouble()),
        (p['end_elapsed_ms'] as num).toInt(),
        (p['end_accuracy_m'] as num).toDouble(),
      );
      result.add(
        LiveRouteEdge(
          start,
          end,
          estimate: p.containsKey('window_end_ms')
              ? VisionEstimate.fromMap(p)
              : null,
          manualRating: RoadRating.fromValue(
            p['manual_road_rating'] as String?,
          ),
        ),
      );
    }
    return result;
  }
}
