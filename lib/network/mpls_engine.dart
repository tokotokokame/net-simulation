// lib/network/mpls_engine.dart
import 'dart:developer';
import '../models/device.dart';
import '../models/packet.dart';
import '../models/topology.dart';

/// MPLS label operation.
enum MplsOp { push, swap, pop }

/// Entry in the Label Forwarding Information Base (LFIB).
class LabelSwitchingEntry {
  final int inLabel;
  final int outLabel;
  final String outInterface;
  final MplsOp operation;

  const LabelSwitchingEntry({
    required this.inLabel,
    required this.outLabel,
    required this.outInterface,
    required this.operation,
  });

  @override
  String toString() =>
      'LSE(in=$inLabel, out=$outLabel, if=$outInterface, op=${operation.name})';
}

/// MPLS label-switching engine.
///
/// - Ingress (non-MPLS → MPLS cloud): push label.
/// - Transit (MPLS cloud → MPLS cloud): swap label.
/// - Egress (MPLS cloud → non-MPLS): pop label.
class MplsEngine {
  /// LFIB: deviceId → inLabel → LabelSwitchingEntry.
  final _lfib = <String, Map<int, LabelSwitchingEntry>>{};
  /// Ingress label allocation: "srcId:dstId" → push label.
  final _ingressLabels = <String, int>{};

  int _nextLabel = 100;

  /// Builds Label-Switched Paths through all [DeviceType.mplsCloud] nodes.
  /// Called once at simulation start.
  void buildLSP(Topology topology) {
    _lfib.clear();
    _ingressLabels.clear();

    final mplsNodes = topology.devices
        .where((d) => d.type == DeviceType.mplsCloud)
        .toList();
    if (mplsNodes.isEmpty) {
      log('MPLS: no mplsCloud nodes — skipping', name: 'MplsEngine');
      return;
    }

    for (final mpls in mplsNodes) {
      _lfib[mpls.id] = {};

      // Edge devices adjacent to this cloud.
      final edges = topology.links
          .where((l) => l.isActive &&
              (l.deviceAId == mpls.id || l.deviceBId == mpls.id))
          .map((l) => l.deviceAId == mpls.id ? l.deviceBId : l.deviceAId)
          .toList();

      // For each src→dst pair through this cloud, allocate labels.
      for (int i = 0; i < edges.length; i++) {
        for (int j = 0; j < edges.length; j++) {
          if (i == j) continue;
          final key = '${edges[i]}:${edges[j]}';
          if (_ingressLabels.containsKey(key)) continue;

          final inLabel = _nextLabel++;
          final outLabel = _nextLabel++;
          _ingressLabels[key] = inLabel;

          // Transit swap entry on the MPLS cloud.
          _lfib[mpls.id]![inLabel] = LabelSwitchingEntry(
            inLabel: inLabel,
            outLabel: outLabel,
            outInterface: 'mpls-out-$j',
            operation: MplsOp.swap,
          );
          log('MPLS: LSP $key → in=$inLabel swap→$outLabel on ${mpls.name}',
              name: 'MplsEngine');
        }
      }
    }
    log('MPLS: built ${_ingressLabels.length} LSPs', name: 'MplsEngine');
  }

  /// Processes [packet] at [device] according to MPLS label operations.
  ///
  /// Returns the (possibly relabelled) packet, or null to drop.
  Packet? processPacket(Packet packet, Device device) {
    if (device.type != DeviceType.mplsCloud) {
      // Non-cloud device: if packet has no label, nothing to do.
      return packet;
    }

    final lfibEntry = _lfib[device.id];

    // Ingress: packet arrives without an MPLS label — push.
    if (packet.mplsLabel == null) {
      final label = _nextLabel++;
      log('MPLS push: label=$label ingress ${device.name}', name: 'MplsEngine');
      return packet.copyWith(mplsLabel: label);
    }

    final entry = lfibEntry?[packet.mplsLabel];
    if (entry == null) {
      // No LFIB entry: egress — pop label.
      log('MPLS pop: label=${packet.mplsLabel} egress ${device.name}',
          name: 'MplsEngine');
      return _popLabel(packet);
    }

    return switch (entry.operation) {
      MplsOp.swap => () {
          log('MPLS swap: ${packet.mplsLabel}→${entry.outLabel} ${device.name}',
              name: 'MplsEngine');
          return packet.copyWith(mplsLabel: entry.outLabel);
        }(),
      MplsOp.pop => () {
          log('MPLS pop: label=${packet.mplsLabel} ${device.name}',
              name: 'MplsEngine');
          return _popLabel(packet);
        }(),
      MplsOp.push => () {
          log('MPLS push: label=${entry.outLabel} ${device.name}',
              name: 'MplsEngine');
          return packet.copyWith(mplsLabel: entry.outLabel);
        }(),
    };
  }

  /// Returns a copy of [p] with the MPLS label removed.
  Packet _popLabel(Packet p) => Packet(
        id: p.id, sourceIp: p.sourceIp, destinationIp: p.destinationIp,
        sourcePort: p.sourcePort, destinationPort: p.destinationPort,
        protocol: p.protocol, size: p.size, ttl: p.ttl,
        tcpFlags: p.tcpFlags, status: p.status,
        vlanTag: p.vlanTag, droppedReason: p.droppedReason,
        // mplsLabel intentionally omitted → null
      );
}
