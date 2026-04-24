// lib/simulation/ospf_engine.dart
import 'dart:developer';
import '../models/device.dart';
import '../models/network_interface.dart';
import '../models/topology.dart';
import '../routing/dijkstra.dart';
import '../routing/fib.dart';
import 'packet_processor.dart';

/// Computes OSPF routes for routing-capable devices using Dijkstra
/// and installs them into per-device FIBs via [PacketProcessor].
class OspfEngine {
  static const _routerTypes = {
    DeviceType.router, DeviceType.l3Switch,
    DeviceType.firewall, DeviceType.vpnGateway, DeviceType.natGateway,
  };

  static void install(Topology topology, PacketProcessor processor) {
    final routers = topology.devices
        .where((d) => _routerTypes.contains(d.type))
        .toList();
    int count = 0;

    for (final src in routers) {
      for (final dst in topology.devices) {
        if (src.id == dst.id) continue;
        for (final iface in dst.interfaces) {
          if (iface.ip == '0.0.0.0' || iface.status == InterfaceStatus.down) continue;
          // Skip if a better route is already in FIB.
          if (processor.contextFor(src.id).fib.lookup(iface.ip) != null) continue;

          final path = Dijkstra.findPath(src.id, iface.ip, topology);
          if (path.length < 2) continue;

          final nextDev = topology.devices
              .where((d) => d.id == path[1]).firstOrNull;
          if (nextDev == null) continue;

          final nextIp = nextDev.interfaces
              .where((i) => i.status == InterfaceStatus.up && i.ip != '0.0.0.0')
              .firstOrNull?.ip ?? iface.ip;
          final outIf = src.interfaces.isNotEmpty
              ? src.interfaces.first.name : 'eth0';

          processor.contextFor(src.id).fib.install(FIBEntry(
            prefix: iface.ip, mask: iface.subnet,
            nextHopIp: nextIp, outputInterface: outIf,
          ));
          count++;
        }
      }
      log('OSPF: routes installed for ${src.name}', name: 'OSPF');
    }
    log('OSPF: total $count entries', name: 'OSPF');
  }
}
