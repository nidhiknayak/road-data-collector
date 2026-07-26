import 'package:sensors_plus/sensors_plus.dart';

class ImuService {
  Stream<AccelerometerEvent> get accelerometer =>
      accelerometerEventStream();

  Stream<GyroscopeEvent> get gyroscope =>
      gyroscopeEventStream();

  Stream<MagnetometerEvent> get magnetometer =>
      magnetometerEventStream();
}