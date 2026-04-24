// test/routing/routing_table_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:net_simulation/routing/rib.dart';
import 'package:net_simulation/routing/fib.dart';
import 'package:net_simulation/network/arp_table.dart';

RIBEntry _route({
  required String prefix,
  required int mask,
  String nextHop = '10.0.0.1',
  RoutingProtocol protocol = RoutingProtocol.static,
  int metric = 0,
  int? adminDistance,
}) {
  return RIBEntry(
    prefix: prefix,
    mask: mask,
    nextHop: nextHop,
    protocol: protocol,
    metric: metric,
    adminDistance: adminDistance,
  );
}

void main() {
  group('RIB', () {
    late RIB rib;

    setUp(() => rib = RIB());

    test('addRoute stores the route', () {
      rib.addRoute(_route(prefix: '192.168.1.0', mask: 24));
      expect(rib.routes, hasLength(1));
    });

    test('removeRoute deletes matching prefix', () {
      rib.addRoute(_route(prefix: '10.0.0.0', mask: 8));
      rib.removeRoute('10.0.0.0');
      expect(rib.routes, isEmpty);
    });

    test('getBestRoute returns null when no routes match', () {
      rib.addRoute(_route(prefix: '192.168.1.0', mask: 24));
      expect(rib.getBestRoute('10.0.0.1'), isNull);
    });

    test('getBestRoute prefers lower adminDistance over higher', () {
      rib.addRoute(_route(
        prefix: '10.0.0.0', mask: 8,
        protocol: RoutingProtocol.ospf, // AD=110
      ));
      rib.addRoute(_route(
        prefix: '10.0.0.0', mask: 8,
        protocol: RoutingProtocol.static, // AD=1
        nextHop: '172.16.0.1',
      ));
      final best = rib.getBestRoute('10.1.2.3');
      expect(best, isNotNull);
      expect(best!.nextHop, '172.16.0.1'); // static wins
    });

    test('getBestRoute prefers longer prefix (longest-prefix match)', () {
      rib.addRoute(_route(prefix: '192.168.0.0', mask: 16, nextHop: '1.1.1.1'));
      rib.addRoute(_route(prefix: '192.168.1.0', mask: 24, nextHop: '2.2.2.2'));
      final best = rib.getBestRoute('192.168.1.5');
      expect(best, isNotNull);
      expect(best!.nextHop, '2.2.2.2'); // /24 wins over /16
    });

    test('getBestRoute prefers lower metric among same prefix/AD', () {
      rib.addRoute(_route(
        prefix: '10.0.0.0', mask: 8,
        protocol: RoutingProtocol.rip, metric: 5,
        nextHop: 'high.metric',
      ));
      rib.addRoute(_route(
        prefix: '10.0.0.0', mask: 8,
        protocol: RoutingProtocol.rip, metric: 2,
        nextHop: '10.0.0.99',
      ));
      expect(rib.getBestRoute('10.5.5.5')!.nextHop, '10.0.0.99');
    });

    test('toJson / loadFromJson round-trips correctly', () {
      rib.addRoute(_route(prefix: '172.16.0.0', mask: 12, nextHop: '192.168.0.1'));
      final json = rib.toJson();
      final rib2 = RIB()..loadFromJson(json);
      expect(rib2.routes.first.prefix, '172.16.0.0');
      expect(rib2.routes.first.mask, 12);
    });
  });

  group('FIB', () {
    late RIB rib;
    late ARPTable arp;
    late FIB fib;

    setUp(() {
      rib = RIB();
      arp = ARPTable();
      fib = FIB();
    });

    test('buildFrom creates FIB entry from RIB + ARP', () {
      rib.addRoute(_route(prefix: '192.168.1.0', mask: 24, nextHop: '10.0.0.1'));
      arp.addEntry(ARPEntry(
        ipAddress: '10.0.0.1',
        macAddress: 'AA:BB:CC:DD:EE:FF',
        interfaceName: 'eth0',
        expiry: DateTime.now().add(const Duration(hours: 1)),
      ));
      fib.buildFrom(rib, arp);
      expect(fib.entries, hasLength(1));
      expect(fib.entries.first.resolvedMac, 'AA:BB:CC:DD:EE:FF');
    });

    test('buildFrom leaves resolvedMac null when ARP miss', () {
      rib.addRoute(_route(prefix: '10.0.0.0', mask: 8, nextHop: '172.16.0.1'));
      fib.buildFrom(rib, arp); // ARP table empty
      expect(fib.entries.first.resolvedMac, isNull);
    });

    test('lookup returns matching FIB entry', () {
      rib.addRoute(_route(prefix: '10.0.0.0', mask: 8, nextHop: '192.168.1.1'));
      fib.buildFrom(rib, arp);
      final entry = fib.lookup('10.5.5.5');
      expect(entry, isNotNull);
      expect(entry!.prefix, '10.0.0.0');
    });

    test('lookup returns null for unmatched destination', () {
      rib.addRoute(_route(prefix: '10.0.0.0', mask: 8, nextHop: '192.168.1.1'));
      fib.buildFrom(rib, arp);
      expect(fib.lookup('172.16.1.1'), isNull);
    });

    test('toJson / loadFromJson round-trips correctly', () {
      rib.addRoute(_route(prefix: '192.168.2.0', mask: 24, nextHop: '10.0.0.1'));
      fib.buildFrom(rib, arp);
      final json = fib.toJson();
      final fib2 = FIB()..loadFromJson(json);
      expect(fib2.entries.first.prefix, '192.168.2.0');
    });
  });
}
