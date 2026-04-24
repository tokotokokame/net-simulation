// lib/routing/ospf_engine.dart
import 'dart:developer';
import '../models/device.dart';
import '../models/network_interface.dart';
import '../models/topology.dart';
import 'rib.dart';

/// Simplified OSPF simulation using Dijkstra with OSPF link costs.
///
/// OSPF cost = 10^8 / link.bandwidth (reference bandwidth 100 Mbps).
/// Only routing-capable devices participate.
/// Routes are returned as [RIBEntry] lists with protocol=ospf, AD=110.
class OspfEngine {
  static const _ospfTypes = {
    DeviceType.router, DeviceType.l3Switch, DeviceType.firewall,
    DeviceType.vpnGateway, DeviceType.natGateway,
  };

  /// Computes OSPF routes for all OSPF-capable devices.
  /// Returns a map of deviceId → list of RIBEntries.
  Map<String, List<RIBEntry>> computeRoutes(Topology topology) {
    final result = <String, List<RIBEntry>>{};
    final ospfIds = topology.devices
        .where((d) => _ospfTypes.contains(d.type))
        .map((d) => d.id)
        .toSet();

    for (final srcId in ospfIds) {
      final (dist: dist, prev: prev) = _dijkstra(srcId, topology, ospfIds);
      final ribs = <RIBEntry>[];

      for (final dst in topology.devices) {
        if (dst.id == srcId) continue;
        final cost = dist[dst.id] ?? double.infinity;
        if (cost == double.infinity) continue;

        final nextHopId = _nextHop(srcId, dst.id, prev);
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
            metric: cost.round().clamp(1, 65535),
            protocol: RoutingProtocol.ospf,
            adminDistance: 110,
          ));
        }
      }
      result[srcId] = ribs;
    }

    final total = result.values.fold(0, (s, l) => s + l.length);
    log('OSPF: computed $total route entries across ${ospfIds.length} devices',
        name: 'OspfEngine');
    return result;
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  /// Dijkstra using OSPF cost (10^8 / bandwidth).
  /// Returns (dist, prev) records.
  ({Map<String, double> dist, Map<String, String?> prev}) _dijkstra(
      String srcId, Topology topology, Set<String> eligible) {
    final dist = <String, double>{
      for (final d in topology.devices) d.id: double.infinity,
    };
    final prev = <String, String?>{};
    dist[srcId] = 0;

    // Simple O(V²) Dijkstra — fine for small topologies.
    final unvisited = {...eligible};
    while (unvisited.isNotEmpty) {
      final u = unvisited.reduce(
          (a, b) => (dist[a] ?? double.infinity) < (dist[b] ?? double.infinity) ? a : b);
      if ((dist[u] ?? double.infinity) == double.infinity) break;
      unvisited.remove(u);

      for (final link in topology.links) {
        if (!link.isActive) continue;
        final neighbor = link.deviceAId == u
            ? link.deviceBId
            : link.deviceBId == u
                ? link.deviceAId
                : null;
        if (neighbor == null || !eligible.contains(neighbor)) continue;
        final nd = dist[u]! + _ospfCost(link.bandwidth);
        if (nd < (dist[neighbor] ?? double.infinity)) {
          dist[neighbor] = nd;
          prev[neighbor] = u;
        }
      }
    }
    return (dist: dist, prev: prev);
  }

  /// OSPF reference bandwidth cost: 10^8 / bandwidth (bps).
  static double _ospfCost(int bandwidth) =>
      bandwidth > 0 ? (1e8 / bandwidth) : 1e5;

  /// Walks [prev] from [dst] backwards to find the node whose prev is [src].
  String? _nextHop(String src, String dst, Map<String, String?> prev) {
    String? cur = dst;
    while (cur != null) {
      if (prev[cur] == src) return cur;
      cur = prev[cur];
    }
    return null;
  }
}
