// lib/routing/rip_engine.dart
import 'dart:collection';
import 'dart:developer';
import '../models/device.dart';
import '../models/network_interface.dart';
import '../models/topology.dart';
import 'rib.dart';

/// Simplified RIP simulation using BFS hop-count distance.
///
/// - Metric = hop count; 16 = infinity (unreachable).
/// - Maximum path 15 hops (RIP spec).
/// - Routes returned with protocol=rip, adminDistance=120.
class RipEngine {
  static const _ripTypes = {DeviceType.router, DeviceType.l3Switch};
  static const _infinity = 16;

  /// Computes RIP routes for all RIP-capable devices.
  /// Returns deviceId → list of RIBEntries.
  Map<String, List<RIBEntry>> computeRoutes(Topology topology) {
    final result = <String, List<RIBEntry>>{};
    final ripIds = topology.devices
        .where((d) => _ripTypes.contains(d.type))
        .map((d) => d.id)
        .toSet();

    for (final srcId in ripIds) {
      final hops = _bfs(srcId, topology, ripIds);
      final ribs = <RIBEntry>[];

      for (final dst in topology.devices) {
        if (dst.id == srcId) continue;
        final hopCount = hops[dst.id] ?? _infinity;
        if (hopCount >= _infinity) continue;

        final nextHopId = _nextHop(srcId, dst.id, topology, ripIds);
        if (nextHopId == null) continue;

        final nextDev = topology.devices
            .where((d) => d.id == nextHopId).firstOrNull;
        final nextIp = nextDev?.interfaces
            .where((i) => i.status == InterfaceStatus.up && i.ip != '0.0.0.0')
            .firstOrNull?.ip ?? '0.0.0.0';

        for (final iface in dst.interfaces) {
          if (iface.ip == '0.0.0.0' || iface.status == InterfaceStatus.down) continue;
          ribs.add(RIBEntry(
            prefix: iface.ip,
            mask: iface.subnet,
            nextHop: nextIp,
            metric: hopCount,
            protocol: RoutingProtocol.rip,
            adminDistance: 120,
          ));
        }
      }
      result[srcId] = ribs;
    }

    final total = result.values.fold(0, (s, l) => s + l.length);
    log('RIP: computed $total route entries across ${ripIds.length} devices',
        name: 'RipEngine');
    return result;
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  /// BFS hop-count from [srcId] within [eligible] devices.
  /// Returns deviceId → hop count (≥16 = unreachable).
  Map<String, int> _bfs(
      String srcId, Topology topology, Set<String> eligible) {
    final hops = <String, int>{srcId: 0};
    final queue = Queue<String>()..add(srcId);

    while (queue.isNotEmpty) {
      final cur = queue.removeFirst();
      if (hops[cur]! >= 15) continue; // max hops reached

      for (final link in topology.links) {
        if (!link.isActive) continue;
        final neighbor = link.deviceAId == cur
            ? link.deviceBId
            : link.deviceBId == cur
                ? link.deviceAId
                : null;
        if (neighbor == null || hops.containsKey(neighbor)) continue;
        if (!eligible.contains(neighbor)) continue;

        hops[neighbor] = hops[cur]! + 1;
        queue.add(neighbor);
      }
    }
    return hops;
  }

  /// Returns the direct neighbor of [src] on the shortest path to [dst].
  String? _nextHop(String src, String dst, Topology topology, Set<String> eligible) {
    // Single-hop BFS step: find neighbors of src, then BFS from each.
    final srcNeighbors = topology.links
        .where((l) => l.isActive &&
            (l.deviceAId == src || l.deviceBId == src) &&
            eligible.contains(l.deviceAId == src ? l.deviceBId : l.deviceAId))
        .map((l) => l.deviceAId == src ? l.deviceBId : l.deviceAId)
        .toList();

    String? best;
    int bestHops = _infinity;
    for (final nb in srcNeighbors) {
      final h = _bfs(nb, topology, eligible)[dst] ?? _infinity;
      if (h < bestHops) { bestHops = h; best = nb; }
    }
    return best;
  }
}
