import 'dart:io';

import '../../features/sessions/session_model.dart';

class SessionDeleteService {
  Future<void> delete(SessionModel session) async {
    final directory = Directory(session.path);

    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}