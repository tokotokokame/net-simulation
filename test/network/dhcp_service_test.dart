// test/network/dhcp_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:net_simulation/network/dhcp_service.dart';

const _scope = DhcpScope(
  startIp: '10.0.0.1',
  endIp: '10.0.0.5',
  gatewayIp: '10.0.0.254',
  dnsIp: '8.8.8.8',
  leaseSeconds: 3600,
);

void main() {
  late DhcpService service;

  setUp(() => service = DhcpService());

  group('requestLease', () {
    test('returns an unused IP from the scope', () {
      final lease = service.requestLease('AA:BB:CC:00:00:01', 'dev1', _scope);
      expect(lease, isNotNull);
      expect(lease!.ip, equals('10.0.0.1'));
      expect(lease.mac, equals('AA:BB:CC:00:00:01'));
      expect(lease.deviceId, equals('dev1'));
      expect(lease.isExpired, isFalse);
    });

    test('second request gets the next available IP', () {
      service.requestLease('AA:BB:CC:00:00:01', 'dev1', _scope);
      final lease2 = service.requestLease('AA:BB:CC:00:00:02', 'dev2', _scope);
      expect(lease2!.ip, equals('10.0.0.2'));
    });

    test('same MAC renews and returns the same IP', () {
      final first = service.requestLease('AA:BB:CC:00:00:01', 'dev1', _scope);
      final renewed = service.requestLease('AA:BB:CC:00:00:01', 'dev1', _scope);
      expect(renewed!.ip, equals(first!.ip));
    });

    test('returns null when scope is exhausted', () {
      // Fill the scope (10.0.0.1–10.0.0.5 = 5 IPs).
      const narrowScope = DhcpScope(
        startIp: '10.0.0.1', endIp: '10.0.0.2',
        gatewayIp: '10.0.0.254', dnsIp: '8.8.8.8',
      );
      service.requestLease('AA:00:00:00:00:01', 'dev1', narrowScope);
      service.requestLease('AA:00:00:00:00:02', 'dev2', narrowScope);

      final overflow = service.requestLease('AA:00:00:00:00:03', 'dev3', narrowScope);
      expect(overflow, isNull);
    });
  });

  group('releaseLease', () {
    test('removes the lease so the IP becomes reusable', () {
      service.requestLease('AA:BB:CC:00:00:01', 'dev1', _scope);
      service.releaseLease('AA:BB:CC:00:00:01');

      expect(service.getLeaseByMac('AA:BB:CC:00:00:01'), isNull);
      // IP should now be available again.
      final next = service.requestLease('AA:BB:CC:00:00:02', 'dev2', _scope);
      expect(next!.ip, equals('10.0.0.1'));
    });

    test('releasing an unknown MAC is a no-op', () {
      expect(() => service.releaseLease('FF:FF:FF:FF:FF:FF'), returnsNormally);
    });
  });

  group('removeExpired', () {
    test('removes only expired leases', () {
      // Create a lease with negative duration → immediately expired.
      const expiredScope = DhcpScope(
        startIp: '10.0.0.10', endIp: '10.0.0.20',
        gatewayIp: '10.0.0.254', dnsIp: '8.8.8.8',
        leaseSeconds: -1, // expires in the past
      );
      const validScope = DhcpScope(
        startIp: '10.0.0.50', endIp: '10.0.0.60',
        gatewayIp: '10.0.0.254', dnsIp: '8.8.8.8',
      );

      service.requestLease('EX:PI:RE:D0:00:01', 'expired', expiredScope);
      service.requestLease('VA:LI:D0:00:00:01', 'valid', validScope);

      final removed = service.removeExpired();
      expect(removed, equals(1));
      expect(service.getLeaseByMac('EX:PI:RE:D0:00:01'), isNull);
      expect(service.getLeaseByMac('VA:LI:D0:00:00:01'), isNotNull);
    });

    test('returns 0 when there are no expired leases', () {
      service.requestLease('AA:BB:CC:00:00:01', 'dev1', _scope);
      expect(service.removeExpired(), equals(0));
    });
  });
}
