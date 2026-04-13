// test/simulation/queue_discipline_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:net_simulation_v4/simulation/queue_discipline.dart';
import 'package:net_simulation_v4/models/packet.dart';

Packet _p(String id, {ProtocolType proto = ProtocolType.tcp, int dport = 80}) =>
    Packet(
      id: id,
      sourceIp: '10.0.0.1',
      destinationIp: '10.0.0.2',
      sourcePort: 1234,
      destinationPort: dport,
      protocol: proto,
    );

void main() {
  // ── FIFO ──────────────────────────────────────────────────────────────────

  group('FIFOQueue', () {
    test('enqueue and dequeue maintain FIFO order', () {
      final q = FIFOQueue(maxSize: 5);
      q.enqueue(_p('p1'));
      q.enqueue(_p('p2'));
      q.enqueue(_p('p3'));
      expect(q.dequeue()?.id, 'p1');
      expect(q.dequeue()?.id, 'p2');
      expect(q.dequeue()?.id, 'p3');
      expect(q.dequeue(), isNull);
    });

    test('enqueue returns false when full (tail-drop)', () {
      final q = FIFOQueue(maxSize: 2);
      expect(q.enqueue(_p('p1')), isTrue);
      expect(q.enqueue(_p('p2')), isTrue);
      expect(q.enqueue(_p('p3')), isFalse);
      expect(q.currentSize, 2);
      expect(q.isFull, isTrue);
    });

    test('dequeue returns null on empty queue', () {
      expect(FIFOQueue().dequeue(), isNull);
    });

    test('currentSize tracks correctly after enqueue/dequeue', () {
      final q = FIFOQueue(maxSize: 10);
      q.enqueue(_p('a'));
      q.enqueue(_p('b'));
      expect(q.currentSize, 2);
      q.dequeue();
      expect(q.currentSize, 1);
    });
  });

  // ── Priority Queue ─────────────────────────────────────────────────────────

  group('PriorityQueue', () {
    test('ICMP (high) dequeued before TCP (normal) and UDP (low)', () {
      final pq = PriorityQueue(maxSize: 100);
      pq.enqueue(_p('udp1', proto: ProtocolType.udp));
      pq.enqueue(_p('tcp1', proto: ProtocolType.tcp));
      pq.enqueue(_p('icmp1', proto: ProtocolType.icmp));
      expect(pq.dequeue()?.id, 'icmp1');
      expect(pq.dequeue()?.id, 'tcp1');
      expect(pq.dequeue()?.id, 'udp1');
    });

    test('sub-queue overflow causes drop and returns false', () {
      // maxSize=4 → subMax=1 per priority band
      final pq = PriorityQueue(maxSize: 4);
      expect(pq.enqueue(_p('u1', proto: ProtocolType.udp)), isTrue);
      expect(pq.enqueue(_p('u2', proto: ProtocolType.udp)), isFalse);
    });

    test('dequeue returns null when all sub-queues empty', () {
      expect(PriorityQueue().dequeue(), isNull);
    });

    test('mixed protocols enqueued correctly', () {
      final pq = PriorityQueue(maxSize: 100);
      pq.enqueue(_p('bgp1', proto: ProtocolType.bgp));
      pq.enqueue(_p('tcp1', proto: ProtocolType.tcp));
      // BGP is high priority → dequeued first
      expect(pq.dequeue()?.id, 'bgp1');
    });
  });

  // ── RED ────────────────────────────────────────────────────────────────────

  group('RED', () {
    test('shouldDrop is false below minThresh', () {
      final red = RED();
      expect(red.shouldDrop(0, 100), isFalse);
      expect(red.shouldDrop(29, 100), isFalse);
    });

    test('shouldDrop is true at and above maxThresh', () {
      final red = RED();
      expect(red.shouldDrop(80, 100), isTrue);
      expect(red.shouldDrop(100, 100), isTrue);
      expect(red.shouldDrop(99, 100), isTrue);
    });

    test('shouldDrop is probabilistic in [minThresh, maxThresh)', () {
      final red = RED();
      int drops = 0;
      for (int i = 0; i < 1000; i++) {
        if (red.shouldDrop(55, 100)) drops++;
      }
      // p ≈ (55-30)/(80-30) = 0.5 → expect roughly 300–700 drops
      expect(drops, greaterThan(200));
      expect(drops, lessThan(800));
    });

    test('RED shouldDrop=true at maxThresh causes enqueue to return false', () {
      // RED with minR=maxR=0.9 → deterministic drop at size >= 9, no randomness.
      final q = FIFOQueue(maxSize: 10, red: RED(minR: 0.9, maxR: 0.9));
      // Fill 9 slots (all below minThresh=9 → no probabilistic drops).
      for (int i = 0; i < 9; i++) {
        q.enqueue(_p('p$i'));
      }
      // currentSize=9 >= maxThresh=9 → RED must drop deterministically.
      expect(q.enqueue(_p('overflow')), isFalse);
    });
  });

  // ── WFQ ───────────────────────────────────────────────────────────────────

  group('WFQQueue', () {
    test('enqueue and dequeue single flow', () {
      final wfq = WFQQueue(maxSize: 10);
      expect(wfq.enqueue(_p('p1')), isTrue);
      expect(wfq.dequeue()?.id, 'p1');
      expect(wfq.dequeue(), isNull);
    });

    test('tail-drop when full', () {
      final wfq = WFQQueue(maxSize: 1);
      expect(wfq.enqueue(_p('p1')), isTrue);
      expect(wfq.enqueue(_p('p2')), isFalse);
      expect(wfq.currentSize, 1);
    });

    test('two flows both dequeue eventually', () {
      final wfq = WFQQueue(maxSize: 20);
      final pA = _p('a1', dport: 80);
      final pB = _p('b1', dport: 443);
      wfq.enqueue(pA);
      wfq.enqueue(pB);
      final results = {wfq.dequeue()?.id, wfq.dequeue()?.id};
      expect(results, containsAll(['a1', 'b1']));
    });
  });
}
