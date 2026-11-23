import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/live_road_quality.dart';
import '../../core/models/road_rating.dart';
import '../../core/services/camera_service.dart';
import '../../core/services/collection_service.dart';
import '../../core/services/gps_service.dart';
import '../../core/services/live_vision_service.dart';
import '../../core/services/permission_service.dart';
import '../../core/services/session_rating_service.dart';
import '../sessions/rating_sheet.dart';
import 'live_route_map.dart';

class LiveMapPage extends StatefulWidget {
  final ValueChanged<bool>? onBusyChanged;
  const LiveMapPage({super.key, this.onBusyChanged});
  @override
  State<LiveMapPage> createState() => _LiveMapPageState();
}

class _LiveMapPageState extends State<LiveMapPage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final _map = MapController();
  final _camera = CameraService(
    resolutionPreset: ResolutionPreset.high,
    imageFormatGroup: ImageFormatGroup.nv21,
  );
  final _gps = GpsService();
  final _vision = LiveVisionService();
  CollectionService? _collection;
  LiveRouteTracker _route = LiveRouteTracker();
  VisionEstimate? _estimate;
  RoadRating? _shownCorrection;
  int? _correctedWindowEndMs;
  StreamSubscription<Position>? _gpsSubscription;
  IOSink? _predictions;
  IOSink? _feedback;
  Directory? _directory;
  Timer? _timer;
  Future<void>? _analysis;
  Future<void> _saving = Future.value();
  bool _recording = false,
      _processing = false,
      _stopping = false,
      _disposed = false;
  bool _mapReady = false, _follow = true;
  int _epoch = 0, _lastSampleMs = -1000, _errors = 0, _lastFixMs = -10000;
  Duration _elapsed = Duration.zero;
  String _view = 'bike';
  String? _gpsMessage, _error, _lastSessionPath;
  double _speed = 0;
  Map<String, dynamic>? _modelInfo;

  @override
  bool get wantKeepAlive => true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadView();
  }

  Future<void> _loadView() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final view = preferences.getString('live_map_camera_view');
      if (mounted && !_recording && !_processing && _views.containsKey(view)) {
        setState(() => _view = view!);
      }
    } catch (_) {
      /* The default view remains usable if preferences fail. */
    }
  }

  static const _views = {
    'bike': 'Bike mounted',
    'car_front': 'Car front seat',
    'car_side': 'Car side window',
    'handheld': 'Walking / handheld',
  };

  void _refresh() {
    if (mounted && !_disposed) setState(() {});
  }

  Future<void> _start() async {
    if (_processing || _recording) return;
    setState(() {
      _processing = true;
      _error = null;
    });
    widget.onBusyChanged?.call(true);
    try {
      await PermissionService().requestAllPermissions();
      if (!await PermissionService().hasAllPermissions()) {
        throw StateError('Camera and location permissions are needed.');
      }
      await _gps.initialize();
      _modelInfo = await _vision.initialize();
      await _vision.reset();
      _ensureForeground();
      await _camera.initialize();
      _ensureForeground();
      _route = LiveRouteTracker();
      _estimate = null;
      _shownCorrection = null;
      _correctedWindowEndMs = null;
      _elapsed = Duration.zero;
      _lastSampleMs = -1000;
      _errors = 0;
      _lastFixMs = -10000;
      _speed = 0;
      _follow = true;
      _gpsMessage = 'Waiting for a GPS fix';
      _lastSessionPath = null;
      _collection = CollectionService(
        cameraService: _camera,
        gpsService: _gps,
        extraMetadata: {
          'collection_mode': 'live_vision_map',
          'camera_position': switch (_view) {
            'car_side' => 'side_window',
            'car_front' => 'front_seat',
            'bike' => 'handlebar',
            _ => 'handheld',
          },
          'vision_camera_view': _view,
          'vehicle_type': _view == 'handheld'
              ? 'walking'
              : _view == 'bike'
              ? 'bike'
              : 'car',
          'vision_model_id': _modelInfo?['model_id'],
          'vision_experimental': true,
          'vision_predictions_file': 'vision_predictions.jsonl',
          'vision_route_file': 'vision_route.geojson',
          'vision_feedback_file': 'vision_feedback.jsonl',
        },
      );
      await _collection!.startRecordingSession(
        requireCamera: true,
        onFrame: _onFrame,
      );
      // Only the preview surface is unbound. Video and image analysis stay
      // active while Flutter displays the map instead of a camera texture.
      await _camera.controller!.pausePreview();
      if (_disposed) throw StateError('Screen closed.');
      _directory = _collection!.sessionDirectory;
      _predictions = File(
        '${_directory!.path}/vision_predictions.jsonl',
      ).openWrite();
      _feedback = File('${_directory!.path}/vision_feedback.jsonl').openWrite();
      _predictions!.done.catchError((Object error) {
        _error = 'The prediction log could not be saved.';
        _refresh();
      });
      _epoch++;
      _recording = true;
      _gpsSubscription = _gps.getPositionStream().listen(
        _onPosition,
        onError: (Object error) {
          _route.breakTracking();
          _gpsMessage = 'GPS unavailable. Recording continues.';
          _refresh();
        },
      );
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        _elapsed = _collection!.clock.elapsed;
        if (_elapsed.inSeconds % 5 == 0) _saveSnapshot();
        _refresh();
      });
    } catch (error) {
      _error = 'Could not start live mapping: $error';
      await _feedback?.close();
      _feedback = null;
      await _predictions?.close();
      _predictions = null;
      if (_collection?.hasActiveSession ?? false) {
        await _collection!.stopRecordingSession();
      }
      await _camera.dispose();
      if (!_disposed) widget.onBusyChanged?.call(false);
    } finally {
      _processing = false;
      _refresh();
    }
  }

  void _onPosition(Position position) {
    if (!_recording || _stopping) return;
    final elapsed = _collection!.clock.elapsedMilliseconds;
    final measured = LiveRouteTracker.elapsedAtGpsFix(
      fixTime: position.timestamp,
      now: DateTime.now(),
      callbackElapsedMs: elapsed,
    );
    if (measured == null) {
      _route.breakTracking();
      _gpsMessage = 'Waiting for a fresh GPS fix';
      _refresh();
      return;
    }
    final accepted = _route.addPosition(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      elapsedMs: measured,
      moving: position.speed < 0 || position.speed >= .5,
    );
    if (accepted) {
      _lastFixMs = measured;
      _gpsMessage = null;
      _speed = position.speed.isFinite ? position.speed.clamp(0, 100) * 3.6 : 0;
      if (_mapReady && _follow) _map.move(_route.points.last.position, 17);
    } else {
      _gpsMessage = 'GPS is imprecise; this stretch is not being mapped.';
    }
    _refresh();
  }

  void _ensureForeground() {
    final state = WidgetsBinding.instance.lifecycleState;
    if (_disposed ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      throw StateError('Keep the app open to start live mapping.');
    }
  }

  void _onFrame(CameraImage image) {
    if (!_recording ||
        _stopping ||
        _analysis != null ||
        _camera.controller == null) {
      return;
    }
    final elapsed = _collection!.clock.elapsedMilliseconds;
    if (elapsed - _lastSampleMs < (_errors == 0 ? 1000 : 3000)) return;
    _lastSampleMs = elapsed;
    final epoch = _epoch;
    _analysis = _analyze(
      image,
      elapsed,
      epoch,
    ).whenComplete(() => _analysis = null);
  }

  Future<void> _analyze(CameraImage image, int elapsed, int epoch) async {
    VisionEstimate estimate;
    try {
      estimate = await _vision.analyze(
        image,
        _camera.controller!,
        _view,
        elapsed,
      );
      _errors = 0;
    } catch (_) {
      _errors++;
      estimate = VisionEstimate(
        status: 'unavailable',
        startMs: elapsed,
        endMs: elapsed,
      );
      try {
        await _vision.reset();
      } catch (_) {
        /* Continue to save the recording. */
      }
    }
    if (epoch != _epoch || _disposed) return;
    _estimate = estimate;
    _shownCorrection = null;
    _correctedWindowEndMs = null;
    _route.apply(estimate);
    _predictions?.writeln(jsonEncode(estimate.toJson()));
    _refresh();
  }

  Future<void> _correctCurrentRating() async {
    final estimate = _estimate;
    final collection = _collection;
    final feedback = _feedback;
    if (!_recording ||
        _stopping ||
        estimate == null ||
        estimate.rating == null ||
        collection == null ||
        feedback == null ||
        collection.clock.elapsedMilliseconds - estimate.endMs > 8000) {
      return;
    }
    final epoch = _epoch;
    final tappedAt = collection.clock.elapsedMilliseconds;
    final point = _route.points.isEmpty ? null : _route.points.last;
    final rating = await showModalBottomSheet<RoadRating>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('What was this section really like?'),
              subtitle: Text('Your correction is saved with this recording.'),
            ),
            for (final option in RoadRating.values.reversed)
              ListTile(
                leading: Icon(option.icon, color: option.color),
                title: Text(option.label),
                onTap: () => Navigator.pop(context, option),
              ),
          ],
        ),
      ),
    );
    if (rating == null || !_recording || _stopping || epoch != _epoch) return;
    try {
      feedback.writeln(
        jsonEncode({
          'type': 'rating_correction',
          'window_start_ms': estimate.startMs,
          'window_end_ms': estimate.endMs,
          'tap_elapsed_ms': tappedAt,
          'saved_elapsed_ms': collection.clock.elapsedMilliseconds,
          'predicted_class': estimate.rawRating?.value,
          'predicted_status': estimate.status,
          'model_scores': estimate.scores,
          'model_id': estimate.modelId,
          'corrected_class': rating.value,
          'camera_view': _view,
          'video_file': 'video.mp4',
          'imu_file': 'imu.csv',
          if (point != null)
            'gps_fix': {
              'latitude': point.position.latitude,
              'longitude': point.position.longitude,
              'accuracy_m': point.accuracy,
              'elapsed_ms': point.elapsedMs,
            },
        }),
      );
      await feedback.flush();
      _route.correct(estimate, rating);
      if (identical(_estimate, estimate)) {
        _shownCorrection = rating;
        _correctedWindowEndMs = estimate.endMs;
      }
      _saveSnapshot();
      _refresh();
    } catch (_) {
      _error = 'This correction could not be saved.';
      _refresh();
    }
  }

  void _saveSnapshot() {
    final directory = _directory;
    if (directory == null) return;
    final data = jsonEncode(_route.toGeoJson());
    _saving = _saving
        .then((_) async {
          final temporary = File('${directory.path}/vision_route.geojson.tmp');
          await temporary.writeAsString(data, flush: true);
          await temporary.rename('${directory.path}/vision_route.geojson');
          await _predictions?.flush();
          await _feedback?.flush();
        })
        .catchError((Object error) {
          _error = 'The map could not be saved. Check available storage.';
          _refresh();
        });
  }

  Future<void> _stop({bool askRating = true}) async {
    if (_processing || _stopping || !_recording) return;
    _processing = true;
    _stopping = true;
    _timer?.cancel();
    _refresh();
    try {
      await _gpsSubscription?.cancel();
      _gpsSubscription = null;
      await _collection!.stopRecordingSession();
      await _analysis;
      _saveSnapshot();
      await _saving;
      await _predictions?.close();
      _predictions = null;
      await _feedback?.close();
      _feedback = null;
      _lastSessionPath = _collection!.lastSessionPath;
    } catch (error) {
      _error = 'Recording stopped, but some files could not be saved: $error';
    } finally {
      await _camera.dispose();
      _recording = false;
      _processing = false;
      _stopping = false;
      if (!_disposed) widget.onBusyChanged?.call(false);
      _refresh();
    }
    if (askRating && mounted && !_disposed && _lastSessionPath != null) {
      final rating = await showModalBottomSheet<RoadRating>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const RatingSheet(),
      );
      if (rating != null) {
        try {
          await SessionRatingService().setRating(_lastSessionPath!, rating);
        } catch (_) {
          _error = 'The manual session rating could not be saved.';
          _refresh();
        }
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (_recording && !_processing) unawaited(_stop(askRating: false));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    if (_recording && !_processing) {
      unawaited(_stop(askRating: false));
    } else if (!_processing) {
      unawaited(_camera.dispose());
    }
    _map.dispose();
    super.dispose();
  }

  void _showInfo() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Experimental road estimates'),
      content: Text(
        'The camera model estimates visible road condition. Its four-class accuracy was '
        '${((_modelInfo?["test_accuracy"] as num? ?? 4 / 13) * 100).toStringAsFixed(1)}% on 13 separate test videos. '
        'Grey means pending, uncertain or unavailable. These colours are not verified road ratings.\n\n'
        'Use Wrong rating to save a correction for the current section. The map updates immediately; the model learns from corrections after later training, not during this recording.\n\n'
        'Estimates run on your phone. OpenStreetMap tiles need an internet connection for new areas. '
        'Keep the app open while recording; leaving the app stops and saves the session.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final elapsed = _collection?.clock.elapsedMilliseconds ?? 0;
    final fresh = _estimate != null && elapsed - _estimate!.endMs <= 8000;
    final corrected = fresh && _correctedWindowEndMs == _estimate?.endMs
        ? _shownCorrection
        : null;
    final label = !_recording
        ? (_lastSessionPath == null ? 'Ready to map' : 'Route saved')
        : fresh
        ? corrected == null
              ? _estimate!.label
              : '${corrected.label} (corrected)'
        : 'Waiting for road estimate';
    final colour = _recording && fresh
        ? (corrected?.color ?? _estimate!.rating?.color ?? pendingRouteColor)
        : pendingRouteColor;
    final gpsStatus =
        _gpsMessage ??
        (_recording && elapsed - _lastFixMs > 5000 ? 'Waiting for GPS' : null);
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: LiveRouteMap(
                  controller: _map,
                  edges: _route.edges,
                  location: _route.points.isEmpty
                      ? null
                      : _route.points.last.position,
                  onReady: () {
                    _mapReady = true;
                    if (_follow && _route.points.isNotEmpty) {
                      _map.move(_route.points.last.position, 17);
                    }
                  },
                  onGesture: () {
                    if (_follow) setState(() => _follow = false);
                  },
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          _recording ? Icons.videocam : Icons.route,
                          color: colour,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                _recording
                                    ? 'Camera recording · ${_formatTime(_elapsed)}'
                                    : 'Record to colour the road as you travel.',
                                style: const TextStyle(fontSize: 12),
                              ),
                              if (gpsStatus != null && _recording)
                                Text(
                                  gpsStatus,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange.shade900,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _showInfo,
                          icon: const Icon(Icons.info_outline),
                          tooltip: 'About experimental estimates',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 30,
                child: FloatingActionButton.small(
                  heroTag: 'live-road-follow',
                  onPressed: () {
                    setState(() => _follow = true);
                    if (_mapReady && _route.points.isNotEmpty) {
                      _map.move(_route.points.last.position, 17);
                    }
                  },
                  tooltip: 'Follow my location',
                  child: Icon(
                    _follow ? Icons.my_location : Icons.location_searching,
                  ),
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.science_outlined, size: 16),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Experimental camera estimates',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      '${(_route.distanceMeters / 1000).toStringAsFixed(2)} km · ${_speed.toStringAsFixed(0)} km/h',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const RoadMapLegend(),
                if (_recording) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                          fresh && _estimate?.rating != null && !_stopping
                          ? _correctCurrentRating
                          : null,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Wrong rating? Correct this section'),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                if (!_recording)
                  DropdownButtonFormField<String>(
                    key: ValueKey(_view),
                    initialValue: _view,
                    decoration: const InputDecoration(
                      labelText: 'Camera position',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final view in _views.entries)
                        DropdownMenuItem(
                          value: view.key,
                          child: Text(view.value),
                        ),
                    ],
                    onChanged: _processing
                        ? null
                        : (view) async {
                            if (view == null) return;
                            setState(() => _view = view);
                            final preferences =
                                await SharedPreferences.getInstance();
                            await preferences.setString(
                              'live_map_camera_view',
                              view,
                            );
                          },
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _processing
                        ? null
                        : _recording
                        ? () => _stop()
                        : _start,
                    style: _recording
                        ? FilledButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                          )
                        : null,
                    icon: _processing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _recording ? Icons.stop : Icons.fiber_manual_record,
                          ),
                    label: Text(
                      _processing
                          ? (_recording
                                ? 'Saving recording…'
                                : 'Preparing camera and model…')
                          : _recording
                          ? 'Stop and save'
                          : 'Start live mapping',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(Duration duration) =>
      '${duration.inMinutes.toString().padLeft(2, "0")}:${duration.inSeconds.remainder(60).toString().padLeft(2, "0")}';
}
