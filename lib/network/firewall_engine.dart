// lib/network/firewall_engine.dart
import 'dart:developer';
import '../models/packet.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum AclAction { permit, deny }

enum AclDirection { inbound, outbound }

// ── AclRule ──────────────────────────────────────────────────────────────────

class AclRule {
  final String id;
  /// Higher number = higher priority (evaluated first).
  final int priority;
  /// null = any source IP (plain IP or CIDR notation supported).
  final String? sourceIp;
  /// null = any destination IP.
  final String? destinationIp;
  /// null = any protocol.
  final ProtocolType? protocol;
  /// null = any source port.
  final int? sourcePort;
  /// null = any destination port.
  final int? destinationPort;
  final AclAction action;
  final AclDirection direction;

  const AclRule({
    required this.id,
    required this.priority,
    this.sourceIp,
    this.destinationIp,
    this.protocol,
    this.sourcePort,
    this.destinationPort,
    required this.action,
    required this.direction,
  });

  @override
  String toString() =>
      'AclRule($id p=$priority ${action.name} ${direction.name} '
      'src=${sourceIp ?? "any"} dst=${destinationIp ?? "any"})';
}

// ── FirewallEngine ───────────────────────────────────────────────────────────

class FirewallEngine {
  const FirewallEngine();

  /// Evaluates [packet] against [rules] for [direction].
  ///
  /// Rules are sorted descending by priority (highest first).
  /// The first matching rule's action is returned.
  /// If no rule matches, defaults to [AclAction.permit].
  AclAction evaluate(
      Packet packet, List<AclRule> rules, AclDirection direction) {
    final sorted = rules
        .where((r) => r.direction == direction)
        .toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    for (final rule in sorted) {
      if (matchesRule(packet, rule)) {
        if (rule.action == AclAction.deny) {
          log('FW deny: rule=${rule.id} '
              '${packet.sourceIp}:${packet.sourcePort}'
              '→${packet.destinationIp}:${packet.destinationPort}',
              name: 'FirewallEngine');
        }
        return rule.action;
      }
    }
    return AclAction.permit; // implicit permit-all
  }

  /// Returns true if [packet] matches all non-null fields of [rule].
  /// IP fields support plain addresses and CIDR notation (e.g. 192.168.1.0/24).
  bool matchesRule(Packet packet, AclRule rule) {
    if (!_matchIp(packet.sourceIp, rule.sourceIp)) return false;
    if (!_matchIp(packet.destinationIp, rule.destinationIp)) return false;
    if (rule.protocol != null && rule.protocol != packet.protocol) {
      return false;
    }
    if (rule.sourcePort != null && rule.sourcePort != packet.sourcePort) {
      return false;
    }
    if (rule.destinationPort != null &&
        rule.destinationPort != packet.destinationPort) {
      return false;
    }
    return true;
  }

  // ── IP matching helpers ───────────────────────────────────────────────────

  static bool _matchIp(String packetIp, String? ruleIp) {
    if (ruleIp == null || ruleIp == 'any') return true;
    if (ruleIp.contains('/')) {
      final parts = ruleIp.split('/');
      final maskBits = int.tryParse(parts[1]) ?? 32;
      return _cidrMatch(packetIp, parts[0], maskBits);
    }
    return packetIp == ruleIp;
  }

  static bool _cidrMatch(String ip, String prefix, int maskBits) {
    if (maskBits == 0) return true;
    final mask = maskBits >= 32
        ? 0xFFFFFFFF
        : (0xFFFFFFFF << (32 - maskBits)) & 0xFFFFFFFF;
    return (_toInt(ip) & mask) == (_toInt(prefix) & mask);
  }

  static int _toInt(String ip) {
    final p = ip.split('.').map(int.parse).toList();
    return (p[0] << 24) | (p[1] << 16) | (p[2] << 8) | p[3];
  }
}
