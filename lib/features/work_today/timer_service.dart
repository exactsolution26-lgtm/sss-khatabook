import 'dart:async';
import 'package:flutter/material.dart';

class TimerService extends ChangeNotifier {
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isRunning = false;
  DateTime? _startTime;
  DateTime? _resumedAt;
  int _baseSeconds = 0;

  int get elapsedSeconds {
    if (!_isRunning || _resumedAt == null) return _elapsedSeconds;
    return _baseSeconds + DateTime.now().difference(_resumedAt!).inSeconds;
  }
  bool get isRunning => _isRunning;
  DateTime? get startTime => _startTime;
  String get formattedTime {
    final value = elapsedSeconds;
    final h = value ~/ 3600;
    final m = (value % 3600) ~/ 60;
    final s = value % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void start() {
    if (_isRunning) return;
    _startTime ??= DateTime.now();
    resume();
  }
  void resume() {
    if (_isRunning) return;
    _baseSeconds = _elapsedSeconds;
    _resumedAt = DateTime.now();
    _isRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
    notifyListeners();
  }
  void pause() {
    if (!_isRunning) return;
    _elapsedSeconds = elapsedSeconds;
    _timer?.cancel();
    _resumedAt = null;
    _isRunning = false;
    notifyListeners();
  }
  void stop() => pause(); // Keep duration until persisted/reset explicitly.
  void reset() {
    pause();
    _elapsedSeconds = 0;
    _baseSeconds = 0;
    _startTime = null;
    notifyListeners();
  }
  void setDuration(int seconds) {
    pause();
    _elapsedSeconds = seconds < 0 ? 0 : seconds;
    notifyListeners();
  }
  void setStartTime(DateTime time) {
    _startTime = time;
    notifyListeners();
  }
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
