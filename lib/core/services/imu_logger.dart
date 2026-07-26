import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'imu_service.dart';
import 'session_clock.dart';

class ImuLogger {
  IOSink? _sink;

  StreamSubscription<AccelerometerEvent>? _accelerometerSub;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSub;
  StreamSubscription<MagnetometerEvent>? _magnetometerSub;

  double _gx = 0, _gy = 0, _gz = 0;
  double _mx = 0, _my = 0, _mz = 0;

  bool _active = false;

  bool get isActive => _active;

  Future<void> start(
    ImuService imuService,
    File file,
    SessionClock clock,
  ) async {
    if (_sink != null) return;

    _active = true;

    debugPrint("Opening IMU file: ${file.path}");

    _sink = file.openWrite();

    _sink!.writeln(
      "elapsed_ms,ax,ay,az,gx,gy,gz,mx,my,mz",
    );

    await _sink!.flush();

    _gyroscopeSub = imuService.gyroscope.listen((event) {
      _gx = event.x;
      _gy = event.y;
      _gz = event.z;
    });

    _magnetometerSub = imuService.magnetometer.listen((event) {
      _mx = event.x;
      _my = event.y;
      _mz = event.z;
    });

    _accelerometerSub = imuService.accelerometer.listen((event) async {
      _sink!.writeln(
        "${clock.elapsedMilliseconds},"
        "${event.x},"
        "${event.y},"
        "${event.z},"
        "$_gx,$_gy,$_gz,"
        "$_mx,$_my,$_mz",
      );

      await _sink!.flush();
    });
  }

  Future<void> stop() async {
    await _accelerometerSub?.cancel();
    await _gyroscopeSub?.cancel();
    await _magnetometerSub?.cancel();

    await _sink?.flush();
    await _sink?.close();

    _accelerometerSub = null;
    _gyroscopeSub = null;
    _magnetometerSub = null;
    _sink = null;

    _active = false;
  }
}