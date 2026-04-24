// lib/simulation/rip_engine.dart
import 'dart:developer';
import '../models/device.dart';
import '../models/network_interface.dart';
import '../models/topology.dart';
import '../routing/dijkstra.dart';
import '../routing/fib.dart';
import 'packet_processor.dart';

/// Installs RIP routes (AD=120) for routers/L3 switches.
/// Only installs when no better route (OSPF AD=110) already exists.
class RipEngine {
  static const _ripTypes = {DeviceType.router, DeviceType.l3Switch};

  static void install(Topology topology, PacketProcessor processor) {
    final routers = topology.devices
        .where((d) => _ripTypes.contains(d.type))
        .toList();
    int count = 0;

    for (final src in routers) {
      for (final dst in topology.devices) {
        if (src.id == dst.id) continue;
        for (final iface in dst.interfaces) {
          if (iface.ip == '0.0.0.0' || iface.status == InterfaceStatus.down) continue;
          // Respect OSPF's lower AD — skip if route exists.
          if (processor.contextFor(src.id).fib.lookup(iface.ip) != null) continue;

          final path = Dijkstra.findPath(src.id, iface.ip, topology);
          if (path.length < 2) continue;

          final nextDev = topology.devices
              .where((d) => d.id == path[1]).firstOrNull;
          if (nextDev == null) continue;

          final nextIp = nextDev.interfaces
              .where((i) => i.status == InterfaceStatus.up && i.ip != '0.0.0.0')
              .firstOrNull?.ip ?? iface.ip;

          processor.contextFor(src.id).fib.install(FIBEntry(
            prefix: iface.ip, mask: iface.subnet,
            nextHopIp: nextIp,
            outputInterface: src.interfaces.isNotEmpty
                ? src.interfaces.first.name : 'eth0',
          ));
          count++;
        }
      }
    }
    log('RIP: installed $count routes', name: 'RIP');
  }
}
