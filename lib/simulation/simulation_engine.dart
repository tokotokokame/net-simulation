// lib/simulation/simulation_engine.dart
import 'dart:async';
import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/demo_timer_service.dart';
import '../models/packet.dart';
import '../models/topology.dart';
import 'packet_processor.dart';
import 'traffic_generator.dart';

enum SimulationState { idle, running, paused, stopped }

class SimulationStats {
  final int totalPackets;
  final int deliveredPackets;
  final int droppedPackets;
  final double avgLatencyMs;
  final double bandwidthUtilization;

  const SimulationStats({
    this.totalPackets = 0,
    this.deliveredPackets = 0,
    this.droppedPackets = 0,
    this.avgLatencyMs = 0,
    this.bandwidthUtilization = 0,
  });

  SimulationStats copyWith({
    int? totalPackets,
    int? deliveredPackets,
    int? droppedPackets,
  }) =>
      SimulationStats(
        totalPackets: totalPackets ?? this.totalPackets,
        deliveredPackets: deliveredPackets ?? this.deliveredPackets,
        droppedPackets: droppedPackets ?? this.droppedPackets,
        avgLatencyMs: avgLatencyMs,
        bandwidthUtilization: bandwidthUtilization,
      );
}

class SimulationEngineState {
  final SimulationState simState;
  final List<Packet> activePackets;
  final SimulationStats stats;

  const SimulationEngineState({
    this.simState = SimulationState.idle,
    this.activePackets = const [],
    this.stats = const SimulationStats(),
  });

  SimulationEngineState copyWith({
    SimulationState? simState,
    List<Packet>? activePackets,
    SimulationStats? stats,
  }) =>
      SimulationEngineState(
        simState: simState ?? this.simState,
        activePackets: activePackets ?? this.activePackets,
        stats: stats ?? this.stats,
      );
}

class SimulationEngine extends StateNotifier<SimulationEngineState> {
  final DemoTimerService _demoTimer;
  final PacketProcessor _processor = PacketProcessor();
  final TrafficGenerator _trafficGen = TrafficGenerator();

  Topology? _topology;
  Timer? _ticker;
  StreamSubscription<SimulationPausedByTimer>? _timerSub;
  final _pending = <Packet>[];
  final _trafficSubs = <StreamSubscription<Packet>>[];

  SimulationEngine(Ref ref)
      : _demoTimer = ref.read(demoTimerServiceProvider),
        super(const SimulationEngineState()) {
    log('SimulationEngine initialized', name: 'Engine');
  }

  SimulationState get simState => state.simState;

  void start(Topology topology, [List<TrafficConfig>? configs]) {
    if (simState == SimulationState.running) return;
    _topology = topology;
    _demoTimer.start();
    _timerSub ??= _demoTimer.onExpired.listen((_) {
      log('SimulationEngine paused by demo timer', name: 'Engine');
      pause();
    });
    for (final cfg in configs ?? []) {
      _trafficSubs.add(_trafficGen.generatePackets(cfg).listen(injectPacket));
    }
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
    state = state.copyWith(simState: SimulationState.running);
    log('SimulationEngine started: ${topology.name}', name: 'Engine');
  }

  void pause() {
    if (simState != SimulationState.running) return;
    _ticker?.cancel();
    _ticker = null;
    _demoTimer.pause();
    state = state.copyWith(simState: SimulationState.paused);
    log('SimulationEngine paused', name: 'Engine');
  }

  void stop() {
    _ticker?.cancel();
    _ticker = null;
    _timerSub?.cancel();
    _timerSub = null;
    for (final s in _trafficSubs) {
      s.cancel();
    }
    _trafficSubs.clear();
    _pending.clear();
    _demoTimer.pause();
    state = state.copyWith(
      simState: SimulationState.stopped,
      activePackets: const [],
    );
    log('SimulationEngine stopped', name: 'Engine');
  }

  void injectPacket(Packet p) => _pending.add(p);

  void _tick() {
    if (simState != SimulationState.running || _topology == null) return;
    final batch = _pending.take(10).toList();
    if (batch.isEmpty) return;
    _pending.removeRange(0, batch.length.clamp(0, _pending.length));

    var stats = state.stats;
    final active = List<Packet>.from(state.activePackets);
    final device = _topology!.devices.firstOrNull;
    if (device == null) return;

    for (final pkt in batch) {
      final result = _processor.processPacket(pkt, device, _topology!);
      stats = stats.copyWith(
        totalPackets: stats.totalPackets + 1,
        deliveredPackets: stats.deliveredPackets + (result.success ? 1 : 0),
        droppedPackets: stats.droppedPackets + (result.success ? 0 : 1),
      );
      active.add(pkt.copyWith(
        status: result.success ? PacketStatus.delivered : PacketStatus.dropped,
        droppedReason: result.droppedReason,
      ));
    }

    if (active.length > 2000) active.removeRange(0, active.length - 2000);
    state = state.copyWith(activePackets: active, stats: stats);
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

final simulationEngineProvider =
    StateNotifierProvider<SimulationEngine, SimulationEngineState>(
  SimulationEngine.new,
);
