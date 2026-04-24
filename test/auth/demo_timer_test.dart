// test/auth/demo_timer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:net_simulation/auth/demo_timer_service.dart';

void main() {
  group('DemoTimerService', () {
    late DemoTimerService timer;

    setUp(() {
      timer = DemoTimerService();
    });

    tearDown(() {
      timer.dispose();
    });

    test('initial remaining equals kDemoLimitSeconds', () {
      expect(timer.remaining, kDemoLimitSeconds);
    });

    test('start sets isRunning to true', () {
      timer.start();
      expect(timer.isRunning, isTrue);
      timer.pause();
    });

    test('pause stops the timer', () {
      timer.start();
      timer.pause();
      expect(timer.isRunning, isFalse);
    });

    test('reset restores full duration', () async {
      timer.start();
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      timer.reset();
      expect(timer.remaining, kDemoLimitSeconds);
    });

    test('remainingSeconds stream emits on each tick', () async {
      final values = <int>[];
      final sub = timer.remainingSeconds.listen(values.add);
      timer.start();
      await Future<void>.delayed(const Duration(milliseconds: 2500));
      timer.pause();
      await sub.cancel();
      expect(values.length, greaterThanOrEqualTo(2));
    });

    test('onExpired fires when remaining reaches 0', () async {
      final shortTimer = DemoTimerService(limitSeconds: 2);
      final expired = <SimulationPausedByTimer>[];
      final sub = shortTimer.onExpired.listen(expired.add);

      shortTimer.start();
      await Future<void>.delayed(const Duration(seconds: 3));
      await sub.cancel();
      shortTimer.dispose();

      expect(expired, hasLength(1));
      expect(shortTimer.isRunning, isFalse);
    });

    test('disableForPro pauses and resets to default limit', () {
      timer.start();
      timer.disableForPro();
      expect(timer.isRunning, isFalse);
      expect(timer.remaining, kDemoLimitSeconds);
    });

    test('start is no-op when already running', () {
      timer.start();
      timer.start();
      expect(timer.isRunning, isTrue);
      timer.pause();
    });

    test('start is no-op when remaining is 0', () {
      final zeroTimer = DemoTimerService(limitSeconds: 0);
      zeroTimer.start();
      expect(zeroTimer.isRunning, isFalse);
      zeroTimer.dispose();
    });
  });
}
