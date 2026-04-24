// test/network/ids_engine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:net_simulation/models/attack_packet.dart';
import 'package:net_simulation/models/device.dart';
import 'package:net_simulation/models/network_interface.dart';
import 'package:net_simulation/models/packet.dart';
import 'package:net_simulation/network/ids_engine.dart';

void main() {
  const engine = IdsEngine();

  // Shared IDS device fixture.
  const idsDevice = Device(
    id: 'ids-1',
    type: DeviceType.ids,
    name: 'IDS-1',
    x: 0,
    y: 0,
    interfaces: [
      NetworkInterface(name: 'eth0', ip: '10.0.0.10', subnet: 24, mac: 'aa:bb:cc:dd:ee:ff'),
    ],
  );

  Packet synPkt(String src, {bool ack = false}) => Packet(
        id: 'p-$src-${DateTime.now().microsecondsSinceEpoch}',
        sourceIp: src,
        destinationIp: '10.0.0.2',
        sourcePort: 12345,
        destinationPort: 80,
        protocol: ProtocolType.tcp,
        tcpFlags: TcpFlags(syn: true, ack: ack),
      );

  // ── SYN Flood ─────────────────────────────────────────────────────────────

  group('SYN flood detection', () {
    test('detects SYN flood above threshold (50 pkts)', () {
      // Generate 55 SYN-only packets from the same source.
      final pkts = List.generate(55, (_) => synPkt('192.168.1.100'));
      final alerts = engine.analyze(pkts, idsDevice);

      expect(alerts, isNotEmpty);
      final a = alerts.firstWhere(
          (a) => a.attackType == AttackType.dosSynFlood,
          orElse: () => throw Exception('No SYN flood alert'));
      expect(a.sourceIp, equals('192.168.1.100'));
      expect(a.packetCount, equals(55));
      expect(a.blocked, isTrue); // action = block
    });

    test('does NOT detect SYN flood below threshold', () {
      // Only 20 SYN packets — under the 50-packet threshold.
      final pkts = List.generate(20, (_) => synPkt('192.168.1.200'));
      final alerts = engine.analyze(pkts, idsDevice);

      final synAlerts =
          alerts.where((a) => a.attackType == AttackType.dosSynFlood);
      expect(synAlerts, isEmpty);
    });

    test('SYN-ACK packets are NOT counted as flood', () {
      // SYN+ACK = normal three-way handshake response, not a flood.
      final pkts = List.generate(60, (_) => synPkt('10.1.1.1', ack: true));
      final alerts = engine.analyze(pkts, idsDevice);

      final synAlerts =
          alerts.where((a) => a.attackType == AttackType.dosSynFlood);
      expect(synAlerts, isEmpty);
    });
  });

  // ── Port Scan ─────────────────────────────────────────────────────────────

  group('Port scan detection', () {
    test('detects port scan when 10+ distinct ports accessed', () {
      // One packet each to 12 different destination ports.
      final pkts = List.generate(
        12,
        (i) => Packet(
          id: 'scan-$i',
          sourceIp: '10.2.2.2',
          destinationIp: '10.0.0.5',
          sourcePort: 50000,
          destinationPort: 1000 + i, // 12 unique ports
          protocol: ProtocolType.tcp,
          tcpFlags: const TcpFlags(syn: true),
        ),
      );

      final alerts = engine.analyze(pkts, idsDevice);
      final scanAlert = alerts.firstWhere(
          (a) => a.attackType == AttackType.portScanTcp,
          orElse: () => throw Exception('No port scan alert'));
      expect(scanAlert.packetCount, greaterThanOrEqualTo(10));
    });

    test('does NOT detect port scan for fewer than 10 ports', () {
      final pkts = List.generate(
        5,
        (i) => Packet(
          id: 'ok-$i',
          sourceIp: '10.3.3.3',
          destinationIp: '10.0.0.5',
          sourcePort: 50000,
          destinationPort: 80 + i, // only 5 unique ports
          protocol: ProtocolType.tcp,
        ),
      );

      final alerts = engine.analyze(pkts, idsDevice);
      final scanAlerts =
          alerts.where((a) => a.attackType == AttackType.portScanTcp);
      expect(scanAlerts, isEmpty);
    });
  });

  // ── ARP Spoofing ──────────────────────────────────────────────────────────

  group('ARP spoofing detection', () {
    test('detects ARP spoofing when same IP has 2+ different MACs', () {
      // Two ARP packets from the same IP but different "MACs" encoded via sourcePort.
      final arpPkts = [
        const Packet(
          id: 'arp-1',
          sourceIp: '10.0.0.1',  // gateway IP
          destinationIp: '255.255.255.255',
          sourcePort: 1001,       // used as MAC discriminator in simplified model
          destinationPort: 0,
          protocol: ProtocolType.arp,
        ),
        const Packet(
          id: 'arp-2',
          sourceIp: '10.0.0.1',  // same IP, different "MAC" (sourcePort)
          destinationIp: '255.255.255.255',
          sourcePort: 9999,
          destinationPort: 0,
          protocol: ProtocolType.arp,
        ),
      ];

      final alerts = engine.analyze(arpPkts, idsDevice);
      final arpAlert = alerts.firstWhere(
          (a) => a.attackType == AttackType.arpSpoofing,
          orElse: () => throw Exception('No ARP spoofing alert'));
      expect(arpAlert.blocked, isTrue);
    });

    test('does NOT trigger ARP alert for single unique MAC per IP', () {
      final arpPkts = [
        const Packet(
          id: 'arp-ok-1',
          sourceIp: '10.0.0.1',
          destinationIp: '255.255.255.255',
          sourcePort: 1001, // same MAC discriminator
          destinationPort: 0,
          protocol: ProtocolType.arp,
        ),
        const Packet(
          id: 'arp-ok-2',
          sourceIp: '10.0.0.1',
          destinationIp: '255.255.255.255',
          sourcePort: 1001, // same discriminator → single MAC
          destinationPort: 0,
          protocol: ProtocolType.arp,
        ),
      ];

      final alerts = engine.analyze(arpPkts, idsDevice);
      final arpAlerts =
          alerts.where((a) => a.attackType == AttackType.arpSpoofing);
      expect(arpAlerts, isEmpty);
    });
  });
}
