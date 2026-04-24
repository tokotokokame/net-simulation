// lib/network/sdn_controller.dart
import 'dart:developer';
import '../models/device.dart';
import '../models/packet.dart';
import '../models/topology.dart';
import '../simulation/packet_processor.dart';

// ── Enums / data classes ──────────────────────────────────────────────────────

enum FlowAction { forward, drop, modify }

/// An OpenFlow-style flow rule installed on a switch.
class FlowRule {
  final String id;
  /// Higher priority is evaluated first.
  final int priority;
  /// null = match any (CIDR notation supported: "192.168.1.0/24").
  final String? matchSrcIp;
  final String? matchDstIp;
  final ProtocolType? matchProtocol;
  final FlowAction action;
  /// Target device ID for forward / modify actions.
  final String? outputPort;
  /// For [FlowAction.modify]: replace source IP (null = keep original).
  final String? modifySrcIp;
  /// For [FlowAction.modify]: replace destination IP (null = keep original).
  final String? modifyDstIp;

  const FlowRule({
    required this.id,
    this.priority = 0,
    this.matchSrcIp,
    this.matchDstIp,
    this.matchProtocol,
    required this.action,
    this.outputPort,
    this.modifySrcIp,
    this.modifyDstIp,
  });

  @override
  String toString() =>
      'FlowRule($id p=$priority ${action.name} '
      'src=${matchSrcIp ?? "any"} dst=${matchDstIp ?? "any"} out=$outputPort)';
}

// ── SdnController ────────────────────────────────────────────────────────────

class SdnController {
  /// Per-switch flow tables: switchDeviceId → rules.
  final _flowTables = <String, List<FlowRule>>{};
  bool _active = false;

  /// Scans [topology] for a [DeviceType.sdnController] node.
  /// Must be called at simulation start; returns true when active.
  bool activate(Topology topology) {
    _active = topology.devices.any((d) => d.type == DeviceType.sdnController);
    log('SDN: controller ${_active ? "active" : "inactive (no sdnController node)"}',
        name: 'SdnController');
    return _active;
  }

  void installFlowRule(String switchDeviceId, FlowRule rule) {
    _flowTables.putIfAbsent(switchDeviceId, () => []).add(rule);
    log('SDN: installed $rule on switch=$switchDeviceId', name: 'SdnController');
  }

  void removeFlowRule(String switchDeviceId, String ruleId) {
    final table = _flowTables[switchDeviceId];
    if (table == null) return;
    final before = table.length;
    table.removeWhere((r) => r.id == ruleId);
    if (table.length < before) {
      log('SDN: removed rule=$ruleId from switch=$switchDeviceId',
          name: 'SdnController');
    }
  }

  List<FlowRule> getFlowTable(String switchDeviceId) =>
      List.unmodifiable(_flowTables[switchDeviceId] ?? const []);

  /// Processes [packet] at [openFlowSwitch] using the installed flow table.
  ///
  /// - Requires [activate] to have been called with a topology that contains
  ///   a [DeviceType.sdnController] device.
  /// - Table-miss → drop (packet-in to controller is outside simulation scope).
  PacketProcessResult processPacket(Packet packet, Device openFlowSwitch) {
    if (!_active) {
      log('SDN: inactive', name: 'SdnController');
      return PacketProcessResult.drop('SDN: controller not active');
    }
    if (openFlowSwitch.type != DeviceType.openFlowSwitch) {
      return PacketProcessResult.drop('SDN: not an OpenFlow switch');
    }

    // Sort descending by priority (highest evaluated first).
    final table = (_flowTables[openFlowSwitch.id] ?? <FlowRule>[]).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    for (final rule in table) {
      if (!_matches(packet, rule)) continue;
      log('SDN: rule=${rule.id} action=${rule.action.name} '
          'pkt=${packet.id} on ${openFlowSwitch.name}', name: 'SdnController');
      return switch (rule.action) {
        FlowAction.forward => PacketProcessResult.success(rule.outputPort),
        FlowAction.drop    => PacketProcessResult.drop('SDN flow: drop'),
        FlowAction.modify  => PacketProcessResult.success(
            rule.outputPort,
            packet: packet.copyWith(
              sourceIp: rule.modifySrcIp,
              destinationIp: rule.modifyDstIp,
            )),
      };
    }

    log('SDN: table-miss pkt=${packet.id} on ${openFlowSwitch.name}',
        name: 'SdnController');
    return PacketProcessResult.drop('SDN: table-miss');
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static bool _matches(Packet pkt, FlowRule rule) {
    if (!_matchIp(pkt.sourceIp, rule.matchSrcIp)) return false;
    if (!_matchIp(pkt.destinationIp, rule.matchDstIp)) return false;
    if (rule.matchProtocol != null && rule.matchProtocol != pkt.protocol) {
      return false;
    }
    return true;
  }

  static bool _matchIp(String ip, String? pattern) {
    if (pattern == null || pattern == 'any') return true;
    if (pattern.contains('/')) {
      final p = pattern.split('/');
      return _cidr(ip, p[0], int.tryParse(p[1]) ?? 32);
    }
    return ip == pattern;
  }

  static bool _cidr(String ip, String prefix, int bits) {
    if (bits == 0) return true;
    final mask = bits >= 32 ? 0xFFFFFFFF : (0xFFFFFFFF << (32 - bits)) & 0xFFFFFFFF;
    return (_int(ip) & mask) == (_int(prefix) & mask);
  }

  static int _int(String ip) {
    final p = ip.split('.').map(int.parse).toList();
    return (p[0] << 24) | (p[1] << 16) | (p[2] << 8) | p[3];
  }
}
