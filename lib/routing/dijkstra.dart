// lib/routing/dijkstra.dart
import 'dart:collection';
import 'dart:developer';
import '../models/topology.dart';

/// Dijkstra's shortest-path algorithm over a [Topology] graph.
///
/// Edge weight = link.latency (ms).
/// Links with isActive=false are excluded.
/// RIB AdminDistance+Metric integration: wire per-device RIBs via
/// [deviceWeights] map ("deviceId" → cost) when available.
class Dijkstra {
  /// Returns an ordered list of device IDs from [sourceId] to the device
  /// owning [destIp]. Returns [] if destIp not found or unreachable.
  static List<String> findPath(
    String sourceId,
    String destIp,
    Topology topology, {
    Map<String, double>? deviceWeights,
  }) {
    // 1. Locate destination device by interface IP.
    final destDevice = topology.devices
        .where((d) => d.interfaces.any((i) => i.ip == destIp))
        .firstOrNull;
    if (destDevice == null) {
      log('no device owns $destIp', name: 'Dijkstra');
      return [];
    }
    if (sourceId == destDevice.id) return [sourceId];

    // 2. Build adjacency list — active links only.
    final adj = <String, List<_Edge>>{
      for (final d in topology.devices) d.id: [],
    };
    for (final link in topology.links) {
      if (!link.isActive) continue;
      // Use RIB-based weight when provided, else link latency.
      final wA = deviceWeights?[link.deviceAId] ?? link.latency;
      final wB = deviceWeights?[link.deviceBId] ?? link.latency;
      adj[link.deviceAId]?.add(_Edge(link.deviceBId, wA));
      adj[link.deviceBId]?.add(_Edge(link.deviceAId, wB));
    }

    // 3. Dijkstra using SplayTreeSet as min-priority queue.
    final dist = <String, double>{
      for (final d in topology.devices) d.id: double.infinity,
    };
    final prev = <String, String?>{};
    dist[sourceId] = 0.0;

    final pq = SplayTreeSet<_PQEntry>((a, b) {
      final c = a.dist.compareTo(b.dist);
      return c != 0 ? c : a.id.compareTo(b.id); // deterministic tie-break
    });
    pq.add(_PQEntry(sourceId, 0.0));

    while (pq.isNotEmpty) {
      final cur = pq.first;
      pq.remove(cur);
      if (cur.dist > dist[cur.id]!) continue; // stale entry
      if (cur.id == destDevice.id) break;      // early exit

      for (final edge in adj[cur.id] ?? <_Edge>[]) {
        final nd = cur.dist + edge.w;
        if (nd < dist[edge.to]!) {
          dist[edge.to] = nd;
          prev[edge.to] = cur.id;
          pq.add(_PQEntry(edge.to, nd));
        }
      }
    }

    // 4. Unreachable?
    if (dist[destDevice.id]! == double.infinity) {
      log('unreachable: $sourceId → $destIp', name: 'Dijkstra');
      return [];
    }

    // 5. Reconstruct path by following prev pointers.
    final path = <String>[];
    String? node = destDevice.id;
    while (node != null) {
      path.insert(0, node);
      node = prev[node];
    }

    log(
      'path $sourceId→$destIp [${path.join("→")}] '
      'cost=${dist[destDevice.id]!.toStringAsFixed(2)}ms',
      name: 'Dijkstra',
    );
    return path;
  }
}

class _Edge {
  final String to;
  final double w;
  const _Edge(this.to, this.w);
}

class _PQEntry {
  final String id;
  final double dist;
  const _PQEntry(this.id, this.dist);
}
