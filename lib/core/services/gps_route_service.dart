import 'dart:io';

import 'package:latlong2/latlong.dart';

class GpsRouteService {
  Future<List<LatLng>> loadRoute(String gpsFilePath) async {
    final file = File(gpsFilePath);

    if (!await file.exists()) {
      return [];
    }

    final lines = await file.readAsLines();

    if (lines.length <= 1) {
      return [];
    }

    final points = <LatLng>[];

    for (final line in lines.skip(1)) {
      final parts = line.split(',');

      if (parts.length < 3) continue;

      final latitude = double.tryParse(parts[1]);
      final longitude = double.tryParse(parts[2]);

      if (latitude == null || longitude == null) continue;

      points.add(
        LatLng(latitude, longitude),
      );
    }

    return points;
  }
}