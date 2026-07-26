import 'package:flutter/material.dart';

class SensorsPage extends StatelessWidget {
  const SensorsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sensors")),
      body: const Center(
        child: Text(
          "Sensors Module\n(Coming Soon)",
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}