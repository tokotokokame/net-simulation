// lib/simulation/queue_discipline.dart
import 'dart:collection';
import 'dart:developer';
import 'dart:math' as math;
import '../models/packet.dart';

enum QueueDiscipline { fifo, pq, wfq }

enum QueuePriority { high, medium, normal, low }

QueuePriority _priority(Packet p) => switch (p.protocol) {
      ProtocolType.icmp ||
      ProtocolType.ospf ||
      ProtocolType.bgp ||
      ProtocolType.arp =>
        QueuePriority.high,
      ProtocolType.tcp => QueuePriority.normal,
      ProtocolType.udp => QueuePriority.low,
    };

// ── RED (Random Early Detection) ──────────────────────────────────────────────

class RED {
  final double minR; // fraction of maxSize at which dropping starts
  final double maxR; // fraction of maxSize at which all packets drop
  final _rng = math.Random();

  RED({this.minR = 0.3, this.maxR = 0.8});

  bool shouldDrop(int current, int maxSize) {
    final lo = maxSize * minR, hi = maxSize * maxR;
    if (current < lo) return false;
    if (current >= hi) return true;
    return _rng.nextDouble() < (current - lo) / (hi - lo);
  }
}

// ── FIFO Queue ─────────────────────────────────────────────────────────────────

class FIFOQueue {
  final int maxSize;
  final RED? red;
  final _q = Queue<Packet>();

  FIFOQueue({this.maxSize = 100, this.red});

  int get currentSize => _q.length;
  bool get isFull => _q.length >= maxSize;

  bool enqueue(Packet p) {
    if (red != null && red!.shouldDrop(_q.length, maxSize)) {
      log('FIFO RED drop: ${p.id}', name: 'Queue');
      return false;
    }
    if (isFull) {
      log('FIFO tail-drop: ${p.id}', name: 'Queue');
      return false;
    }
    _q.addLast(p);
    return true;
  }

  Packet? dequeue() => _q.isNotEmpty ? _q.removeFirst() : null;
}

// ── Priority Queue ─────────────────────────────────────────────────────────────

class PriorityQueue {
  final int maxSize;
  final _qs = {for (final p in QueuePriority.values) p: Queue<Packet>()};

  PriorityQueue({this.maxSize = 100});

  int get currentSize => _qs.values.fold(0, (s, q) => s + q.length);
  int get _subMax => (maxSize / 4).ceil();

  bool enqueue(Packet p) {
    final pri = _priority(p);
    if (_qs[pri]!.length >= _subMax) {
      log('PQ drop [$pri]: ${p.id}', name: 'Queue');
      return false;
    }
    _qs[pri]!.addLast(p);
    return true;
  }

  Packet? dequeue() {
    for (final pri in QueuePriority.values) {
      if (_qs[pri]!.isNotEmpty) return _qs[pri]!.removeFirst();
    }
    return null;
  }
}

// ── WFQ Queue (Deficit Weighted Round-Robin) ──────────────────────────────────

class WFQQueue {
  final int maxSize;
  final _flows = <String, Queue<Packet>>{};
  final _weights = <String, double>{};
  final _deficits = <String, double>{};

  WFQQueue({this.maxSize = 100});

  int get currentSize => _flows.values.fold(0, (s, q) => s + q.length);

  String _key(Packet p) =>
      '${p.sourceIp}|${p.destinationIp}|${p.protocol.name}|${p.destinationPort}';

  void setWeight(String flowKey, double weight) => _weights[flowKey] = weight;

  bool enqueue(Packet p) {
    if (currentSize >= maxSize) {
      log('WFQ tail-drop: ${p.id}', name: 'Queue');
      return false;
    }
    final k = _key(p);
    _flows.putIfAbsent(k, Queue.new);
    _weights.putIfAbsent(k, () => 1.0);
    _deficits.putIfAbsent(k, () => 0.0);
    _flows[k]!.addLast(p);
    return true;
  }

  Packet? dequeue() {
    final active = _flows.entries.where((e) => e.value.isNotEmpty).toList();
    if (active.isEmpty) return null;
    for (final e in active) {
      _deficits[e.key] = (_deficits[e.key] ?? 0) + (_weights[e.key] ?? 1.0);
    }
    active.sort((a, b) =>
        (_deficits[b.key] ?? 0).compareTo(_deficits[a.key] ?? 0));
    final k = active.first.key;
    final pkt = _flows[k]!.removeFirst();
    _deficits[k] = (_deficits[k] ?? 0) - 1.0;
    if (_flows[k]!.isEmpty) _flows.remove(k);
    return pkt;
  }
}
