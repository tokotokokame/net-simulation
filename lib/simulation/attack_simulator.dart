// lib/simulation/attack_simulator.dart
//
// ⚠️ EDUCATIONAL PURPOSE ONLY
// This penetration test simulation operates ONLY within the virtual
// network topology. It has NO effect on real networks or systems.
// Designed for network security education and firewall validation.

import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;
import 'package:uuid/uuid.dart';
import '../models/attack_packet.dart';
import '../models/device.dart';
import '../models/packet.dart';
import '../models/topology.dart';

const _uuid = Uuid();
const _kQueueMax = 100; // FIFOQueue default maxSize

class AttackSimulator {
  // ── Helpers ────────────────────────────────────────────────────────────────

  static Device? _device(String id, Topology t) =>
      t.devices.where((d) => d.id == id).firstOrNull;

  static String _ip(Device? d) =>
      d?.interfaces.firstOrNull?.ip ?? '10.0.0.1';

  static List<Device> _idsOnPath(
      String attackerId, String targetId, Topology t) {
    return t.devices
        .where((d) => d.type == DeviceType.ids || d.type == DeviceType.ips)
        .toList();
  }

  /// Returns true when the topology has a firewall device on the path.
  /// In this simulation, having any firewall device present causes it to
  /// block a fraction of high-intensity flood packets (simplified model).
  static bool _firewallPresent(Topology t) =>
      t.devices.any((d) => d.type == DeviceType.firewall);

  // ── DoS simulation ─────────────────────────────────────────────────────────

  /// Simulates a DoS flood attack. Yields an [AttackResult] every second
  /// for the requested [duration].
  Stream<AttackResult> simulateDoS({
    required String attackerDeviceId,
    required String targetDeviceId,
    required AttackType type,
    required AttackIntensity intensity,
    required Topology topology,
    required Duration duration,
  }) async* {
    assert(
      type == AttackType.dosSynFlood ||
          type == AttackType.dosUdpFlood ||
          type == AttackType.dosIcmpFlood,
      'simulateDoS requires a DoS AttackType',
    );

    log('Attack: DoS ${type.name} started '
        'attacker=$attackerDeviceId target=$targetDeviceId '
        'intensity=${intensity.name}',
        name: 'AttackSimulator');

    final attacker = _device(attackerDeviceId, topology);
    final target   = _device(targetDeviceId,   topology);
    final srcIp    = _ip(attacker);
    final dstIp    = _ip(target);
    final ids      = _idsOnPath(attackerDeviceId, targetDeviceId, topology);

    final perSecond = intensity.packetsPerSecond;
    final seconds   = duration.inSeconds.clamp(1, 300);

    for (var s = 0; s < seconds; s++) {
      int generated = 0, blocked = 0;
      final rng = math.Random();

      for (var i = 0; i < perSecond; i++) {
        final pkt = AttackPacket(
          id:          _uuid.v4(),
          sourceIp:    srcIp,
          destinationIp: dstIp,
          sourcePort:  1024 + rng.nextInt(60000),
          destinationPort: type == AttackType.dosSynFlood ? 80 : rng.nextInt(65535),
          protocol:    type == AttackType.dosIcmpFlood ? ProtocolType.icmp : ProtocolType.tcp,
          tcpFlags: type == AttackType.dosSynFlood
              ? const TcpFlags(syn: true)
              : null,
          size:     type == AttackType.dosUdpFlood ? 1400 : 64,
          attackType: type,
          attackerId: attackerDeviceId,
          targetId:   targetDeviceId,
          intensity:  intensity,
        );
        generated++;
        // Simplified model: firewall blocks ~30% of high-intensity packets.
        if (_firewallPresent(topology) && pkt.id.hashCode % 10 < 3) blocked++;
      }

      final overloaded = generated - blocked > _kQueueMax;
      final detectedIds = <String>[];
      for (final d in ids) {
        if (perSecond >= 50) {
          detectedIds.add(d.id);
          log('Attack: IDS alert on ${d.name} — ${type.name} detected '
              'src=$srcIp', name: 'AttackSimulator');
        }
      }

      yield AttackResult(
        attackType:       type,
        targetId:         targetDeviceId,
        packetsGenerated: generated,
        packetsBlocked:   blocked,
        targetOverloaded: overloaded,
        openPorts:        const [],
        detectedBy:       detectedIds,
        timestamp:        DateTime.now(),
      );

      await Future<void>.delayed(const Duration(seconds: 1));
    }

    log('Attack: DoS ${type.name} finished attacker=$attackerDeviceId',
        name: 'AttackSimulator');
  }

  // ── Port scan simulation ───────────────────────────────────────────────────

  /// Simulates a TCP/UDP/stealth port scan.
  Future<AttackResult> simulatePortScan({
    required String scannerDeviceId,
    required String targetDeviceId,
    required AttackType scanType,
    List<int> targetPorts = const [21, 22, 23, 25, 53, 80, 443, 3389, 8080],
    required Topology topology,
  }) async {
    log('Attack: PortScan ${scanType.name} started '
        'scanner=$scannerDeviceId target=$targetDeviceId '
        'ports=$targetPorts',
        name: 'AttackSimulator');

    final scanner = _device(scannerDeviceId, topology);
    final target  = _device(targetDeviceId,  topology);
    final srcIp   = _ip(scanner);
    final dstIp   = _ip(target);
    final ids     = _idsOnPath(scannerDeviceId, targetDeviceId, topology);
    final openPorts = <int>[];
    int generated = 0, blocked = 0;

    // Simulated open ports: server devices respond on common ports.
    final isServer = target?.type == DeviceType.server;
    final simulatedOpen = isServer ? {80, 443, 22} : <int>{};

    for (final port in targetPorts) {
      final flags = switch (scanType) {
        AttackType.portScanTcp    => const TcpFlags(syn: true),
        AttackType.portScanStealth => const TcpFlags(fin: true),
        _                         => null,
      };

      // Log the scan probe (flags used for protocol fidelity logging).
      log('Attack: probe port=$port flags=${flags?.syn == true ? "SYN" : flags?.fin == true ? "FIN" : "none"} '
          'src=$srcIp dst=$dstIp', name: 'AttackSimulator');
      generated++;

      // Firewall blocks non-stealth scans when present.
      if (_firewallPresent(topology) && scanType != AttackType.portScanStealth) {
        blocked++;
        continue;
      }
      // Stealth (FIN) scan bypasses stateless FW but not stateful.
      if (simulatedOpen.contains(port)) openPorts.add(port);
    }

    final detectedIds = <String>[];
    if (targetPorts.length >= 10) {
      for (final d in ids) {
        detectedIds.add(d.id);
        log('Attack: IDS alert on ${d.name} — port scan detected src=$srcIp',
            name: 'AttackSimulator');
      }
    }

    final result = AttackResult(
      attackType:       scanType,
      targetId:         targetDeviceId,
      packetsGenerated: generated,
      packetsBlocked:   blocked,
      targetOverloaded: false,
      openPorts:        openPorts,
      detectedBy:       detectedIds,
      timestamp:        DateTime.now(),
    );

    log('Attack: PortScan done openPorts=$openPorts', name: 'AttackSimulator');
    return result;
  }

  // ── ARP spoofing simulation ────────────────────────────────────────────────

  /// Simulates ARP spoofing: attacker poisons the victim's ARP cache.
  Stream<AttackResult> simulateArpSpoofing({
    required String attackerDeviceId,
    required String victimDeviceId,
    required String gatewayDeviceId,
    required Topology topology,
  }) async* {
    log('Attack: ARPSpoofing started '
        'attacker=$attackerDeviceId victim=$victimDeviceId '
        'gateway=$gatewayDeviceId',
        name: 'AttackSimulator');

    final attacker = _device(attackerDeviceId, topology);
    final gateway  = _device(gatewayDeviceId,  topology);
    final ids      = _idsOnPath(attackerDeviceId, victimDeviceId, topology);

    final gwIp    = _ip(gateway);
    final fakeMAC = attacker?.interfaces.firstOrNull?.mac ?? 'de:ad:be:ef:00:01';

    for (var round = 0; round < 5; round++) {
      // Fake gratuitous ARP reply: "gateway IP is at attacker MAC"
      final pkt = AttackPacket(
        id: _uuid.v4(),
        sourceIp: gwIp,
        destinationIp: '255.255.255.255',
        sourcePort: 0,
        destinationPort: 0,
        protocol: ProtocolType.arp,
        size: 28,
        attackType: AttackType.arpSpoofing,
        attackerId: attackerDeviceId,
        targetId: victimDeviceId,
        intensity: AttackIntensity.low,
      );

      final detectedIds = <String>[];
      for (final d in ids) {
        detectedIds.add(d.id);
        log('Attack: IDS alert on ${d.name} — ARP spoofing detected '
            'fakeMAC=$fakeMAC gwIp=$gwIp', name: 'AttackSimulator');
      }

      yield AttackResult(
        attackType:       AttackType.arpSpoofing,
        targetId:         victimDeviceId,
        packetsGenerated: 1,
        packetsBlocked:   detectedIds.isNotEmpty ? 1 : 0,
        targetOverloaded: false,
        openPorts:        const [],
        detectedBy:       detectedIds,
        timestamp:        DateTime.now(),
      );

      // Suppress unused variable warning
      assert(pkt.attackType == AttackType.arpSpoofing);
      await Future<void>.delayed(const Duration(seconds: 1));
    }

    log('Attack: ARPSpoofing finished', name: 'AttackSimulator');
  }
}
