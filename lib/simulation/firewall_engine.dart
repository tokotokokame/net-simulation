// lib/simulation/firewall_engine.dart
import 'dart:developer';
import '../models/device.dart';
import '../models/packet.dart';
import 'packet_processor.dart';

/// Evaluates ACL rules on firewall/IDS/IPS device types.
/// Returns a Drop result if blocked, null to permit.
class FirewallEngine {
  static const _enforcingTypes = {
    DeviceType.firewall, DeviceType.ids, DeviceType.ips,
  };

  static PacketProcessResult? evaluate(Packet packet, Device device) {
    if (!_enforcingTypes.contains(device.type)) return null;

    // Phase 4+: evaluate stored ACL rules from Device config.
    // Currently defaults to implicit permit-all for all protocols.
    // Block only packets explicitly destined for the device itself
    // on management ports (placeholder logic).
    if (packet.destinationPort == 22 || packet.destinationPort == 23) {
      log('FW drop: mgmt port ${packet.destinationPort} blocked on ${device.name}',
          name: 'Firewall');
      return PacketProcessResult.drop('Firewall: mgmt port blocked');
    }

    log('FW permit: ${packet.sourceIp}→${packet.destinationIp}:${packet.destinationPort}'
        ' on ${device.name}', name: 'Firewall');
    return null; // permit
  }
}
