import '../../core/models/road_rating.dart';

class SessionModel {
  final String id;
  final String path;
  final DateTime? startTime;
  final Duration duration;
  final RoadRating? rating;

  const SessionModel({
    required this.id,
    required this.path,
    required this.startTime,
    required this.duration,
    this.rating,
  });

  String get videoPath => "$path/video.mp4";

  String get gpsPath => "$path/gps.csv";

  String get imuPath => "$path/imu.csv";

  String get metadataPath => "$path/metadata.json";

  String get correlationPath => "$path/correlation.json";
}
