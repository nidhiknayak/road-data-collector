import 'dart:io';

import 'package:flutter/material.dart';

/// Raw scrollable table view of a session's imu.csv.
class ImuViewerPage extends StatefulWidget {
  final String imuPath;

  const ImuViewerPage({super.key, required this.imuPath});

  @override
  State<ImuViewerPage> createState() => _ImuViewerPageState();
}

class _ImuViewerPageState extends State<ImuViewerPage> {
  static const List<String> _columns = [
    "elapsed_ms",
    "ax",
    "ay",
    "az",
    "gx",
    "gy",
    "gz",
    "mx",
    "my",
    "mz",
  ];

  static const double _columnWidth = 100;

  bool _loading = true;
  String? _error;
  List<List<String>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final file = File(widget.imuPath);

      if (!await file.exists()) {
        if (!mounted) return;
        setState(() {
          _error = "imu.csv not found for this session.";
          _loading = false;
        });
        return;
      }

      final lines = await file.readAsLines();
      final dataLines = lines.where((l) => l.trim().isNotEmpty).toList();

      // If the first line's first field isn't numeric, it's a header row
      // written by the logger — skip it, since we render our own fixed
      // header below regardless.
      if (dataLines.isNotEmpty) {
        final firstField = dataLines.first.split(",").first.trim();
        if (double.tryParse(firstField) == null) {
          dataLines.removeAt(0);
        }
      }

      final parsed = dataLines.map((line) => line.split(",")).toList();

      if (!mounted) return;
      setState(() {
        _rows = parsed;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Failed to read imu.csv: $e";
        _loading = false;
      });
    }
  }

  Widget _buildHeaderRow(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: _columns
            .map(
              (c) => SizedBox(
                width: _columnWidth,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: Text(
                    c,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildDataRow(BuildContext context, List<String> row, int index) {
    return ColoredBox(
      color: index.isEven
          ? Colors.transparent
          : Theme.of(context).colorScheme.surfaceContainerLow,
      child: Row(
        children: List.generate(_columns.length, (i) {
          final value = i < row.length ? row[i] : "";
          return SizedBox(
            width: _columnWidth,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Text(
                value,
                style: const TextStyle(fontFamily: "monospace"),
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalWidth = _columnWidth * _columns.length;

    return Scaffold(
      appBar: AppBar(title: Text("IMU Data (${_rows.length} rows)")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: totalWidth,
                          child: Column(
                            children: [
                              _buildHeaderRow(context),
                              const Divider(height: 1),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: _rows.length,
                                  itemBuilder: (context, index) =>
                                      _buildDataRow(
                                    context,
                                    _rows[index],
                                    index,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}