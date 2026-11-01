import 'package:flutter/material.dart';

import '../../core/models/road_rating.dart';

/// Bottom sheet shown after a recording. Pops with the chosen RoadRating,
/// or null if the driver skips.
class RatingSheet extends StatelessWidget {
  const RatingSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "How was the road?",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                "This is saved as the ground-truth label for this session.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              for (final r in RoadRating.values.reversed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: r.color,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                      ),
                      onPressed: () => Navigator.pop(context, r),
                      icon: Icon(r.icon),
                      label: Text(r.label),
                    ),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Skip for now"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
