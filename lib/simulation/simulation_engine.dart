// lib/simulation/simulation_engine.dart
import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;
import 'package:flutter/material.dart' show Offset;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/demo_timer_service.dart';
import '../models/attack_packet.dart';
import '../models/device.dart';
import '../models/link.dart';
import '../models/network_interface.dart';
import '../models/packet.dart';
import '../models/topology.dart';
import '../network/arp_table.dart';
import '../network/dns_service.dart';
import '../visualization/packet_particle.dart';
import 'bgp_engine.dart';
import 'delay_model.dart';
import 'dhcp_service.dart';
import 'firewall_engine.dart';
import 'mpls_engine.dart';
import 'ospf_engine.dart';
import 'packet_processor.dart';
import 'rip_engine.dart';
import 'routing_engine.dart';
import 'traffic_generator.dart';
import 'vlan_engine.dart';

enum SimulationState { idle, running, paused, stopped }

/// Result returned by [SimulationEngine.validateAndPrepare].
class SimulationStartResult {
  final List<String> errors;
  final List<String> warnings;
  /// Topology with auto-assigned IPs (same as input when errors are present).
  final Topology prepared;
  const SimulationStartResult({
    required this.errors,
    required this.warnings,
    required this.prepared,
  });
  bool get hasErrors => errors.isNotEmpty;
}

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
  final List<AttackResult> attackResults;
  final List<PacketParticle> particles;
  const SimulationEngineState({
    this.simState = SimulationState.idle,
    this.activePackets = const [],
    this.stats = const SimulationStats(),
    this.attackResults = const [],
    this.particles = const [],
  });
  SimulationEngineState copyWith({
    SimulationState? simState,
    List<Packet>? activePackets,
    SimulationStats? stats,
    List<AttackResult>? attackResults,
    List<PacketParticle>? particles,
  }) => SimulationEngineState(
    simState: simState ?? this.simState,
    activePackets: activePackets ?? this.activePackets,
    stats: stats ?? this.stats,
    attackResults: attackResults ?? this.attackResults,
    particles: particles ?? this.particles,
  );
}

class SimulationEngine extends StateNotifier<SimulationEngineState> {
  final DemoTimerService _demoTimer;
  final PacketProcessor _processor = PacketProcessor();
  final TrafficGenerator _trafficGen = TrafficGenerator();
  final RoutingEngine _routingEngine = RoutingEngine();

  Topology? _topology;
  Timer? _ticker;
  StreamSubscription<SimulationPausedByTimer>? _timerSub;
  final _pending = <Packet>[];
  final _trafficSubs = <StreamSubscription<Packet>>[];
  final _particles = <PacketParticle>[];
  Map<String, String> _dhcpAssignments = {};
  Map<String, int> _mplsLsps = {};

  SimulationEngine(Ref ref)
      : _demoTimer = ref.read(demoTimerServiceProvider),
        super(const SimulationEngineState()) {
    log('SimulationEngine initialized', name: 'Engine');
  }

  SimulationState get simState => state.simState;

  /// Records an [AttackResult] from the pentest screen (capped at 500).
  void recordAttackResult(AttackResult result) {
    final updated = [...state.attackResults, result];
    if (updated.length > 500) updated.removeRange(0, updated.length - 500);
    state = state.copyWith(attackResults: updated);
  }

  /// Validates [topology] and auto-assigns IPs where missing.
  /// Always safe to call; does NOT start the simulation.
  SimulationStartResult validateAndPrepare(Topology topology) {
    final errors   = <String>[];
    final warnings = <String>[];

    // 1. Must have at least one link.
    if (topology.links.isEmpty) {
      errors.add('リンクが存在しません。デバイスを接続してからシミュレーションを開始してください。');
    }

    // 2. Auto-assign 0.0.0.0 IPs.
    int ipSuffix = 10;
    final preparedDevices = <Device>[];
    for (final device in topology.devices) {
      if (device.interfaces.isEmpty) {
        final ip = '192.168.1.$ipSuffix'; ipSuffix++;
        warnings.add('${device.name}: eth0 を自動追加 → $ip');
        preparedDevices.add(device.copyWith(interfaces: [
          NetworkInterface(name: 'eth0', ip: ip, subnet: 24, mac: _genMac()),
        ]));
      } else {
        final ifaces = <NetworkInterface>[];
        for (final iface in device.interfaces) {
          if (iface.ip == '0.0.0.0' || iface.ip.isEmpty) {
            final ip = '192.168.1.$ipSuffix'; ipSuffix++;
            warnings.add('${device.name}/${iface.name}: IP自動補完 → $ip');
            final mac = iface.mac.isEmpty || iface.mac == '00:00:00:00:00:00'
                ? _genMac() : iface.mac;
            ifaces.add(iface.copyWith(ip: ip, mac: mac));
          } else {
            final mac = iface.mac.isEmpty || iface.mac == '00:00:00:00:00:00'
                ? _genMac() : iface.mac;
            ifaces.add(iface.copyWith(mac: mac));
          }
        }
        preparedDevices.add(device.copyWith(interfaces: ifaces));
      }
    }

    // 3. Duplicate IP check.
    final seen = <String, String>{};
    for (final d in preparedDevices) {
      for (final i in d.interfaces) {
        if (i.ip == '0.0.0.0') continue;
        if (seen.containsKey(i.ip)) {
          errors.add('IPアドレス重複: ${i.ip}  (${seen[i.ip]} と ${d.name})');
        } else {
          seen[i.ip] = d.name;
        }
      }
    }

    final prepared = errors.isEmpty
        ? topology.copyWith(devices: preparedDevices)
        : topology;
    return SimulationStartResult(errors: errors, warnings: warnings, prepared: prepared);
  }

  static String _genMac() {
    final r = math.Random();
    return List.generate(6, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0').toUpperCase()).join(':');
  }

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

    // 7. ARP table population — pre-seed all device IP→MAC mappings.
    try {
      for (final device in topology.devices) {
        final ctx = _processor.contextFor(device.id);
        for (final other in topology.devices) {
          for (final iface in other.interfaces) {
            if (iface.ip == '0.0.0.0' || iface.ip.isEmpty) continue;
            ctx.arpTable.addEntry(ARPEntry(
              ipAddress: iface.ip,
              macAddress: iface.mac.isEmpty ? '00:00:00:00:00:00' : iface.mac,
              interfaceName: iface.name,
              expiry: DateTime.now().add(const Duration(hours: 4)),
            ));
          }
        }
      }
      log('ARP: tables seeded for ${topology.devices.length} devices', name: 'Engine');
    } catch (e) { log('ARP seed error: $e', name: 'Engine'); }

    // 8. DNS — register device hostnames.
    try {
      final dns = DnsService.fromTopology(topology);
      log('DNS: ${dns.records.length} records built', name: 'Engine');
    } catch (e) { log('DNS error: $e', name: 'Engine'); }

    // 8b. Pre-compute path particles for every link (both directions).
    _spawnParticlesForTopology(topology);

    // 9. Demo timer countdown.
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

    // 10. Ticker — simulation loop.
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
    _particles.clear();
    _dhcpAssignments = {};
    _mplsLsps = {};
    _demoTimer.pause();
    state = state.copyWith(
      simState: SimulationState.stopped,
      activePackets: const [],
      particles: const [],
    );
    log('SimulationEngine stopped', name: 'Engine');
  }

  void injectPacket(Packet p) => _pending.add(p);

  void _tick() {
    if (simState != SimulationState.running || _topology == null) return;

    // Advance particle positions (dt = 100ms = 0.1s).
    _updateParticles(0.1);

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
    state = state.copyWith(
      activePackets: active,
      stats: stats,
      particles: List.of(_particles),
    );
  }

  // ── Particle management ───────────────────────────────────────────────────

  // ── Packet-trace spawn ────────────────────────────────────────────────────

  void _spawnParticlesForTopology(Topology topology) {
    _particles.clear();
    if (topology.devices.length < 2) return;

    const endpointTypes = {
      DeviceType.pc, DeviceType.laptop, DeviceType.server, DeviceType.iotDevice,
    };
    final endpoints = topology.devices
        .where((d) => endpointTypes.contains(d.type))
        .toList();

    // Build up to 3 meaningful src→dst pairs (prefer endpoints).
    final pairs = <(Device, Device)>[];
    final candidates = endpoints.length >= 2 ? endpoints : topology.devices;
    for (int i = 0; i < candidates.length && pairs.length < 3; i++) {
      for (int j = i + 1; j < candidates.length && pairs.length < 3; j++) {
        pairs.add((candidates[i], candidates[j]));
      }
    }
    if (pairs.isEmpty) {
      pairs.add((topology.devices.first, topology.devices.last));
    }

    int idx = 0;
    for (final (src, dst) in pairs) {
      final pathIds = _routingEngine.shortestPath(src.id, dst.id, topology);
      if (pathIds.length < 2) continue;

      // F3: skip paths that cross any blocked (inactive) link.
      bool hasBlocked = false;
      for (int i = 0; i < pathIds.length - 1 && !hasBlocked; i++) {
        hasBlocked = !topology.links.any((l) =>
            l.isActive &&
            ((l.deviceAId == pathIds[i]     && l.deviceBId == pathIds[i + 1]) ||
             (l.deviceAId == pathIds[i + 1] && l.deviceBId == pathIds[i])));
      }
      if (hasBlocked) continue;

      _spawnParticle('p${idx++}', pathIds, topology);
      log('[Engine] Trace: ${src.name}→${dst.name} (${pathIds.length} hops)', name: 'Engine');
    }

    // Fallback: one particle per active link (keeps animation alive for
    // topologies with only infrastructure nodes and no endpoint pairs).
    if (_particles.isEmpty) {
      for (final link in topology.links) {
        if (!link.isActive) continue;
        final a = topology.devices.where((d) => d.id == link.deviceAId).firstOrNull;
        final b = topology.devices.where((d) => d.id == link.deviceBId).firstOrNull;
        if (a == null || b == null) continue;
        _spawnParticle('p${idx++}', [a.id, b.id], topology);
        if (_particles.length >= 4) break;
      }
    }

    log('[Engine] ${_particles.length} trace particles spawned', name: 'Engine');
  }

  void _spawnParticle(String id, List<String> deviceIds, Topology topology) {
    final positions = deviceIds
        .map((did) => topology.devices.where((d) => d.id == did).firstOrNull)
        .whereType<Device>()
        .map((d) => Offset(d.x, d.y))
        .toList();
    if (positions.length < 2) return;
    _particles.add(PacketParticle(
      id: id,
      path: positions,
      position: positions.first,
      deviceIds: deviceIds,
    ));
  }

  void _updateParticles(double dt) {
    for (final p in _particles) {
      if (p.status == PacketStatus.delivered) {
        p.doneFrames++;
        p.progress = (p.doneFrames / 20.0).clamp(0.0, 1.0);
        if (p.doneFrames > 20) p.reset();
        continue;
      }
      if (p.status == PacketStatus.dropped) {
        p.doneFrames++;
        if (p.doneFrames > 20) p.reset();
        continue;
      }

      // Pause at intermediate node (orange glow).
      if (p.isAtNode) {
        p.nodeFrames++;
        if (p.nodeFrames >= PacketParticle.kNodePauseDuration) {
          p.isAtNode   = false;
          p.nodeFrames = 0;
        }
        continue;
      }

      p.progress += dt * 0.55;

      if (p.progress >= 1.0) {
        p.progress = 0.0;
        p.pathIndex++;

        if (p.pathIndex >= p.path.length - 1) {
          // Reached destination → green pulse.
          p.status     = PacketStatus.delivered;
          p.position   = p.path.last;
          p.doneFrames = 0;
          continue;
        }

        // F3: check if the next link is still active before pausing at node.
        if (p.deviceIds.length > p.pathIndex + 1 && _topology != null) {
          final nextActive = _topology!.links.any((l) =>
              l.isActive &&
              ((l.deviceAId == p.deviceIds[p.pathIndex]     && l.deviceBId == p.deviceIds[p.pathIndex + 1]) ||
               (l.deviceAId == p.deviceIds[p.pathIndex + 1] && l.deviceBId == p.deviceIds[p.pathIndex])));
          if (!nextActive) {
            // Next link is blocked → drop here with red flash.
            p.status     = PacketStatus.dropped;
            p.position   = p.path[p.pathIndex];
            p.doneFrames = 0;
            continue;
          }
        }

        // Pause at this intermediate node (orange glow).
        p.position   = p.path[p.pathIndex];
        p.isAtNode   = true;
        p.nodeFrames = 0;
      } else {
        if (p.pathIndex < p.path.length - 1) {
          p.position = Offset.lerp(
            p.path[p.pathIndex],
            p.path[p.pathIndex + 1],
            p.progress.clamp(0.0, 1.0),
          )!;
        }
      }
    }
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
