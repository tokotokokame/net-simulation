// lib/simulation/routing_engine.dart
import 'dart:collection';
import 'dart:developer';
import '../models/link.dart';
import '../models/topology.dart';

/// Link-based Dijkstra. Returns ordered list of device IDs, or [] if unreachable.
/// Works even for devices without IP addresses (cloud/WAN nodes included).
class RoutingEngine {
  List<String> shortestPath(String srcId, String dstId, Topology topology) {
    if (srcId == dstId) return [srcId];

    // Build adjacency from active links — ALL device types are transit candidates.
    final adj = <String, List<_Edge>>{};
    for (final link in topology.links) {
      if (!link.isActive) continue;
      final cost = _linkCost(link);
      adj.putIfAbsent(link.deviceAId, () => []).add(_Edge(link.deviceBId, cost));
      adj.putIfAbsent(link.deviceBId, () => []).add(_Edge(link.deviceAId, cost));
    }

    final dist = <String, double>{srcId: 0.0};
    final prev = <String, String?>{};
    final pq = SplayTreeSet<_PQEntry>((a, b) {
      final c = a.cost.compareTo(b.cost);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
    pq.add(_PQEntry(srcId, 0.0));

    while (pq.isNotEmpty) {
      final cur = pq.first;
      pq.remove(cur);
      if (cur.id == dstId) break;
      if ((dist[cur.id] ?? double.infinity) < cur.cost) continue;

      for (final edge in adj[cur.id] ?? const <_Edge>[]) {
        final newCost = cur.cost + edge.cost;
        if (newCost < (dist[edge.to] ?? double.infinity)) {
          dist[edge.to] = newCost;
          prev[edge.to] = cur.id;
          pq.add(_PQEntry(edge.to, newCost));
        }
      }
    }

    if (!dist.containsKey(dstId)) {
      log('unreachable: $srcId → $dstId', name: 'RoutingEngine');
      return [];
    }

    final path = <String>[];
    String? cur = dstId;
    while (cur != null) {
      path.insert(0, cur);
      cur = prev[cur];
    }

    if (path.isEmpty || path.first != srcId) return [];
    log('path $srcId→$dstId [${path.join("→")}]', name: 'RoutingEngine');
    return path;
  }

  double _linkCost(Link link) {
    final bw = link.bandwidth > 0 ? link.bandwidth : 1000000;
    return 1e9 / bw;
  }
}

class _Edge {
  final String to;
  final double cost;
  const _Edge(this.to, this.cost);
}

class _PQEntry {
  final String id;
  final double cost;
  const _PQEntry(this.id, this.cost);
}
