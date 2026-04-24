// lib/ui/screens/topology_state.dart
import 'dart:developer';
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
    log('addDevice: ${d.id} ${d.name}', name: 'Topology');
    state = state.copyWith(devices: [...state.devices, d]);
  }

  void updateDevice(Device d) {
    state = state.copyWith(
      devices: state.devices.map((e) => e.id == d.id ? d : e).toList(),
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
  }
}

final topologyProvider =
    StateNotifierProvider<TopologyNotifier, Topology>((_) => TopologyNotifier());

final selectedDeviceIdProvider = StateProvider<String?>((ref) => null);
