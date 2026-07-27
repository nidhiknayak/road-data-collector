import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../features/sessions/session_model.dart';

class SessionService {
  Future<List<SessionModel>> getSessions() async {
    final dir = await getExternalStorageDirectory();

    if (dir == null) {
      return [];
    }

    final sessions = <SessionModel>[];

    final folders = dir
        .listSync()
        .whereType<Directory>()
        .where(
          (d) => path.basename(d.path).startsWith("Session_"),
        );

    for (final folder in folders) {
      final metadataFile = File(
        path.join(folder.path, "metadata.json"),
      );

      if (!metadataFile.existsSync()) continue;

      final json = jsonDecode(
        await metadataFile.readAsString(),
      );

      sessions.add(
        SessionModel(
          id: json["session_id"],
          path: folder.path,
          startTime: DateTime.tryParse(
            json["start_time"],
          ),
          duration: Duration(
            milliseconds: json["duration_ms"],
          ),
        ),
      );
    }

    sessions.sort(
      (a, b) =>
          (b.startTime ?? DateTime(0))
              .compareTo(a.startTime ?? DateTime(0)),
    );

    return sessions;
  }
}