import 'package:flutter/material.dart';
import '../features/home/home_page.dart';
import 'theme.dart';

class RoadDataCollectorApp extends StatelessWidget {
  const RoadDataCollectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Road Data Collector',
      theme: buildAppTheme(),
      home: const HomePage(),
    );
  }
}