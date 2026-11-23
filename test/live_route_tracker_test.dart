import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_data_collector/core/models/live_road_quality.dart';
import 'package:road_data_collector/core/models/road_rating.dart';

void main() {
  late LiveRouteTracker route;
  setUp(() => route = LiveRouteTracker());

  test(
    'GPS time aligns to capture clock and rejects stale or pre-session fixes',
    () {
      final now = DateTime.utc(2026, 11, 22, 12);
      expect(
        LiveRouteTracker.elapsedAtGpsFix(
          fixTime: now.subtract(const Duration(seconds: 2)),
          now: now,
          callbackElapsedMs: 10000,
        ),
        8000,
      );
      expect(
        LiveRouteTracker.elapsedAtGpsFix(
          fixTime: now.subtract(const Duration(seconds: 6)),
          now: now,
          callbackElapsedMs: 10000,
        ),
        isNull,
      );
      expect(
        LiveRouteTracker.elapsedAtGpsFix(
          fixTime: now.subtract(const Duration(seconds: 2)),
          now: now,
          callbackElapsedMs: 1000,
        ),
        isNull,
      );
      expect(
        LiveRouteTracker.elapsedAtGpsFix(
          fixTime: now.add(const Duration(seconds: 2)),
          now: now,
          callbackElapsedMs: 10000,
        ),
        isNull,
      );
    },
  );
  void point(int time, {double accuracy = 4, double? latitude}) {
    route.addPosition(
      latitude: latitude ?? 13 + time / 100000000,
      longitude: 77,
      accuracy: accuracy,
      elapsedMs: time,
    );
  }

  VisionEstimate estimate(
    int start,
    int end, {
    String status = 'prediction',
    RoadRating rating = RoadRating.good,
  }) => VisionEstimate(
    status: status,
    startMs: start,
    endMs: end,
    rawRating: rating,
    score: .8,
    frames: 3,
  );

  test(
    'delayed camera result colours covered GPS only and cannot rewrite completed road',
    () {
      point(0);
      point(1000);
      point(2000);
      point(3000);
      route.apply(estimate(0, 1500, rating: RoadRating.bad));
      expect(route.edges.map((e) => e.rating), [RoadRating.bad, null, null]);
      route.apply(estimate(0, 1400)); // Out of order.
      expect(route.edges.first.rating, RoadRating.bad);
      route.apply(estimate(0, 2500));
      expect(route.edges.map((e) => e.rating), [
        RoadRating.bad,
        RoadRating.good,
        null,
      ]);
    },
  );

  test('warm-up can mature but uncertain and missing road remain grey', () {
    point(0);
    point(1000);
    point(2000);
    point(3000);
    point(4000);
    route.apply(estimate(0, 1000, status: 'warming_up'));
    route.apply(estimate(0, 2000));
    expect(
      route.edges.take(2).every((e) => e.rating == RoadRating.good),
      isTrue,
    );
    route.apply(estimate(3000, 3000, status: 'road_not_visible'));
    route.apply(estimate(0, 4000));
    expect(route.edges[2].rating, isNull);
    expect(route.edges[2].estimate!.status, 'road_not_visible');
    expect(route.edges[3].rating, RoadRating.good);
  });

  test(
    'poor GPS, impossible jumps and long gaps never create connecting lines',
    () {
      point(0);
      point(1000, accuracy: 100);
      point(2000);
      expect(route.edges, isEmpty);
      point(3000);
      expect(route.edges, hasLength(1));
      point(4000, latitude: 14); // More than 100km in one second.
      point(5000);
      expect(route.edges, hasLength(1));
      point(20000);
      expect(route.edges, hasLength(1));
      point(21000);
      expect(route.edges, hasLength(2));
      expect(route.points.every((p) => p.position.latitude < 14), isTrue);
    },
  );

  test(
    'GeoJSON round trip keeps uncertain raw scores separate from route rating',
    () {
      point(0);
      point(1000);
      route.apply(
        const VisionEstimate(
          status: 'uncertain',
          startMs: 0,
          endMs: 1000,
          rawRating: RoadRating.good,
          score: .49,
          scores: {'good': .49},
          frames: 3,
        ),
      );
      final json =
          jsonDecode(jsonEncode(route.toGeoJson())) as Map<String, dynamic>;
      expect(json['features'][0]['properties']['road_rating'], isNull);
      final edges = LiveRouteTracker.fromGeoJson(json);
      expect(edges.single.rating, isNull);
      expect(edges.single.estimate!.rawRating, RoadRating.good);
      expect(edges.single.estimate!.scores['good'], .49);
      expect(edges.single.end.elapsedMs, 1000);
    },
  );

  test('invalid coordinates and reversed prediction windows are ignored', () {
    point(0);
    point(1000);
    expect(
      route.addPosition(
        latitude: double.nan,
        longitude: 77,
        accuracy: 4,
        elapsedMs: 2000,
      ),
      isFalse,
    );
    route.apply(estimate(3000, 2000));
    expect(route.edges.single.rating, isNull);
    expect(route.toGeoJson()['source'], 'experimental_camera_vision');
  });

  test('stationary GPS jitter does not inflate mapped distance', () {
    route.addPosition(latitude: 13, longitude: 77, accuracy: 4, elapsedMs: 0);
    route.addPosition(
      latitude: 13.00001,
      longitude: 77,
      accuracy: 4,
      elapsedMs: 1000,
      moving: false,
    );
    route.addPosition(
      latitude: 13.00002,
      longitude: 77,
      accuracy: 4,
      elapsedMs: 2000,
      moving: false,
    );
    expect(route.edges, isEmpty);
    expect(route.distanceMeters, 0);
    expect(route.points, hasLength(3));
  });

  test(
    'manual correction changes saved route but preserves raw prediction',
    () {
      point(0);
      point(1000);
      point(2000);
      final original = estimate(0, 1500, rating: RoadRating.bad);
      route.apply(original);
      expect(route.correct(original, RoadRating.veryGood), 1);
      expect(route.edges.first.rating, RoadRating.veryGood);
      expect(route.edges.first.estimate!.rawRating, RoadRating.bad);
      final json =
          jsonDecode(jsonEncode(route.toGeoJson())) as Map<String, dynamic>;
      final restored = LiveRouteTracker.fromGeoJson(json);
      expect(restored.first.rating, RoadRating.veryGood);
      expect(restored.first.estimate!.rawRating, RoadRating.bad);
      expect(restored.last.rating, isNull);
    },
  );
}
