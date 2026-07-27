class SessionModel {
  final String id;
  final String path;
  final DateTime? startTime;
  final Duration duration;

  const SessionModel({
    required this.id,
    required this.path,
    required this.startTime,
    required this.duration,
  });

  String get videoPath => "$path/video.mp4";

  String get gpsPath => "$path/gps.csv";

  String get imuPath => "$path/imu.csv";

  String get metadataPath => "$path/metadata.json";
}