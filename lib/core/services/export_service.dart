import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/sessions/session_model.dart';

class ExportService {
  Future<File> createZip(SessionModel session) async {
    final archive = Archive();

    final sessionDirectory =
        Directory(p.dirname(session.metadataPath));

    final files = sessionDirectory.listSync(recursive: true);

    for (final entity in files) {
      if (entity is File) {
        final relativePath =
            p.relative(entity.path, from: sessionDirectory.path);

        archive.addFile(
          ArchiveFile(
            relativePath,
            await entity.length(),
            await entity.readAsBytes(),
          ),
        );
      }
    }

    final bytes = ZipEncoder().encode(archive);

    if (bytes == null) {
      throw Exception("Failed to create ZIP archive.");
    }

    final tempDir = await getTemporaryDirectory();

    final zipFile = File(
      p.join(tempDir.path, "${session.id}.zip"),
    );

    await zipFile.writeAsBytes(bytes);

    return zipFile;
  }

  Future<void> shareSession(SessionModel session) async {
    final zip = await createZip(session);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(zip.path)],
        text: session.id,
      ),
    );
  }
}