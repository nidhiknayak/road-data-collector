import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

/// Human-readable view of a session's correlation.json — the per-bucket
/// GPS/IMU/video correlation produced by CorrelationService.
class CorrelationViewerPage extends StatefulWidget {
  final String correlationPath;

  const CorrelationViewerPage({super.key, required this.correlationPath});

  @override
  State<CorrelationViewerPage> createState() => _CorrelationViewerPageState();
}

class _CorrelationViewerPageState extends State<CorrelationViewerPage> {
  bool _loading = true;
  String? _error;

  int _bucketMs = 0;
  double _potholeThreshold = 0;
  List<Map<String, dynamic>> _buckets = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final file = File(widget.correlationPath);

      if (!await file.exists()) {
        if (!mounted) return;
        setState(() {
          _error = "correlation.json not found for this session. "
              "Generate it first from Session Details.";
          _loading = false;
        });
        return;
      }

      final decoded = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final buckets = (decoded["buckets"] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      if (!mounted) return;
      setState(() {
        _bucketMs = decoded["bucket_ms"] as int? ?? 0;
        _potholeThreshold = (decoded["pothole_threshold"] as num?)?.toDouble() ?? 0;
        _buckets = buckets;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Failed to read correlation.json: $e";
        _loading = false;
      });
    }
  }

  String _fmt(dynamic value, {int decimals = 2}) {
    if (value == null) return "-";
    if (value is num) return value.toStringAsFixed(decimals);
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final potholeCount = _buckets.where((b) => b["pothole"] == true).length;

    return Scaffold(
      appBar: AppBar(title: const Text("Correlation Data")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : Column(
                  children: [
                    Card(
                      margin: const EdgeInsets.all(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Summary",
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text("Bucket size: $_bucketMs ms"),
                            Text(
                              "Pothole threshold: ${_potholeThreshold.toStringAsFixed(2)} m/s²",
                            ),
                            Text("Total buckets: ${_buckets.length}"),
                            Text(
                              "Flagged as pothole: $potholeCount",
                              style: TextStyle(
                                color: potholeCount > 0 ? Colors.red : null,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _buckets.length,
                        itemBuilder: (context, index) {
                          final b = _buckets[index];
                          final isPothole = b["pothole"] == true;

                          return ListTile(
                            tileColor: isPothole
                                ? Colors.red.withValues(alpha: 0.08)
                                : null,
                            leading: Icon(
                              isPothole
                                  ? Icons.warning_amber_rounded
                                  : Icons.check_circle_outline,
                              color: isPothole ? Colors.red : Colors.green,
                            ),
                            title: Text(
                              "Bucket ${b["bucket_index"]} — "
                              "video ${_fmt(b["video_time_ms"], decimals: 0)}ms",
                            ),
                            subtitle: Text(
                              "lat=${_fmt(b["latitude"], decimals: 5)}, "
                              "lon=${_fmt(b["longitude"], decimals: 5)}, "
                              "speed=${_fmt(b["speed"])} m/s\n"
                              "accel_peak_deviation=${_fmt(b["accel_peak_deviation"])}",
                            ),
                            isThreeLine: true,
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}