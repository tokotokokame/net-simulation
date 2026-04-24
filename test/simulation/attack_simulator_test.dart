// test/simulation/attack_simulator_test.dart
//
// ⚠️ EDUCATIONAL PURPOSE ONLY — virtual network simulation tests only
import 'package:flutter_test/flutter_test.dart';
import 'package:net_simulation/models/attack_packet.dart';
import 'package:net_simulation/models/device.dart';
import 'package:net_simulation/models/network_interface.dart';
import 'package:net_simulation/models/topology.dart';
import 'package:net_simulation/simulation/attack_simulator.dart';

// ── Topology fixtures ────────────────────────────────────────────────────────

const _eth = NetworkInterface(
  name: 'eth0', ip: '10.0.0.1', subnet: 24, mac: 'AA:BB:CC:DD:EE:01');

const _ethTarget = NetworkInterface(
  name: 'eth0', ip: '10.0.0.2', subnet: 24, mac: 'AA:BB:CC:DD:EE:02');

const _ethGw = NetworkInterface(
  name: 'eth0', ip: '10.0.0.254', subnet: 24, mac: 'AA:BB:CC:DD:EE:FE');

const _attacker = Device(
  id: 'atk', type: DeviceType.pc, name: 'Attacker',
  x: 0, y: 0, interfaces: [_eth]);

const _serverDevice = Device(
  id: 'srv', type: DeviceType.server, name: 'Server',
  x: 100, y: 0, interfaces: [_ethTarget]);

const _pcTarget = Device(
  id: 'tgt', type: DeviceType.pc, name: 'Target',
  x: 100, y: 0, interfaces: [_ethTarget]);

const _idsDevice = Device(
  id: 'ids1', type: DeviceType.ids, name: 'IDS-1',
  x: 50, y: 50, interfaces: [_eth]);

const _firewallDevice = Device(
  id: 'fw1', type: DeviceType.firewall, name: 'Firewall',
  x: 50, y: 0, interfaces: [_eth]);

const _gatewayDevice = Device(
  id: 'gw', type: DeviceType.router, name: 'Gateway',
  x: 50, y: 100, interfaces: [_ethGw]);

final _kNow = DateTime(2026, 1, 1);

/// Minimal topology: attacker + target only.
Topology _plainTopo({DeviceType targetType = DeviceType.pc}) => Topology(
  id: 't1', name: 'test',
  devices: [
    _attacker,
    targetType == DeviceType.server ? _serverDevice : _pcTarget,
  ],
  links: const [],
  createdAt: _kNow, updatedAt: _kNow,
);

/// Topology with an IDS device on the path.
Topology _topoWithIds() => Topology(
  id: 't2', name: 'test-ids',
  devices: [_attacker, _pcTarget, _idsDevice],
  links: const [],
  createdAt: _kNow, updatedAt: _kNow,
);

/// Topology with a firewall device.
Topology _topoWithFw() => Topology(
  id: 't3', name: 'test-fw',
  devices: [_attacker, _serverDevice, _firewallDevice],
  links: const [],
  createdAt: _kNow, updatedAt: _kNow,
);

/// Topology with both IDS and firewall.
Topology _topoFull() => Topology(
  id: 't4', name: 'test-full',
  devices: [_attacker, _pcTarget, _idsDevice, _firewallDevice, _gatewayDevice],
  links: const [],
  createdAt: _kNow, updatedAt: _kNow,
);

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  final sim = AttackSimulator();

  // ── 1. SYN flood — packet count matches intensity ────────────────────────

  group('SYN flood (simulateDoS)', () {
    test('low intensity generates exactly 10 packets in 1 second', () async {
      final result = await sim.simulateDoS(
        attackerDeviceId: 'atk',
        targetDeviceId:   'tgt',
        type:      AttackType.dosSynFlood,
        intensity: AttackIntensity.low, // 10 pkt/s
        topology:  _plainTopo(),
        duration:  const Duration(seconds: 1),
      ).first;

      expect(result.packetsGenerated, equals(10));
      expect(result.attackType, equals(AttackType.dosSynFlood));
    });

    test('medium intensity generates exactly 100 packets', () async {
      final result = await sim.simulateDoS(
        attackerDeviceId: 'atk',
        targetDeviceId:   'tgt',
        type:      AttackType.dosSynFlood,
        intensity: AttackIntensity.medium, // 100 pkt/s
        topology:  _plainTopo(),
        duration:  const Duration(seconds: 1),
      ).first;

      expect(result.packetsGenerated, equals(100));
    });

    test('high intensity overloads target queue (>100 pkt/s)', () async {
      final result = await sim.simulateDoS(
        attackerDeviceId: 'atk',
        targetDeviceId:   'tgt',
        type:      AttackType.dosSynFlood,
        intensity: AttackIntensity.high, // 1000 pkt/s > queue max 100
        topology:  _plainTopo(),
        duration:  const Duration(seconds: 1),
      ).first;

      expect(result.targetOverloaded, isTrue);
    });

    test('UDP flood produces correct packet count', () async {
      final result = await sim.simulateDoS(
        attackerDeviceId: 'atk',
        targetDeviceId:   'tgt',
        type:      AttackType.dosUdpFlood,
        intensity: AttackIntensity.low,
        topology:  _plainTopo(),
        duration:  const Duration(seconds: 1),
      ).first;

      expect(result.packetsGenerated, equals(10));
      expect(result.attackType, equals(AttackType.dosUdpFlood));
    });
  });

  // ── 2. Port scan — open ports discovered on server ───────────────────────

  group('Port scan (simulatePortScan)', () {
    test('TCP scan on server device discovers open ports 22/80/443', () async {
      final result = await sim.simulatePortScan(
        scannerDeviceId: 'atk',
        targetDeviceId:  'srv',
        scanType:    AttackType.portScanTcp,
        targetPorts: const [21, 22, 80, 443, 8080],
        topology:    _plainTopo(targetType: DeviceType.server),
      );

      expect(result.openPorts, containsAll([22, 80, 443]));
      expect(result.attackType, equals(AttackType.portScanTcp));
    });

    test('scan on non-server device finds no open ports', () async {
      final result = await sim.simulatePortScan(
        scannerDeviceId: 'atk',
        targetDeviceId:  'tgt',
        scanType:    AttackType.portScanTcp,
        targetPorts: const [22, 80, 443],
        topology:    _plainTopo(),
      );

      expect(result.openPorts, isEmpty);
    });

    test('generates one packet per scanned port', () async {
      const ports = [80, 443, 22, 25, 53];
      final result = await sim.simulatePortScan(
        scannerDeviceId: 'atk',
        targetDeviceId:  'srv',
        scanType:    AttackType.portScanTcp,
        targetPorts: ports,
        topology:    _plainTopo(targetType: DeviceType.server),
      );

      expect(result.packetsGenerated, equals(ports.length));
    });
  });

  // ── 3. IDS detection — alert generated above threshold ──────────────────

  group('IDS detection', () {
    test('IDS detects SYN flood at medium intensity (100 >= 50 threshold)', () async {
      final result = await sim.simulateDoS(
        attackerDeviceId: 'atk',
        targetDeviceId:   'tgt',
        type:      AttackType.dosSynFlood,
        intensity: AttackIntensity.medium, // 100 pkt/s ≥ IDS threshold 50
        topology:  _topoWithIds(),
        duration:  const Duration(seconds: 1),
      ).first;

      expect(result.detectedBy, contains('ids1'));
    });

    test('IDS does NOT alert at low intensity (10 < 50 threshold)', () async {
      final result = await sim.simulateDoS(
        attackerDeviceId: 'atk',
        targetDeviceId:   'tgt',
        type:      AttackType.dosSynFlood,
        intensity: AttackIntensity.low, // 10 pkt/s < IDS threshold 50
        topology:  _topoWithIds(),
        duration:  const Duration(seconds: 1),
      ).first;

      expect(result.detectedBy, isEmpty);
    });

    test('no IDS in topology → detectedBy is empty', () async {
      final result = await sim.simulateDoS(
        attackerDeviceId: 'atk',
        targetDeviceId:   'tgt',
        type:      AttackType.dosSynFlood,
        intensity: AttackIntensity.high,
        topology:  _plainTopo(), // no IDS device
        duration:  const Duration(seconds: 1),
      ).first;

      expect(result.detectedBy, isEmpty);
    });
  });

  // ── 4. ARP spoofing ──────────────────────────────────────────────────────

  group('ARP spoofing (simulateArpSpoofing)', () {
    test('emits results with arpSpoofing attackType', () async {
      final result = await sim.simulateArpSpoofing(
        attackerDeviceId: 'atk',
        victimDeviceId:   'tgt',
        gatewayDeviceId:  'gw',
        topology: _topoFull(),
      ).first;

      expect(result.attackType, equals(AttackType.arpSpoofing));
      expect(result.targetId,   equals('tgt'));
    });

    test('IDS detects ARP spoofing when IDS present', () async {
      final result = await sim.simulateArpSpoofing(
        attackerDeviceId: 'atk',
        victimDeviceId:   'tgt',
        gatewayDeviceId:  'gw',
        topology: _topoFull(),
      ).first;

      expect(result.detectedBy, contains('ids1'));
      expect(result.packetsBlocked, greaterThan(0));
    });

    test('no IDS → ARP spoofing goes undetected', () async {
      final result = await sim.simulateArpSpoofing(
        attackerDeviceId: 'atk',
        victimDeviceId:   'tgt',
        gatewayDeviceId:  'tgt', // no separate gateway needed
        topology: _plainTopo(),  // no IDS
      ).first;

      expect(result.detectedBy, isEmpty);
      expect(result.packetsBlocked, equals(0));
    });
  });

  // ── 5. Firewall blocking ─────────────────────────────────────────────────

  group('Firewall blocking', () {
    test('firewall blocks non-stealth TCP scan (all packets blocked)', () async {
      final result = await sim.simulatePortScan(
        scannerDeviceId: 'atk',
        targetDeviceId:  'srv',
        scanType:    AttackType.portScanTcp,  // non-stealth → blocked
        targetPorts: const [22, 80, 443],
        topology:    _topoWithFw(),
      );

      expect(result.packetsBlocked, equals(result.packetsGenerated));
      expect(result.openPorts, isEmpty);
    });

    test('stealth scan bypasses firewall and finds open ports', () async {
      final result = await sim.simulatePortScan(
        scannerDeviceId: 'atk',
        targetDeviceId:  'srv',
        scanType:    AttackType.portScanStealth, // FIN scan bypasses FW
        targetPorts: const [22, 80, 443],
        topology:    _topoWithFw(),
      );

      expect(result.packetsBlocked, equals(0));
      expect(result.openPorts, containsAll([22, 80, 443]));
    });

    test('firewall reduces DoS through-put (some packets blocked)', () async {
      final result = await sim.simulateDoS(
        attackerDeviceId: 'atk',
        targetDeviceId:   'tgt',
        type:      AttackType.dosSynFlood,
        intensity: AttackIntensity.medium,
        topology:  _topoFull(), // has firewall
        duration:  const Duration(seconds: 1),
      ).first;

      // With FW present, some (~30%) are blocked, fewer pass through.
      expect(result.packetsBlocked, greaterThan(0));
      expect(result.packetsThrough, lessThan(result.packetsGenerated));
    });
  });

  // ── 6. AttackResult helpers ──────────────────────────────────────────────

  group('AttackResult.packetsThrough', () {
    test('packetsThrough = generated - blocked', () async {
      final result = await sim.simulatePortScan(
        scannerDeviceId: 'atk',
        targetDeviceId:  'srv',
        scanType:    AttackType.portScanTcp,
        targetPorts: const [80, 443],
        topology:    _topoWithFw(),
      );

      expect(result.packetsThrough,
          equals(result.packetsGenerated - result.packetsBlocked));
    });
  });
}
