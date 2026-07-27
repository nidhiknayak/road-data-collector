import 'package:share_plus/share_plus.dart';

import '../../features/sessions/session_model.dart';

class ExportService {
  Future<void> shareSession(SessionModel session) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(session.videoPath),
          XFile(session.gpsPath),
          XFile(session.imuPath),
          XFile(session.metadataPath),
        ],
        text: session.id,
      ),
    );
  }
}