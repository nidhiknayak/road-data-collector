import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/services/sensor_service.dart';

class SensorsPage extends StatelessWidget {
  const SensorsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sensorService = SensorService();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sensors"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            StreamBuilder<AccelerometerEvent>(
              stream: sensorService.accelerometer(),
              builder: (context, snapshot) {

                final data = snapshot.data;

                return Card(
                  child: ListTile(
                    title: const Text("Accelerometer"),
                    subtitle: Text(
                      data == null
                          ? "Waiting..."
                          : "x=${data.x.toStringAsFixed(2)}\n"
                            "y=${data.y.toStringAsFixed(2)}\n"
                            "z=${data.z.toStringAsFixed(2)}",
                    ),
                  ),
                );
              },
            ),

            StreamBuilder<GyroscopeEvent>(
              stream: sensorService.gyroscope(),
              builder: (context, snapshot) {

                final data = snapshot.data;

                return Card(
                  child: ListTile(
                    title: const Text("Gyroscope"),
                    subtitle: Text(
                      data == null
                          ? "Waiting..."
                          : "x=${data.x.toStringAsFixed(2)}\n"
                            "y=${data.y.toStringAsFixed(2)}\n"
                            "z=${data.z.toStringAsFixed(2)}",
                    ),
                  ),
                );
              },
            ),

            StreamBuilder<MagnetometerEvent>(
              stream: sensorService.magnetometer(),
              builder: (context, snapshot) {

                final data = snapshot.data;

                return Card(
                  child: ListTile(
                    title: const Text("Magnetometer"),
                    subtitle: Text(
                      data == null
                          ? "Waiting..."
                          : "x=${data.x.toStringAsFixed(2)}\n"
                            "y=${data.y.toStringAsFixed(2)}\n"
                            "z=${data.z.toStringAsFixed(2)}",
                    ),
                  ),
                );
              },
            ),

          ],
        ),
      ),
    );
  }
}