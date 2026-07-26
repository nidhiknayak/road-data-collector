import 'package:flutter/material.dart';

class GpsPage extends StatelessWidget {
  const GpsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("GPS")),
      body: const Center(
        child: Text(
          "GPS Module\n(Coming Soon)",
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}