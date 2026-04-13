// lib/auth/demo_timer_service.dart
import 'dart:async';
import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Maximum free simulation duration in seconds (60 minutes).
const int kDemoLimitSeconds = 3600;

/// Event emitted when the demo timer expires.
class SimulationPausedByTimer {
  const SimulationPausedByTimer();
}

class DemoTimerService {
  final StreamController<int> _remainingController =
      StreamController<int>.broadcast();
  final StreamController<SimulationPausedByTimer> _expiredController =
      StreamController<SimulationPausedByTimer>.broadcast();

  Timer? _ticker;
  late int _remaining;
  bool _running = false;

  /// [limitSeconds] defaults to [kDemoLimitSeconds]; override in tests.
  DemoTimerService({int limitSeconds = kDemoLimitSeconds})
      : _remaining = limitSeconds;

  /// Stream of remaining seconds (ticks every second).
  Stream<int> get remainingSeconds => _remainingController.stream;

  /// Fires once when the timer reaches zero.
  Stream<SimulationPausedByTimer> get onExpired => _expiredController.stream;

  int get remaining => _remaining;
  bool get isRunning => _running;

  void start() {
    if (_running || _remaining <= 0) return;
    _running = true;
    log('DemoTimer started, remaining: $_remaining s', name: 'DemoTimer');
    _ticker = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  void pause() {
    if (!_running) return;
    _running = false;
    _ticker?.cancel();
    _ticker = null;
    log('DemoTimer paused, remaining: $_remaining s', name: 'DemoTimer');
  }

  void reset() {
    pause();
    _remaining = kDemoLimitSeconds;
    _remainingController.add(_remaining);
    log('DemoTimer reset', name: 'DemoTimer');
  }

  /// Call when user becomes Pro — disables the timer.
  void disableForPro() {
    pause();
    _remaining = kDemoLimitSeconds;
    log('DemoTimer disabled (Pro user)', name: 'DemoTimer');
  }

  void _onTick(Timer _) {
    if (_remaining <= 0) return;
    _remaining--;
    _remainingController.add(_remaining);

    // Log every 60 seconds.
    if (_remaining % 60 == 0) {
      final minutes = _remaining ~/ 60;
      log('DemoTimer: ${minutes}m remaining', name: 'DemoTimer');
    }

    if (_remaining <= 0) {
      _running = false;
      _ticker?.cancel();
      _ticker = null;
      log('DemoTimer expired — simulation paused', name: 'DemoTimer');
      _expiredController.add(const SimulationPausedByTimer());
    }
  }

  void dispose() {
    _ticker?.cancel();
    _remainingController.close();
    _expiredController.close();
    log('DemoTimerService disposed', name: 'DemoTimer');
  }
}

// ── Riverpod providers ────────────────────────────────────────────────────────

final demoTimerServiceProvider = Provider<DemoTimerService>((ref) {
  final service = DemoTimerService();
  ref.onDispose(service.dispose);
  return service;
});

/// Remaining seconds as an async stream.
final demoRemainingProvider = StreamProvider<int>((ref) {
  final service = ref.watch(demoTimerServiceProvider);
  return service.remainingSeconds;
});
