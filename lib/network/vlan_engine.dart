// lib/network/vlan_engine.dart
import 'dart:developer';
import '../models/network_interface.dart';
import '../models/packet.dart';

/// 802.1Q VLAN processing engine.
class VlanEngine {
  const VlanEngine();

  /// Processes an ingress frame on [ingressPort].
  ///
  /// - Trunk port: frame passes unchanged.
  /// - Access port + untagged frame: tag with port VLAN.
  /// - Access port + matching tag: untag (strip for internal processing).
  /// - Access port + mismatched tag: drop (returns null).
  /// - No VLAN config on port: pass through.
  Packet? processFrame(Packet packet, NetworkInterface ingressPort) {
    // No VLAN config on port → pass through.
    if (ingressPort.vlan == null && ingressPort.vlanMode == null) return packet;

    // Trunk port → pass all VLANs.
    if (ingressPort.vlanMode == VlanMode.trunk) {
      log('VLAN trunk: pass tag=${packet.vlanTag} on ${ingressPort.name}',
          name: 'VlanEngine');
      return packet;
    }

    // Access port logic.
    final portVlan = ingressPort.vlan;
    if (portVlan == null) return packet;

    if (packet.vlanTag == null) {
      // Untagged ingress → push access VLAN.
      log('VLAN tag: untagged → vlan=$portVlan on ${ingressPort.name}',
          name: 'VlanEngine');
      return tag802_1Q(packet, portVlan);
    }

    if (!isAllowed(packet.vlanTag!, ingressPort)) {
      log('VLAN block: tag=${packet.vlanTag} ≠ portVlan=$portVlan '
          'on ${ingressPort.name}', name: 'VlanEngine');
      return null;
    }

    // Matching tag on access port → strip for internal forwarding.
    log('VLAN untag: vlan=${packet.vlanTag} on ${ingressPort.name}',
        name: 'VlanEngine');
    return untag(packet);
  }

  /// Returns true if [vlanId] is allowed on [port].
  /// Trunk ports allow every VLAN. Access ports allow only their configured VLAN.
  bool isAllowed(int vlanId, NetworkInterface port) {
    if (port.vlanMode == VlanMode.trunk) return true;
    return port.vlan == vlanId;
  }

  /// Returns a copy of [packet] with [vlanId] set as the 802.1Q tag.
  Packet tag802_1Q(Packet packet, int vlanId) =>
      packet.copyWith(vlanTag: vlanId);

  /// Returns a copy of [packet] with the VLAN tag removed (set to null).
  Packet untag(Packet packet) => Packet(
        id: packet.id,
        sourceIp: packet.sourceIp,
        destinationIp: packet.destinationIp,
        sourcePort: packet.sourcePort,
        destinationPort: packet.destinationPort,
        protocol: packet.protocol,
        size: packet.size,
        ttl: packet.ttl,
        tcpFlags: packet.tcpFlags,
        status: packet.status,
        mplsLabel: packet.mplsLabel,
        droppedReason: packet.droppedReason,
        // vlanTag intentionally omitted → null
      );
}
