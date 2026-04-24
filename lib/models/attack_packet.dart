// lib/models/attack_packet.dart
//
// ⚠️ EDUCATIONAL PURPOSE ONLY
// This penetration test simulation operates ONLY within the virtual
// network topology. It has NO effect on real networks or systems.
// Designed for network security education and firewall validation.

import 'packet.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum AttackType {
  dosSynFlood,      // SYNフラッドによるDoS
  dosUdpFlood,      // UDPフラッドによるDoS
  dosIcmpFlood,     // PingフラッドによるDoS（Smurf攻撃）
  portScanTcp,      // TCPポートスキャン（SYN scan）
  portScanUdp,      // UDPポートスキャン
  portScanStealth,  // ステルススキャン（FINスキャン）
  arpSpoofing,      // ARPスプーフィング
  manInTheMiddle,   // MitM（ARPスプーフィング応用）
  dnsAmplification, // DNS増幅攻撃
}

enum AttackIntensity {
  low,    // 10 packets/sec
  medium, // 100 packets/sec
  high,   // 1000 packets/sec（キュー上限を意図的に超える）
  ;

  int get packetsPerSecond => switch (this) {
        AttackIntensity.low    => 10,
        AttackIntensity.medium => 100,
        AttackIntensity.high   => 1000,
      };
}

// ── AttackPacket ──────────────────────────────────────────────────────────────

/// A [Packet] subclass that carries penetration-test metadata.
class AttackPacket extends Packet {
  final AttackType attackType;

  /// Device ID of the attacker node in the virtual topology.
  final String attackerId;

  /// Device ID of the target node in the virtual topology.
  final String targetId;

  final AttackIntensity intensity;

  const AttackPacket({
    required super.id,
    required super.sourceIp,
    required super.destinationIp,
    required super.sourcePort,
    required super.destinationPort,
    required super.protocol,
    super.size,
    super.ttl,
    super.tcpFlags,
    super.status,
    super.vlanTag,
    super.mplsLabel,
    super.droppedReason,
    required this.attackType,
    required this.attackerId,
    required this.targetId,
    required this.intensity,
  });

  @override
  String toString() =>
      'AttackPacket(${attackType.name} $sourceIp→$destinationIp '
      'intensity=${intensity.name})';
}

// ── AttackResult ──────────────────────────────────────────────────────────────

class AttackResult {
  final AttackType attackType;
  final String targetId;
  final int packetsGenerated;

  /// Number of packets blocked by firewall/IDS.
  final int packetsBlocked;

  /// True when the target's queue was saturated.
  final bool targetOverloaded;

  /// Open ports found during a port scan.
  final List<int> openPorts;

  /// Device IDs of IDS/IPS nodes that raised alerts.
  final List<String> detectedBy;

  final DateTime timestamp;

  const AttackResult({
    required this.attackType,
    required this.targetId,
    required this.packetsGenerated,
    required this.packetsBlocked,
    required this.targetOverloaded,
    required this.openPorts,
    required this.detectedBy,
    required this.timestamp,
  });

  int get packetsThrough => packetsGenerated - packetsBlocked;

  @override
  String toString() =>
      'AttackResult(${attackType.name} gen=$packetsGenerated '
      'blocked=$packetsBlocked overloaded=$targetOverloaded '
      'openPorts=$openPorts detectedBy=$detectedBy)';
}
