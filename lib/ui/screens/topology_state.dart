// lib/ui/screens/topology_state.dart
import 'dart:developer';
import 'dart:math' as math;
import 'dart:ui' show Offset;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/device.dart';
import '../../models/link.dart';
import '../../models/network_interface.dart';
import '../../models/topology.dart';

const _uuid = Uuid();

class TopologyNotifier extends StateNotifier<Topology> {
  TopologyNotifier()
      : super(Topology.empty(id: _uuid.v4(), name: 'New Topology'));

  void addDevice(Device d) {
    // Auto-generate a numbered name when the caller passes the raw enum name.
    final count = state.devices.where((e) => e.type == d.type).length + 1;
    final named = d.name == d.type.name
        ? d.copyWith(name: _defaultName(d.type, count))
        : d;
    log('addDevice: ${named.id} ${named.name}', name: 'Topology');
    state = state.copyWith(devices: [...state.devices, named]);
  }

  void updateDevice(Device d) {
    state = state.copyWith(
      devices: state.devices.map((e) => e.id == d.id ? d : e).toList(),
    );
  }

  /// Moves a device without logging — called every frame during drag.
  void crashDevice(String deviceId) {
    state = state.copyWith(
      devices: state.devices.map((d) => d.id == deviceId
          ? d.copyWith(
              interfaces: d.interfaces
                  .map((i) => i.copyWith(status: InterfaceStatus.down))
                  .toList())
          : d).toList(),
    );
    log('crashDevice: $deviceId', name: 'Topology');
  }

  void moveDevice(String deviceId, Offset pos) {
    state = state.copyWith(
      devices: state.devices.map((d) => d.id == deviceId
          ? d.copyWith(x: pos.dx, y: pos.dy)
          : d).toList(),
    );
  }

  void removeDevice(String id) {
    log('removeDevice: $id', name: 'Topology');
    state = state.copyWith(
      devices: state.devices.where((d) => d.id != id).toList(),
      links: state.links
          .where((l) => l.deviceAId != id && l.deviceBId != id)
          .toList(),
    );
  }

  void addLink(Link l) {
    log('addLink: ${l.id}', name: 'Topology');
    state = state.copyWith(links: [...state.links, l]);
  }

  void removeLink(String id) {
    log('removeLink: $id', name: 'Topology');
    state = state.copyWith(
      links: state.links.where((l) => l.id != id).toList(),
    );
  }

  void updateLink(Link updated) {
    log('updateLink: ${updated.id}', name: 'Topology');
    state = state.copyWith(
      links: state.links.map((l) => l.id == updated.id ? updated : l).toList(),
    );
  }

  void rename(String name) => state = state.copyWith(name: name);

  void load(Topology t) => state = t;

  void clear() {
    log('clear', name: 'Topology');
    state = Topology.empty(id: state.id, name: state.name);
  }

  void updateInterface(String deviceId, int index, NetworkInterface updated) {
    final device = state.devices.where((d) => d.id == deviceId).firstOrNull;
    if (device == null) return;
    final ifaces = List.of(device.interfaces);
    if (index < ifaces.length) { ifaces[index] = updated; } else { ifaces.add(updated); }
    updateDevice(device.copyWith(interfaces: ifaces));
    log('updateInterface: $deviceId[$index] ip=${updated.ip}/${updated.subnet} mac=${updated.mac}',
        name: 'Topology');
  }

  void removeInterface(String deviceId, int index) {
    final device = state.devices.where((d) => d.id == deviceId).firstOrNull;
    if (device == null || index >= device.interfaces.length) return;
    final ifaces = List.of(device.interfaces)..removeAt(index);
    updateDevice(device.copyWith(interfaces: ifaces));
    log('removeInterface: $deviceId[$index]', name: 'Topology');
  }

  static String _defaultName(DeviceType type, int count) {
    const names = {
      DeviceType.router:            'Router',
      DeviceType.l3Switch:          'L3SW',
      DeviceType.switch_:           'SW',
      DeviceType.hub:               'Hub',
      DeviceType.bridge:            'Bridge',
      DeviceType.pc:                'PC',
      DeviceType.laptop:            'Laptop',
      DeviceType.server:            'Server',
      DeviceType.iotDevice:         'IoT',
      DeviceType.wirelessAP:        'AP',
      DeviceType.firewall:          'FW',
      DeviceType.ids:               'IDS',
      DeviceType.ips:               'IPS',
      DeviceType.natGateway:        'NAT-GW',
      DeviceType.internetCloud:     'Internet',
      DeviceType.mplsCloud:         'MPLS',
      DeviceType.lteNetwork:        'LTE',
      DeviceType.fiveGNetwork:      '5G',
      DeviceType.vpnGateway:        'VPN-GW',
      DeviceType.sdnController:     'SDN-Ctrl',
      DeviceType.openFlowSwitch:    'OFS',
    };
    return '${names[type] ?? 'Device'}-$count';
  }

  static String generateMac() {
    final r = math.Random();
    return List.generate(6,
        (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');
  }
}

final topologyProvider =
    StateNotifierProvider<TopologyNotifier, Topology>((_) => TopologyNotifier());

final selectedDeviceIdProvider = StateProvider<String?>((ref) => null);
