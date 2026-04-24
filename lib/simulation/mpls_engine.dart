// lib/simulation/mpls_engine.dart
import 'dart:developer';
import '../models/device.dart';
import '../models/topology.dart';
import 'packet_processor.dart';

/// Pre-computes MPLS Label-Switched Paths through mplsCloud nodes.
/// Returns "srcDeviceId:dstDeviceId" → MPLS label map.
class MplsEngine {
  static int _nextLabel = 100;

  static Map<String, int> computeLsps(
      Topology topology, PacketProcessor processor) {
    final lsps = <String, int>{};
    final mplsNodes = topology.devices
        .where((d) => d.type == DeviceType.mplsCloud)
        .toList();

    if (mplsNodes.isEmpty) {
      log('MPLS: no cloud nodes — skipping', name: 'MPLS');
      return lsps;
    }

    for (final mpls in mplsNodes) {
      // Collect edge routers adjacent to this MPLS cloud.
      final edges = topology.links
          .where((l) => l.isActive &&
              (l.deviceAId == mpls.id || l.deviceBId == mpls.id))
          .map((l) => l.deviceAId == mpls.id ? l.deviceBId : l.deviceAId)
          .toList();

      for (final src in edges) {
        for (final dst in edges) {
          if (src == dst) continue;
          final key = '$src:$dst';
          if (lsps.containsKey(key)) continue;
          final label = _nextLabel++;
          lsps[key] = label;
          log('MPLS: LSP $key → label $label', name: 'MPLS');
        }
      }
    }
    log('MPLS: ${lsps.length} LSPs computed', name: 'MPLS');
    return lsps;
  }
}
