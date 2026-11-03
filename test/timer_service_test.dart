import 'package:flutter_test/flutter_test.dart';
import 'package:offline_khata_app/features/work_today/timer_service.dart';

void main() {
  test('stop preserves elapsed duration for saving', () {
    final timer = TimerService();
    timer.setDuration(120);
    timer.stop();
    expect(timer.elapsedSeconds, 120);
    timer.reset();
    expect(timer.elapsedSeconds, 0);
    timer.dispose();
  });

  test('resume starts from persisted duration', () {
    final timer = TimerService();
    timer.setDuration(42);
    timer.resume();
    expect(timer.elapsedSeconds, greaterThanOrEqualTo(42));
    timer.pause();
    expect(timer.elapsedSeconds, greaterThanOrEqualTo(42));
    timer.dispose();
  });
}
