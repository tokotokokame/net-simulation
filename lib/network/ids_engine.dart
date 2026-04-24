// lib/network/ids_engine.dart
//
// ⚠️ EDUCATIONAL PURPOSE ONLY
// This penetration test simulation operates ONLY within the virtual
// network topology. It has NO effect on real networks or systems.
// Designed for network security education and firewall validation.

import 'dart:developer';
import '../models/attack_packet.dart';
import '../models/device.dart';
import '../models/packet.dart';

// ── Enums / data classes ──────────────────────────────────────────────────────

enum IdsAction { alert, block, rateLimit }

class DetectionRule {
  final String id;
  final String name;
  final String description;
  final AttackType attackType;

  /// Packets-per-second from a single source that triggers the rule.
  final int threshold;
  final IdsAction action;

  const DetectionRule({
    required this.id,
    required this.name,
    required this.description,
    required this.attackType,
    required this.threshold,
    required this.action,
  });
}

class DetectionAlert {
  final String ruleId;
  final AttackType attackType;
  final String sourceIp;
  final String targetIp;
  final int packetCount;
  final DateTime timestamp;
  final bool blocked;

  const DetectionAlert({
    required this.ruleId,
    required this.attackType,
    required this.sourceIp,
    required this.targetIp,
    required this.packetCount,
    required this.timestamp,
    required this.blocked,
  });

  @override
  String toString() =>
      'DetectionAlert(${attackType.name} src=$sourceIp '
      'count=$packetCount blocked=$blocked)';
}

// ── IdsEngine ─────────────────────────────────────────────────────────────────

class IdsEngine {
  const IdsEngine();

  // ── Default rule set ───────────────────────────────────────────────────────

  /// Returns the built-in detection rules.
  List<DetectionRule> getDefaultRules() => const [
        DetectionRule(
          id: 'ids-001',
          name: 'SYN Flood Detection',
          description: 'Detects SYN flood DoS attacks from a single source',
          attackType: AttackType.dosSynFlood,
          threshold: 50, // 50+ SYN packets/sec
          action: IdsAction.block,
        ),
        DetectionRule(
          id: 'ids-002',
          name: 'UDP Flood Detection',
          description: 'Detects UDP flood DoS attacks from a single source',
          attackType: AttackType.dosUdpFlood,
          threshold: 100,
          action: IdsAction.block,
        ),
        DetectionRule(
          id: 'ids-003',
          name: 'ICMP Flood Detection',
          description: 'Detects ICMP Smurf/ping flood attacks',
          attackType: AttackType.dosIcmpFlood,
          threshold: 50,
          action: IdsAction.block,
        ),
        DetectionRule(
          id: 'ids-004',
          name: 'Port Scan Detection',
          description: 'Detects port scanning (10+ distinct ports in 10 sec)',
          attackType: AttackType.portScanTcp,
          threshold: 10,
          action: IdsAction.alert,
        ),
        DetectionRule(
          id: 'ids-005',
          name: 'ARP Spoofing Detection',
          description: 'Detects ARP reply with conflicting MAC for known IP',
          attackType: AttackType.arpSpoofing,
          threshold: 1,
          action: IdsAction.block,
        ),
      ];

  // ── Analysis ───────────────────────────────────────────────────────────────

  /// Analyses [recentPackets] (assumed received within ~1-10 seconds) and
  /// returns any [DetectionAlert]s raised by [idsDevice].
  List<DetectionAlert> analyze(
      List<Packet> recentPackets, Device idsDevice) {
    assert(
      idsDevice.type == DeviceType.ids || idsDevice.type == DeviceType.ips,
      'analyze() requires an IDS or IPS device',
    );

    final rules = getDefaultRules();
    final alerts = <DetectionAlert>[];

    // ── SYN flood: count SYN-only packets per source ──────────────────────
    final synCounts = <String, int>{};
    for (final pkt in recentPackets) {
      if (pkt.protocol == ProtocolType.tcp &&
          pkt.tcpFlags?.syn == true &&
          pkt.tcpFlags?.ack == false) {
        synCounts[pkt.sourceIp] = (synCounts[pkt.sourceIp] ?? 0) + 1;
      }
    }
    for (final entry in synCounts.entries) {
      final rule = rules.firstWhere(
          (r) => r.attackType == AttackType.dosSynFlood);
      if (entry.value >= rule.threshold) {
        final alert = DetectionAlert(
          ruleId: rule.id,
          attackType: AttackType.dosSynFlood,
          sourceIp: entry.key,
          targetIp: recentPackets
                  .where((p) => p.sourceIp == entry.key)
                  .firstOrNull
                  ?.destinationIp ??
              '?',
          packetCount: entry.value,
          timestamp: DateTime.now(),
          blocked: rule.action == IdsAction.block,
        );
        alerts.add(alert);
        log('IDS[${idsDevice.name}]: $alert', name: 'IdsEngine');
      }
    }

    // ── Port scan: distinct destination ports per source ──────────────────
    final portsBySource = <String, Set<int>>{};
    for (final pkt in recentPackets) {
      portsBySource
          .putIfAbsent(pkt.sourceIp, () => {})
          .add(pkt.destinationPort);
    }
    for (final entry in portsBySource.entries) {
      final rule = rules.firstWhere(
          (r) => r.attackType == AttackType.portScanTcp);
      if (entry.value.length >= rule.threshold) {
        final alert = DetectionAlert(
          ruleId: rule.id,
          attackType: AttackType.portScanTcp,
          sourceIp: entry.key,
          targetIp: recentPackets
                  .where((p) => p.sourceIp == entry.key)
                  .firstOrNull
                  ?.destinationIp ??
              '?',
          packetCount: entry.value.length,
          timestamp: DateTime.now(),
          blocked: rule.action == IdsAction.block,
        );
        alerts.add(alert);
        log('IDS[${idsDevice.name}]: $alert', name: 'IdsEngine');
      }
    }

    // ── ARP spoofing: multiple MACs for same source IP in ARP packets ─────
    final arpMacByIp = <String, Set<String>>{};
    for (final pkt in recentPackets) {
      if (pkt.protocol != ProtocolType.arp) continue;
      // MAC is encoded in packet source — use a sentinel if no tcpFlags
      // (real ARP carries sender-MAC; here we derive from packet metadata)
      final mac = pkt.tcpFlags?.toString() ?? pkt.sourcePort.toString();
      arpMacByIp.putIfAbsent(pkt.sourceIp, () => {}).add(mac);
    }
    for (final entry in arpMacByIp.entries) {
      if (entry.value.length >= 2) {
        final rule = rules.firstWhere(
            (r) => r.attackType == AttackType.arpSpoofing);
        final alert = DetectionAlert(
          ruleId: rule.id,
          attackType: AttackType.arpSpoofing,
          sourceIp: entry.key,
          targetIp: '(broadcast)',
          packetCount: entry.value.length,
          timestamp: DateTime.now(),
          blocked: rule.action == IdsAction.block,
        );
        alerts.add(alert);
        log('IDS[${idsDevice.name}]: $alert', name: 'IdsEngine');
      }
    }

    return alerts;
  }
}
