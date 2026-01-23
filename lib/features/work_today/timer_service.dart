import 'dart:async';
import 'package:flutter/material.dart';

class TimerService extends ChangeNotifier {
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isRunning = false;
  DateTime? _startTime;

  int get elapsedSeconds => _elapsedSeconds;
  bool get isRunning => _isRunning;
  DateTime? get startTime => _startTime;

  String get formattedTime {
    final hours = _elapsedSeconds ~/ 3600;
    final minutes = (_elapsedSeconds % 3600) ~/ 60;
    final seconds = _elapsedSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void start() {
    if (_isRunning) return;
    
    _startTime = DateTime.now();
    _isRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedSeconds++;
      notifyListeners();
    });
    notifyListeners();
  }

  void pause() {
    _timer?.cancel();
    _isRunning = false;
    notifyListeners();
  }

  void resume() {
    if (_isRunning) return;
    _isRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedSeconds++;
      notifyListeners();
    });
    notifyListeners();
  }

  void stop() {
    _timer?.cancel();
    _isRunning = false;
    _elapsedSeconds = 0;
    _startTime = null;
    notifyListeners();
  }

  void reset() {
    stop();
    _elapsedSeconds = 0;
    notifyListeners();
  }

  void setDuration(int seconds) {
    _elapsedSeconds = seconds;
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
