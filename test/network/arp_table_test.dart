// test/network/arp_table_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:net_simulation/network/arp_table.dart';

ARPEntry _entry(String ip, String mac, {Duration ttl = const Duration(hours: 1)}) {
  return ARPEntry(
    ipAddress: ip,
    macAddress: mac,
    interfaceName: 'eth0',
    expiry: DateTime.now().add(ttl),
  );
}

void main() {
  group('ARPTable', () {
    late ARPTable table;

    setUp(() => table = ARPTable());

    test('lookup returns correct MAC for known IP', () {
      table.addEntry(_entry('192.168.1.1', 'AA:BB:CC:DD:EE:01'));
      expect(table.lookup('192.168.1.1'), equals('AA:BB:CC:DD:EE:01'));
    });

    test('lookup returns null for unknown IP', () {
      expect(table.lookup('10.0.0.99'), isNull);
    });

    test('addEntry stores the entry and is retrievable', () {
      table.addEntry(_entry('10.0.0.1', '11:22:33:44:55:66'));
      expect(table.entries, hasLength(1));
      expect(table.entries.first.macAddress, '11:22:33:44:55:66');
    });

    test('addEntry overwrites existing entry for same IP', () {
      table.addEntry(_entry('10.0.0.1', 'OLD:MAC'));
      table.addEntry(_entry('10.0.0.1', 'NEW:MAC'));
      expect(table.entries, hasLength(1));
      expect(table.lookup('10.0.0.1'), 'NEW:MAC');
    });

    test('removeExpired removes only expired entries', () {
      table.addEntry(_entry('192.168.1.1', 'AA:BB:CC:00:00:01'));
      table.addEntry(ARPEntry(
        ipAddress: '192.168.1.2',
        macAddress: 'AA:BB:CC:00:00:02',
        interfaceName: 'eth0',
        expiry: DateTime.now().subtract(const Duration(seconds: 1)),
      ));
      final removed = table.removeExpired();
      expect(removed, 1);
      expect(table.entries, hasLength(1));
      expect(table.entries.first.ipAddress, '192.168.1.1');
    });

    test('removeExpired returns 0 when all entries are valid', () {
      table.addEntry(_entry('10.0.0.1', 'AA:00:00:00:00:01'));
      table.addEntry(_entry('10.0.0.2', 'AA:00:00:00:00:02'));
      expect(table.removeExpired(), 0);
      expect(table.entries, hasLength(2));
    });

    test('lookup returns null for expired entry', () {
      table.addEntry(ARPEntry(
        ipAddress: '192.168.1.5',
        macAddress: 'EE:FF:00:00:00:01',
        interfaceName: 'eth0',
        expiry: DateTime.now().subtract(const Duration(seconds: 1)),
      ));
      expect(table.lookup('192.168.1.5'), isNull);
    });

    test('toJson / loadFromJson round-trips correctly', () {
      table.addEntry(_entry('10.1.1.1', 'DE:AD:BE:EF:00:01'));
      final json = table.toJson();
      final table2 = ARPTable()..loadFromJson(json);
      expect(table2.entries.first.ipAddress, '10.1.1.1');
      expect(table2.entries.first.macAddress, 'DE:AD:BE:EF:00:01');
    });
  });
}
