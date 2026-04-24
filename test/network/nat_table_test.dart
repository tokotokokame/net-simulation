// test/network/nat_table_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:net_simulation/network/nat_table.dart';
import 'package:net_simulation/models/packet.dart';

NATEntry _entry({
  String inside = '192.168.1.10:12345',
  String global = '203.0.113.1:45678',
  String outside = '8.8.8.8:53',
  NATState state = NATState.active,
}) {
  return NATEntry(
    protocol: ProtocolType.udp,
    insideLocal: inside,
    insideGlobal: global,
    outsideGlobal: outside,
    state: state,
    createdAt: DateTime.now(),
  );
}

Packet _packet({String src = '192.168.1.10', int srcPort = 12345}) {
  return Packet(
    id: 'p1',
    sourceIp: src,
    destinationIp: '8.8.8.8',
    sourcePort: srcPort,
    destinationPort: 53,
    protocol: ProtocolType.udp,
  );
}

void main() {
  group('NATTable', () {
    late NATTable table;

    setUp(() => table = NATTable());

    test('addEntry stores the entry', () {
      table.addEntry(_entry());
      expect(table.entries, hasLength(1));
    });

    test('translate rewrites source IP and port for matching packet', () {
      table.addEntry(_entry());
      final result = table.translate(_packet());
      expect(result, isNotNull);
      expect(result!.sourceIp, '203.0.113.1');
      expect(result.sourcePort, 45678);
    });

    test('translate returns null for non-matching source IP', () {
      table.addEntry(_entry());
      final result = table.translate(_packet(src: '10.0.0.99'));
      expect(result, isNull);
    });

    test('translate returns null for non-matching source port', () {
      table.addEntry(_entry());
      final result = table.translate(_packet(srcPort: 99999));
      expect(result, isNull);
    });

    test('translate returns null for closed entry', () {
      table.addEntry(_entry(state: NATState.closed));
      final result = table.translate(_packet());
      expect(result, isNull);
    });

    test('removeByState removes only closed entries', () {
      table.addEntry(_entry(state: NATState.active));
      table.addEntry(_entry(
        inside: '192.168.1.11:22222',
        global: '203.0.113.1:55555',
        state: NATState.closed,
      ));
      final removed = table.removeByState(NATState.closed);
      expect(removed, 1);
      expect(table.entries, hasLength(1));
      expect(table.entries.first.state, NATState.active);
    });

    test('removeByState returns 0 when no entries match state', () {
      table.addEntry(_entry(state: NATState.active));
      expect(table.removeByState(NATState.closed), 0);
    });

    test('toJson / loadFromJson round-trips correctly', () {
      table.addEntry(_entry());
      final json = table.toJson();
      final table2 = NATTable()..loadFromJson(json);
      expect(table2.entries.first.insideLocal, '192.168.1.10:12345');
      expect(table2.entries.first.insideGlobal, '203.0.113.1:45678');
    });
  });
}
