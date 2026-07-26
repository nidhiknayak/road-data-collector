import 'package:flutter/material.dart';

class CameraPage extends StatelessWidget {
  const CameraPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Camera")),
      body: const Center(
        child: Text(
          "Camera Module\n(Coming Soon)",
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}