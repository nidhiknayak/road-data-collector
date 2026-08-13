import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

/// Human-readable view of a session's metadata.json, instead of requiring
/// the user to open the raw file.
class MetadataViewerPage extends StatefulWidget {
  final String metadataPath;

  const MetadataViewerPage({super.key, required this.metadataPath});

  @override
  State<MetadataViewerPage> createState() => _MetadataViewerPageState();
}

class _MetadataViewerPageState extends State<MetadataViewerPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final file = File(widget.metadataPath);

      if (!await file.exists()) {
        if (!mounted) return;
        setState(() {
          _error = "metadata.json not found for this session.";
          _loading = false;
        });
        return;
      }

      final decoded = jsonDecode(await file.readAsString());

      if (!mounted) return;
      setState(() {
        _data = decoded is Map<String, dynamic> ? decoded : {};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Failed to read metadata.json: $e";
        _loading = false;
      });
    }
  }

  String _label(String key) {
    return key
        .split("_")
        .map((w) => w.isEmpty ? w : "${w[0].toUpperCase()}${w.substring(1)}")
        .join(" ");
  }

  String _displayValue(String key, dynamic value) {
    if (value == null) return "-";

    if (key == "duration_ms" && value is int) {
      final d = Duration(milliseconds: value);
      final h = d.inHours;
      final m = d.inMinutes.remainder(60);
      final s = d.inSeconds.remainder(60);
      return "${h}h ${m}m ${s}s ($value ms)";
    }

    if ((key == "start_time" || key == "end_time") && value is String) {
      final parsed = DateTime.tryParse(value);
      return parsed?.toString() ?? value;
    }

    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Session Metadata")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: _data.entries
                      .map(
                        (e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _label(e.key),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(_displayValue(e.key, e.value)),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
    );
  }
}