// test/simulation/packet_processor_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:net_simulation/simulation/packet_processor.dart';
import 'package:net_simulation/models/device.dart';
import 'package:net_simulation/models/network_interface.dart';
import 'package:net_simulation/models/packet.dart';
import 'package:net_simulation/models/topology.dart';
import 'package:net_simulation/network/arp_table.dart';
import 'package:net_simulation/routing/fib.dart';

// ── Test helpers ──────────────────────────────────────────────────────────────

Device _router(String id, {String ip = '10.0.0.1'}) => Device(
      id: id,
      type: DeviceType.router,
      name: id,
      x: 0,
      y: 0,
      interfaces: [
        NetworkInterface(name: 'eth0', ip: ip, subnet: 24, mac: 'AA:BB:CC:00:00:01'),
      ],
    );

Topology _topo(List<Device> devices) => Topology(
      id: 't1',
      name: 'test',
      devices: devices,
      links: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

Packet _pkt({int ttl = 64, String dst = '192.168.1.100'}) => Packet(
      id: 'p1',
      sourceIp: '10.0.0.1',
      destinationIp: dst,
      sourcePort: 1234,
      destinationPort: 80,
      protocol: ProtocolType.tcp,
      ttl: ttl,
    );

DeviceContext _ctxWithRoute({
  String prefix = '192.168.1.0',
  int mask = 24,
  String nextHop = '192.168.1.254',
  bool withArp = true,
}) {
  final fib = FIB()
    ..loadFromJson([
      {
        'prefix': prefix,
        'mask': mask,
        'nextHopIp': nextHop,
        'outputInterface': 'eth0',
        'resolvedMac': null,
      }
    ]);
  final arp = ARPTable();
  if (withArp) {
    arp.addEntry(ARPEntry(
      ipAddress: nextHop,
      macAddress: 'FF:EE:DD:CC:BB:AA',
      interfaceName: 'eth0',
      expiry: DateTime.now().add(const Duration(hours: 1)),
    ));
  }
  return DeviceContext(fib: fib, arpTable: arp);
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late PacketProcessor processor;
  late Device router;
  late Topology topology;

  setUp(() {
    processor = PacketProcessor();
    router = _router('r1', ip: '10.0.0.1');
    final nextHopDevice = _router('r2', ip: '192.168.1.254');
    topology = _topo([router, nextHopDevice]);
  });

  group('PacketProcessor', () {
    test('TTL=0 packet is dropped with reason "TTL expired"', () {
      final result = processor.processPacket(_pkt(ttl: 0), router, topology);
      expect(result.success, isFalse);
      expect(result.droppedReason, contains('TTL'));
    });

    test('TTL=1 packet is NOT dropped by TTL check', () {
      // TTL=1 is still > 0 so should proceed to routing check, not TTL drop
      final result = processor.processPacket(_pkt(ttl: 1), router, topology);
      expect(result.droppedReason, isNot(contains('TTL')));
    });

    test('No FIB route → drop "No route to host"', () {
      final result = processor.processPacket(_pkt(), router, topology);
      expect(result.success, isFalse);
      expect(result.droppedReason, contains('No route'));
    });

    test('Valid route + ARP entry → success with next device ID', () {
      processor.setContext('r1', _ctxWithRoute());
      final result =
          processor.processPacket(_pkt(dst: '192.168.1.100'), router, topology);
      expect(result.success, isTrue);
      expect(result.nextDeviceId, 'r2');
    });

    test('Route exists but ARP unresolved → drop "ARP unresolved"', () {
      processor.setContext('r1', _ctxWithRoute(withArp: false));
      final result =
          processor.processPacket(_pkt(dst: '192.168.1.100'), router, topology);
      expect(result.success, isFalse);
      expect(result.droppedReason, contains('ARP'));
    });

    test('Exception inside FIB lookup is caught — no crash, returns drop', () {
      processor.setContext('r1', DeviceContext(fib: _ThrowingFIB()));
      PacketProcessResult? result;
      // Must not throw
      expect(
        () => result = processor.processPacket(_pkt(), router, topology),
        returnsNormally,
      );
      expect(result!.success, isFalse);
      expect(result!.droppedReason, isNotNull);
    });

    test('PacketProcessResult.success carries nextDeviceId', () {
      final r = PacketProcessResult.success('dev-42');
      expect(r.success, isTrue);
      expect(r.nextDeviceId, 'dev-42');
      expect(r.droppedReason, isNull);
    });

    test('PacketProcessResult.drop carries reason', () {
      final r = PacketProcessResult.drop('test reason');
      expect(r.success, isFalse);
      expect(r.droppedReason, 'test reason');
      expect(r.nextDeviceId, isNull);
    });
  });
}

/// FIB stub that throws on lookup — tests exception safety in processor.
class _ThrowingFIB extends FIB {
  @override
  FIBEntry? lookup(String destinationIp) =>
      throw StateError('Simulated FIB failure');
}
