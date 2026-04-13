// test/integration/simulation_integration_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:net_simulation_v4/auth/demo_timer_service.dart';
import 'package:net_simulation_v4/models/device.dart';
import 'package:net_simulation_v4/models/link.dart';
import 'package:net_simulation_v4/models/network_interface.dart';
import 'package:net_simulation_v4/models/packet.dart';
import 'package:net_simulation_v4/models/topology.dart';
import 'package:net_simulation_v4/simulation/simulation_engine.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Device _dev(String id, {double x = 0, double y = 0}) => Device(
      id: id, type: DeviceType.router, name: id, x: x, y: y,
      interfaces: const [NetworkInterface(name: 'eth0', ip: '10.0.0.1', subnet: 24, mac: 'AA:BB:CC:00:00:01')],
    );

Topology _topo(List<Device> devices, [List<Link> links = const []]) => Topology(
      id: 't1', name: 'Test Topology',
      devices: devices, links: links,
      createdAt: DateTime.now(), updatedAt: DateTime.now(),
    );

Packet _pkt(String id) => Packet(
      id: id, sourceIp: '10.0.0.1', destinationIp: '10.0.0.2',
      sourcePort: 1234, destinationPort: 80, protocol: ProtocolType.tcp,
    );

ProviderContainer _container({int limitSeconds = 3600}) => ProviderContainer(
      overrides: [
        demoTimerServiceProvider.overrideWith((_) => DemoTimerService(limitSeconds: limitSeconds)),
      ],
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── Test 1: Basic E2E flow ────────────────────────────────────────────────

  group('Simulation E2E flow', () {
    test('start → inject packets → stats increment', () async {
      final container = _container();
      addTearDown(container.dispose);

      final engine = container.read(simulationEngineProvider.notifier);
      engine.start(_topo([_dev('r1'), _dev('r2', x: 200)]));
      expect(container.read(simulationEngineProvider).simState, SimulationState.running);

      for (int i = 0; i < 5; i++) { engine.injectPacket(_pkt('p$i')); }
      await Future.delayed(const Duration(milliseconds: 250));

      final stats = container.read(simulationEngineProvider).stats;
      expect(stats.totalPackets, greaterThan(0));
      engine.stop();
      expect(container.read(simulationEngineProvider).simState, SimulationState.stopped);
    });
  });

  // ── Test 2: Demo timer expiry pauses simulation ───────────────────────────

  group('Demo timer expiry', () {
    test('simulation pauses when demo timer expires', () async {
      final container = _container(limitSeconds: 1);
      addTearDown(container.dispose);

      final engine = container.read(simulationEngineProvider.notifier);
      engine.start(_topo([_dev('r1')]));
      expect(container.read(simulationEngineProvider).simState, SimulationState.running);

      await Future.delayed(const Duration(milliseconds: 1500));

      expect(container.read(simulationEngineProvider).simState, SimulationState.paused);
    });
  });

  // ── Test 3: Device + Link + Simulation lifecycle ──────────────────────────

  group('Device + Link + Simulation flow', () {
    test('topology with two devices and a link starts correctly', () async {
      final container = _container();
      addTearDown(container.dispose);

      const link = Link(
        id: 'l1', deviceAId: 'a1', deviceBId: 'b1',
        interfaceAName: 'eth0', interfaceBName: 'eth0',
      );
      final topology = _topo([_dev('a1'), _dev('b1', x: 300)], [link]);

      expect(topology.devices.length, 2);
      expect(topology.links.length, 1);

      final engine = container.read(simulationEngineProvider.notifier);
      engine.start(topology);
      expect(container.read(simulationEngineProvider).simState, SimulationState.running);

      await Future.delayed(const Duration(milliseconds: 150));
      engine.stop();

      final state = container.read(simulationEngineProvider);
      expect(state.simState, SimulationState.stopped);
      expect(state.activePackets, isEmpty);
    });

    test('pause and resume: no new packets processed while paused', () async {
      final container = _container();
      addTearDown(container.dispose);

      final engine = container.read(simulationEngineProvider.notifier);
      engine.start(_topo([_dev('r1')]));
      for (int i = 0; i < 5; i++) { engine.injectPacket(_pkt('p$i')); }
      await Future.delayed(const Duration(milliseconds: 200));

      engine.pause();
      final statsBefore = container.read(simulationEngineProvider).stats.totalPackets;
      await Future.delayed(const Duration(milliseconds: 200));
      final statsAfter = container.read(simulationEngineProvider).stats.totalPackets;

      expect(statsAfter, equals(statsBefore));
      engine.stop();
    });

    test('stop resets activePackets to empty', () {
      final container = _container();
      addTearDown(container.dispose);

      final engine = container.read(simulationEngineProvider.notifier);
      engine.start(_topo([_dev('r1')]));
      engine.injectPacket(_pkt('x1'));
      engine.stop();

      expect(container.read(simulationEngineProvider).activePackets, isEmpty);
    });
  });
}
