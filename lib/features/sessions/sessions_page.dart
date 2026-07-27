import 'package:flutter/material.dart';

import '../../core/services/session_service.dart';
import 'session_details_page.dart';
import 'session_model.dart';

class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key});

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  final SessionService _service = SessionService();

  late Future<List<SessionModel>> _sessions;

  @override
  void initState() {
    super.initState();
    _sessions = _service.getSessions();
  }

  Future<void> _refresh() async {
    setState(() {
      _sessions = _service.getSessions();
    });

    await _sessions;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds =
        (duration.inSeconds % 60).toString().padLeft(2, '0');

    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sessions"),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<SessionModel>>(
          future: _sessions,
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  "Error: ${snapshot.error}",
                ),
              );
            }

            final sessions = snapshot.data ?? [];

            if (sessions.isEmpty) {
              return const Center(
                child: Text("No recordings yet"),
              );
            }

            return ListView.builder(
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.folder),
                    title: Text(session.id),
                    subtitle: Text(
                      _formatDuration(session.duration),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                    ),
                    onTap: () async {
                      final deleted =
                          await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SessionDetailsPage(
                            session: session,
                          ),
                        ),
                      );

                      if (deleted == true) {
                        _refresh();
                      }
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}