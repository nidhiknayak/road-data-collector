import 'package:sensors_plus/sensors_plus.dart';

class SensorService {
  Stream<AccelerometerEvent> accelerometer() => accelerometerEventStream();

  Stream<GyroscopeEvent> gyroscope() => gyroscopeEventStream();

  Stream<MagnetometerEvent> magnetometer() => magnetometerEventStream();
}