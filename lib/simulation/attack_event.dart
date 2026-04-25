// lib/simulation/attack_event.dart
//
// ⚠️ EDUCATIONAL PURPOSE ONLY — virtual topology only.

import '../models/attack_packet.dart';

/// High-level outcome of one attack cycle.
enum AttackOutcome { sent, detected, blocked, rateLimited }

/// Derives [AttackOutcome] from an [AttackResult].
AttackOutcome outcomeOf(AttackResult r) {
  if (r.detectedBy.isNotEmpty && r.packetsBlocked > 0) return AttackOutcome.blocked;
  if (r.detectedBy.isNotEmpty)  return AttackOutcome.detected;
  if (r.packetsBlocked > 0)     return AttackOutcome.rateLimited;
  return AttackOutcome.sent;
}

/// Human-readable label for an [AttackType].
extension AttackTypeLabel on AttackType {
  String get label => switch (this) {
    AttackType.dosSynFlood        => 'SYNフラッド',
    AttackType.dosUdpFlood        => 'UDPフラッド',
    AttackType.dosIcmpFlood       => 'ICMPフラッド',
    AttackType.portScanTcp        => 'TCPポートスキャン',
    AttackType.portScanUdp        => 'UDPポートスキャン',
    AttackType.portScanStealth    => 'ステルススキャン',
    AttackType.arpSpoofing        => 'ARPスプーフィング',
    AttackType.manInTheMiddle     => 'MitM攻撃',
    AttackType.dnsAmplification   => 'DNS増幅攻撃',
  };
}
