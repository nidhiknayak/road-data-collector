import 'package:flutter/material.dart';

class RecordingPage extends StatelessWidget {
  const RecordingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Recording")),
      body: const Center(
        child: Text(
          "Recording Module\n(Coming Soon)",
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}