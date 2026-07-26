import 'dart:core';

class SessionClock {
  Stopwatch? _stopwatch;

  void start() {
    _stopwatch = Stopwatch()..start();
  }

  void stop() {
    _stopwatch?.stop();
  }

  void reset() {
    _stopwatch = null;
  }

  int get elapsedMilliseconds {
    return _stopwatch?.elapsedMilliseconds ?? 0;
  }

  Duration get elapsed {
    return _stopwatch?.elapsed ?? Duration.zero;
  }

  bool get isRunning {
    return _stopwatch?.isRunning ?? false;
  }
}