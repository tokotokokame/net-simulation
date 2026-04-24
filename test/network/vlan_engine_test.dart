// test/network/vlan_engine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:net_simulation/models/network_interface.dart';
import 'package:net_simulation/models/packet.dart';
import 'package:net_simulation/network/vlan_engine.dart';

NetworkInterface _accessPort(String name, int vlan) => NetworkInterface(
      name: name, ip: '0.0.0.0', subnet: 24, mac: '00:00:00:00:00:01',
      vlan: vlan, vlanMode: VlanMode.access);

NetworkInterface _trunkPort(String name) => NetworkInterface(
      name: name, ip: '0.0.0.0', subnet: 24, mac: '00:00:00:00:00:02',
      vlan: 1, vlanMode: VlanMode.trunk);

Packet _pkt({int? vlanTag}) => Packet(
      id: 'test', sourceIp: '10.0.0.1', destinationIp: '10.0.0.2',
      sourcePort: 1000, destinationPort: 80, protocol: ProtocolType.tcp,
      vlanTag: vlanTag);

void main() {
  const engine = VlanEngine();

  group('Access port — matching VLAN', () {
    test('tagged frame with matching VLAN passes through (untagged internally)',
        () {
      final result = engine.processFrame(_pkt(vlanTag: 10), _accessPort('eth0', 10));
      expect(result, isNotNull);
      expect(result!.vlanTag, isNull); // stripped
    });

    test('untagged frame on access port is tagged with port VLAN', () {
      final result = engine.processFrame(_pkt(), _accessPort('eth0', 20));
      expect(result, isNotNull);
      expect(result!.vlanTag, equals(20));
    });
  });

  group('Access port — mismatched VLAN is blocked', () {
    test('tagged frame with wrong VLAN returns null', () {
      final result = engine.processFrame(_pkt(vlanTag: 99), _accessPort('eth0', 10));
      expect(result, isNull);
    });

    test('isAllowed returns false for wrong VLAN on access port', () {
      expect(engine.isAllowed(99, _accessPort('eth0', 10)), isFalse);
    });

    test('isAllowed returns true for correct VLAN on access port', () {
      expect(engine.isAllowed(10, _accessPort('eth0', 10)), isTrue);
    });
  });

  group('Trunk port passes all frames', () {
    test('untagged frame passes on trunk', () {
      final result = engine.processFrame(_pkt(), _trunkPort('trunk0'));
      expect(result, isNotNull);
    });

    test('any tagged frame passes on trunk', () {
      for (final tag in [1, 10, 100, 4094]) {
        final result = engine.processFrame(_pkt(vlanTag: tag), _trunkPort('trunk0'));
        expect(result, isNotNull, reason: 'tag=$tag should pass');
      }
    });

    test('isAllowed always returns true on trunk', () {
      expect(engine.isAllowed(0, _trunkPort('t')), isTrue);
      expect(engine.isAllowed(4094, _trunkPort('t')), isTrue);
    });
  });

  group('tag802_1Q and untag', () {
    test('tag802_1Q sets vlanTag', () {
      final tagged = engine.tag802_1Q(_pkt(), 42);
      expect(tagged.vlanTag, equals(42));
    });

    test('untag clears vlanTag', () {
      final untagged = engine.untag(_pkt(vlanTag: 42));
      expect(untagged.vlanTag, isNull);
    });

    test('untag preserves all other fields', () {
      final original = _pkt(vlanTag: 7);
      final untagged = engine.untag(original);
      expect(untagged.id, original.id);
      expect(untagged.sourceIp, original.sourceIp);
      expect(untagged.destinationIp, original.destinationIp);
      expect(untagged.protocol, original.protocol);
    });
  });
}
