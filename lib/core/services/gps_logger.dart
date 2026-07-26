import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'session_clock.dart';

class GpsLogger {
  IOSink? _sink;
  StreamSubscription<Position>? _subscription;

  Future<void> start(
    Stream<Position> stream,
    File file,
    SessionClock clock,
  ) async {
    // Prevent starting twice.
    if (_subscription != null) return;

    debugPrint("Opening GPS file: ${file.path}");

    _sink = file.openWrite();

    _sink!.writeln(
      "elapsed_ms,latitude,longitude,altitude,speed,speed_accuracy,heading,accuracy",
    );

    await _sink!.flush();

    _subscription = stream.listen(
      (Position position) async {
        debugPrint(
          "GPS: ${position.latitude}, ${position.longitude}",
        );

        _sink!.writeln(
          "${clock.elapsedMilliseconds},"
          "${position.latitude},"
          "${position.longitude},"
          "${position.altitude},"
          "${position.speed},"
          "${position.speedAccuracy},"
          "${position.heading},"
          "${position.accuracy}",
        );

        await _sink!.flush();
      },
      onError: (Object error) {
        debugPrint("GPS ERROR: $error");
      },
    );
  }

  Future<void> stop() async {
    await _subscription?.cancel();

    await _sink?.flush();
    await _sink?.close();

    _subscription = null;
    _sink = null;
  }
}