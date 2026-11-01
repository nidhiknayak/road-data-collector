import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/road_rating.dart';
import 'logger_service.dart';

class SessionRatingService {
  static const String _component = "SessionRatingService";
  static const JsonEncoder _encoder = JsonEncoder.withIndent("  ");

  Future<void> setRating(String sessionPath, RoadRating rating) async {
    final metadataFile = File(p.join(sessionPath, "metadata.json"));

    if (!await metadataFile.exists()) {
      throw Exception("metadata.json not found for this session.");
    }

    final metadata =
        jsonDecode(await metadataFile.readAsString()) as Map<String, dynamic>;

    metadata["road_rating"] = rating.value;
    metadata["road_rating_score"] = rating.score;
    metadata["rated_at"] = DateTime.now().toIso8601String();

    await metadataFile.writeAsString(_encoder.convert(metadata));

    // If correlation data already exists, keep it in sync.
    final correlationFile = File(p.join(sessionPath, "correlation.json"));
    if (await correlationFile.exists()) {
      try {
        final data =
            jsonDecode(await correlationFile.readAsString())
                as Map<String, dynamic>;

        data["road_rating"] = rating.value;
        data["road_rating_score"] = rating.score;

        final buckets = data["buckets"];
        if (buckets is List) {
          for (final b in buckets) {
            if (b is Map<String, dynamic>) {
              b["road_rating"] = rating.value;
              b["road_rating_score"] = rating.score;
            }
          }
        }

        await correlationFile.writeAsString(_encoder.convert(data));
      } catch (e, stackTrace) {
        // Metadata is already saved; don't fail the whole rating over this.
        LoggerService.error(
          component: _component,
          operation: "setRating.patchCorrelation",
          message: "Failed to update correlation.json with rating",
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
  }
}
