// lib/simulation/vlan_engine.dart
import 'dart:developer';
import '../models/device.dart';
import '../models/network_interface.dart';
import '../models/packet.dart';
import '../models/topology.dart';

/// Applies 802.1Q VLAN filtering at each hop.
class VlanEngine {
  /// Returns the packet (possibly retagged) if VLAN policy permits it,
  /// or null to drop.
  static Packet? process(Packet packet, Device device, Topology topology) {
    final vlanIfaces = device.interfaces
        .where((i) => i.vlan != null)
        .toList();

    // Device with no VLAN config: pass through.
    if (vlanIfaces.isEmpty) return packet;

    // Untagged packet on a device that has VLAN interfaces.
    if (packet.vlanTag == null) {
      final accessPorts = vlanIfaces
          .where((i) => i.vlanMode == VlanMode.access)
          .toList();
      if (accessPorts.isNotEmpty) {
        // Tag with the access-port VLAN.
        return packet.copyWith(vlanTag: accessPorts.first.vlan);
      }
      log('VLAN drop: untagged pkt on trunk-only ${device.name}', name: 'VLAN');
      return null;
    }

    // Tagged packet: check if any interface allows this VLAN.
    final allowed = vlanIfaces.any((i) => i.vlan == packet.vlanTag);
    if (!allowed) {
      log('VLAN drop: tag ${packet.vlanTag} not in ${device.name}', name: 'VLAN');
      return null;
    }
    return packet;
  }
}
