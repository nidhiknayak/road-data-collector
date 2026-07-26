import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class CollectionService {
  Directory? sessionDirectory;

  Future<Directory> createSession() async {
    final appDir = await getExternalStorageDirectory();

    final now = DateTime.now();

    final sessionName =
        "Session_${now.year}"
        "${now.month.toString().padLeft(2, '0')}"
        "${now.day.toString().padLeft(2, '0')}_"
        "${now.hour.toString().padLeft(2, '0')}"
        "${now.minute.toString().padLeft(2, '0')}"
        "${now.second.toString().padLeft(2, '0')}";

    final folder = Directory(
      path.join(appDir!.path, sessionName),
    );

    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    sessionDirectory = folder;

    return folder;
  }
}