// lib/simulation/dhcp_service.dart
import 'dart:developer';
import '../models/device.dart';
import '../models/topology.dart';

/// Assigns IP addresses to endpoint devices that have no configured IP (0.0.0.0).
class DhcpService {
  static const _endpointTypes = {
    DeviceType.pc, DeviceType.laptop, DeviceType.server,
    DeviceType.iotDevice, DeviceType.wirelessAP,
  };

  /// Returns a map of deviceId → assigned IP.
  /// Detects an existing subnet from any configured interface;
  /// falls back to 192.168.1.0/24.
  static Map<String, String> assignIps(Topology topology) {
    final assignments = <String, String>{};
    String subnetBase = '192.168.1';

    // Derive subnet from first configured non-zero interface.
    outer:
    for (final d in topology.devices) {
      for (final i in d.interfaces) {
        if (i.ip == '0.0.0.0') continue;
        final parts = i.ip.split('.');
        if (parts.length == 4) {
          subnetBase = '${parts[0]}.${parts[1]}.${parts[2]}';
          break outer;
        }
      }
    }

    int host = 100;
    for (final d in topology.devices) {
      if (!_endpointTypes.contains(d.type)) continue;
      if (d.interfaces.any((i) => i.ip != '0.0.0.0')) continue;
      final ip = '$subnetBase.${host++}';
      assignments[d.id] = ip;
      log('DHCP: ${d.name} (${d.id}) ← $ip', name: 'DHCP');
    }
    log('DHCP: assigned ${assignments.length} addresses', name: 'DHCP');
    return assignments;
  }
}
