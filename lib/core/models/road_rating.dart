import 'package:flutter/material.dart';

enum RoadRating {
  veryBad(
    'very_bad',
    'Very Bad',
    1,
    Color(0xFFC62828),
    Icons.sentiment_very_dissatisfied,
  ),
  bad('bad', 'Bad', 2, Color(0xFFEF6C00), Icons.sentiment_dissatisfied),
  good('good', 'Good', 3, Color(0xFF7CB342), Icons.sentiment_satisfied),
  veryGood(
    'very_good',
    'Very Good',
    4,
    Color(0xFF2E7D32),
    Icons.sentiment_very_satisfied,
  );

  final String value; // what gets written to JSON
  final String label;
  final int score; // 1 (very bad) .. 4 (very good), handy for training
  final Color color;
  final IconData icon;

  const RoadRating(this.value, this.label, this.score, this.color, this.icon);

  static RoadRating? fromValue(String? value) {
    for (final r in RoadRating.values) {
      if (r.value == value) return r;
    }
    return null;
  }
}
