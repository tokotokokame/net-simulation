// lib/simulation/simulation_engine.dart
import 'dart:async';
import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/demo_timer_service.dart';
import '../models/link.dart';
import '../models/packet.dart';
import '../models/topology.dart';
import 'bgp_engine.dart';
import 'delay_model.dart';
import 'dhcp_service.dart';
import 'firewall_engine.dart';
import 'mpls_engine.dart';
import 'ospf_engine.dart';
import 'packet_processor.dart';
import 'rip_engine.dart';
import 'traffic_generator.dart';
import 'vlan_engine.dart';

enum SimulationState { idle, running, paused, stopped }

class SimulationStats {
  final int totalPackets, deliveredPackets, droppedPackets;
  final double avgLatencyMs, bandwidthUtilization;
  const SimulationStats({
    this.totalPackets = 0, this.deliveredPackets = 0, this.droppedPackets = 0,
    this.avgLatencyMs = 0, this.bandwidthUtilization = 0,
  });
  SimulationStats copyWith({int? totalPackets, int? deliveredPackets, int? droppedPackets}) =>
      SimulationStats(
        totalPackets: totalPackets ?? this.totalPackets,
        deliveredPackets: deliveredPackets ?? this.deliveredPackets,
        droppedPackets: droppedPackets ?? this.droppedPackets,
        avgLatencyMs: avgLatencyMs, bandwidthUtilization: bandwidthUtilization,
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
  SimulationEngineState copyWith({SimulationState? simState, List<Packet>? activePackets, SimulationStats? stats}) =>
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
  Map<String, String> _dhcpAssignments = {};
  Map<String, int> _mplsLsps = {};

  SimulationEngine(Ref ref)
      : _demoTimer = ref.read(demoTimerServiceProvider),
        super(const SimulationEngineState()) {
    log('SimulationEngine initialized', name: 'Engine');
  }

  SimulationState get simState => state.simState;

  void start(Topology topology, [List<TrafficConfig>? configs]) {
    if (simState == SimulationState.running) return;
    _topology = topology;

    // 1. Topology validation.
    try {
      topology.validate();
    } catch (e) {
      log('start: validation failed: $e', name: 'Engine');
      return;
    }

    // 2. DHCP — assign IPs to unaddressed endpoints.
    try { _dhcpAssignments = DhcpService.assignIps(topology); }
    catch (e) { log('DHCP error: $e', name: 'Engine'); }

    // 3. OSPF route computation.
    try { OspfEngine.install(topology, _processor); }
    catch (e) { log('OSPF error: $e', name: 'Engine'); }

    // 4. RIP route computation.
    try { RipEngine.install(topology, _processor); }
    catch (e) { log('RIP error: $e', name: 'Engine'); }

    // 5. BGP route computation.
    try { BgpEngine.install(topology, _processor); }
    catch (e) { log('BGP error: $e', name: 'Engine'); }

    // 6. MPLS LSP pre-computation.
    try { _mplsLsps = MplsEngine.computeLsps(topology, _processor); }
    catch (e) { log('MPLS error: $e', name: 'Engine'); }

    // 7. Demo timer countdown.
    _demoTimer.start();
    _timerSub ??= _demoTimer.onExpired.listen((_) {
      log('SimulationEngine paused by demo timer', name: 'Engine');
      pause();
    });
    final effectiveConfigs = configs ?? [];
    for (final cfg in effectiveConfigs) {
      _trafficSubs.add(_trafficGen.generatePackets(cfg).listen(injectPacket));
    }

    // Auto-generate default ping when no configs provided.
    if (effectiveConfigs.isEmpty && topology.devices.length >= 2) {
      final src = topology.devices.first;
      final dst = topology.devices.last;
      final srcIp = src.interfaces.isNotEmpty ? src.interfaces.first.ip : '10.0.0.1';
      final dstIp = dst.interfaces.isNotEmpty ? dst.interfaces.first.ip : '10.0.0.2';
      if (srcIp != '0.0.0.0' && dstIp != '0.0.0.0') {
        _trafficSubs.add(_trafficGen.generatePackets(TrafficConfig(
          type: TrafficType.ping,
          sourceDeviceId: src.id,
          sourceIp: srcIp,
          destinationIp: dstIp,
          packetRate: 2,
          duration: const Duration(minutes: 10),
        )).listen(injectPacket));
        log('Auto ping: ${src.name}($srcIp) → ${dst.name}($dstIp)', name: 'Engine');
      }
    }

    // 8. Ticker — simulation loop.
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
    state = state.copyWith(simState: SimulationState.running);
    log('SimulationEngine started: ${topology.name} '
        'dhcp=${_dhcpAssignments.length} lsps=${_mplsLsps.length}', name: 'Engine');
  }

  void pause() {
    if (simState != SimulationState.running) return;
    _ticker?.cancel(); _ticker = null;
    _demoTimer.pause();
    state = state.copyWith(simState: SimulationState.paused);
    log('SimulationEngine paused', name: 'Engine');
  }

  void stop() {
    _ticker?.cancel(); _ticker = null;
    _timerSub?.cancel(); _timerSub = null;
    for (final s in _trafficSubs) { s.cancel(); }
    _trafficSubs.clear();
    _pending.clear();
    _dhcpAssignments = {};
    _mplsLsps = {};
    _demoTimer.pause();
    state = state.copyWith(simState: SimulationState.stopped, activePackets: const []);
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

    for (final pkt in batch) {
      try {
        // 1. Find source device by IP; fall back to first device.
        final device = _topology!.devices
            .where((d) => d.interfaces.any((i) => i.ip == pkt.sourceIp))
            .firstOrNull ?? _topology!.devices.firstOrNull;
        if (device == null) continue;

        // 2. VLAN processing.
        final vlanPkt = VlanEngine.process(pkt, device, _topology!);
        if (vlanPkt == null) {
          stats = stats.copyWith(totalPackets: stats.totalPackets + 1,
              droppedPackets: stats.droppedPackets + 1);
          active.add(pkt.copyWith(status: PacketStatus.dropped, droppedReason: 'VLAN blocked'));
          continue;
        }

        // 3. Firewall ACL evaluation.
        final fwDrop = FirewallEngine.evaluate(vlanPkt, device);
        if (fwDrop != null) {
          stats = stats.copyWith(totalPackets: stats.totalPackets + 1,
              droppedPackets: stats.droppedPackets + 1);
          active.add(vlanPkt.copyWith(status: PacketStatus.dropped, droppedReason: fwDrop.droppedReason));
          continue;
        }

        // 4–6. NAT + ARP + PacketProcessor routing (Dijkstra fallback included).
        final result = _processor.processPacket(vlanPkt, device, _topology!);

        // 7. Delay calculation (logs internally).
        if (result.success && result.nextDeviceId != null) {
          final link = _linkBetween(device.id, result.nextDeviceId!);
          if (link != null) DelayModel.calculate(vlanPkt, link, 0);
        }

        // 8–9. Particle animation update + stats.
        stats = stats.copyWith(
          totalPackets: stats.totalPackets + 1,
          deliveredPackets: stats.deliveredPackets + (result.success ? 1 : 0),
          droppedPackets: stats.droppedPackets + (result.success ? 0 : 1),
        );
        active.add(vlanPkt.copyWith(
          status: result.success ? PacketStatus.delivered : PacketStatus.dropped,
          droppedReason: result.droppedReason,
        ));
      } catch (e, st) {
        log('_tick error: $e\n$st', name: 'Engine');
        stats = stats.copyWith(totalPackets: stats.totalPackets + 1,
            droppedPackets: stats.droppedPackets + 1);
      }
    }

    if (active.length > 2000) active.removeRange(0, active.length - 2000);
    state = state.copyWith(activePackets: active, stats: stats);
  }

  Link? _linkBetween(String a, String b) =>
      _topology?.links.where((l) =>
          l.isActive &&
          ((l.deviceAId == a && l.deviceBId == b) ||
           (l.deviceAId == b && l.deviceBId == a))).firstOrNull;

  @override
  void dispose() { stop(); super.dispose(); }
}

final simulationEngineProvider =
    StateNotifierProvider<SimulationEngine, SimulationEngineState>(
        SimulationEngine.new);
