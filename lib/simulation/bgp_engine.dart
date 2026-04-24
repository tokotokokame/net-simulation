// lib/simulation/bgp_engine.dart
import 'dart:developer';
import '../models/device.dart';
import '../models/network_interface.dart';
import '../models/topology.dart';
import '../routing/fib.dart';
import 'packet_processor.dart';

/// Installs a default route (0.0.0.0/0) on routers adjacent to
/// internetCloud nodes (BGP eBGP peer simulation).
class BgpEngine {
  static void install(Topology topology, PacketProcessor processor) {
    final cloudIds = topology.devices
        .where((d) => d.type == DeviceType.internetCloud)
        .map((d) => d.id)
        .toSet();
    if (cloudIds.isEmpty) {
      log('BGP: no internetCloud nodes', name: 'BGP');
      return;
    }

    int count = 0;
    for (final link in topology.links) {
      if (!link.isActive) continue;
      final String? routerId;
      final String? cloudId;
      if (cloudIds.contains(link.deviceBId)) {
        routerId = link.deviceAId; cloudId = link.deviceBId;
      } else if (cloudIds.contains(link.deviceAId)) {
        routerId = link.deviceBId; cloudId = link.deviceAId;
      } else {
        continue;
      }

      final cloud = topology.devices.where((d) => d.id == cloudId).firstOrNull;
      final router = topology.devices.where((d) => d.id == routerId).firstOrNull;
      if (cloud == null || router == null) continue;

      final cloudIp = cloud.interfaces
          .where((i) => i.ip != '0.0.0.0' && i.status == InterfaceStatus.up)
          .firstOrNull?.ip;
      if (cloudIp == null) continue;

      processor.contextFor(routerId).fib.install(FIBEntry(
        prefix: '0.0.0.0', mask: 0,
        nextHopIp: cloudIp,
        outputInterface: router.interfaces.isNotEmpty
            ? router.interfaces.first.name : 'eth0',
      ));
      log('BGP: default route on ${router.name} via $cloudIp', name: 'BGP');
      count++;
    }
    log('BGP: installed $count default routes', name: 'BGP');
  }
}
