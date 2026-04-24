// test/network/firewall_engine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:net_simulation/models/packet.dart';
import 'package:net_simulation/network/firewall_engine.dart';

Packet _pkt({
  String src = '192.168.1.10',
  String dst = '10.0.0.1',
  int sport = 49152,
  int dport = 80,
  ProtocolType proto = ProtocolType.tcp,
}) =>
    Packet(
      id: 'test', sourceIp: src, destinationIp: dst,
      sourcePort: sport, destinationPort: dport, protocol: proto,
    );

const _dir = AclDirection.inbound;
const engine = FirewallEngine();

void main() {
  group('permit rule', () {
    test('explicit permit passes the packet', () {
      final rules = [
        const AclRule(id: '1', priority: 10, action: AclAction.permit, direction: _dir),
      ];
      expect(engine.evaluate(_pkt(), rules, _dir), AclAction.permit);
    });

    test('no matching rule defaults to permit', () {
      // Rule with wrong direction — no match.
      final rules = [
        const AclRule(
            id: '1', priority: 10, action: AclAction.deny,
            direction: AclDirection.outbound),
      ];
      expect(engine.evaluate(_pkt(), rules, _dir), AclAction.permit);
    });
  });

  group('deny rule', () {
    test('exact-IP deny blocks the packet', () {
      final rules = [
        const AclRule(
            id: '1', priority: 10,
            sourceIp: '192.168.1.10',
            action: AclAction.deny, direction: _dir),
      ];
      expect(engine.evaluate(_pkt(), rules, _dir), AclAction.deny);
    });

    test('CIDR deny blocks packets in subnet', () {
      final rules = [
        const AclRule(
            id: '1', priority: 10,
            sourceIp: '192.168.1.0/24',
            action: AclAction.deny, direction: _dir),
      ];
      expect(engine.evaluate(_pkt(src: '192.168.1.99'), rules, _dir), AclAction.deny);
    });

    test('CIDR deny does not block packets outside subnet', () {
      final rules = [
        const AclRule(
            id: '1', priority: 10,
            sourceIp: '192.168.2.0/24',
            action: AclAction.deny, direction: _dir),
      ];
      expect(engine.evaluate(_pkt(src: '192.168.1.10'), rules, _dir), AclAction.permit);
    });
  });

  group('priority ordering', () {
    test('higher-priority permit wins over lower-priority deny', () {
      final rules = [
        const AclRule(id: 'low', priority: 5,
            action: AclAction.deny, direction: _dir),
        const AclRule(id: 'high', priority: 100,
            action: AclAction.permit, direction: _dir),
      ];
      expect(engine.evaluate(_pkt(), rules, _dir), AclAction.permit);
    });

    test('higher-priority deny wins over lower-priority permit', () {
      final rules = [
        const AclRule(id: 'low', priority: 5,
            action: AclAction.permit, direction: _dir),
        const AclRule(id: 'high', priority: 100,
            destinationPort: 80,
            action: AclAction.deny, direction: _dir),
      ];
      expect(engine.evaluate(_pkt(dport: 80), rules, _dir), AclAction.deny);
    });
  });

  group('null (any) matching', () {
    test('all-null rule matches every packet', () {
      final rules = [
        const AclRule(id: '1', priority: 10,
            action: AclAction.deny, direction: _dir),
      ];
      // Different source, destination, protocol — still matches.
      expect(engine.evaluate(_pkt(src: '1.2.3.4', dst: '5.6.7.8',
          proto: ProtocolType.udp), rules, _dir), AclAction.deny);
    });

    test('null protocol matches all protocols', () {
      final rules = [
        const AclRule(id: '1', priority: 10,
            protocol: null,
            action: AclAction.permit, direction: _dir),
      ];
      for (final proto in ProtocolType.values) {
        expect(engine.evaluate(_pkt(proto: proto), rules, _dir), AclAction.permit,
            reason: 'protocol=$proto should match');
      }
    });
  });

  group('matchesRule', () {
    test('port-specific rule does not match other ports', () {
      const rule = AclRule(id: '1', priority: 10,
          destinationPort: 443, action: AclAction.deny, direction: _dir);
      expect(engine.matchesRule(_pkt(dport: 80), rule), isFalse);
      expect(engine.matchesRule(_pkt(dport: 443), rule), isTrue);
    });
  });
}
