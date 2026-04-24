// lib/routing/bgp_engine.dart
import 'dart:developer';
import '../models/device.dart';
import '../models/network_interface.dart';
import '../models/topology.dart';
import 'rib.dart';

/// BGP configuration per device.
class BgpConfig {
  final int asNumber;
  final List<String> neighborIps; // peer IP addresses
  final int localPref;            // higher = preferred (default 100)

  const BgpConfig({
    required this.asNumber,
    this.neighborIps = const [],
    this.localPref = 100,
  });
}

/// Simplified BGP simulation.
///
/// - eBGP (different AS): adminDistance = 20, propagates default routes
///   from internetCloud nodes to adjacent border routers.
/// - iBGP (same AS): adminDistance = 200, distributes learned routes
///   within the same AS.
/// - Route selection: higher localPref → shorter AS path.
class BgpEngine {
  final Map<String, BgpConfig> _configs;

  BgpEngine({Map<String, BgpConfig>? configs})
      : _configs = configs ?? const {};

  /// Auto-detects BGP config from topology.
  /// internetCloud nodes each receive a unique external AS (64512+).
  /// Adjacent routers are assigned internal AS 65001.
  factory BgpEngine.autoDetect(Topology topology) {
    final cfgs = <String, BgpConfig>{};
    int extAs = 64512;
    for (final d in topology.devices) {
      if (d.type == DeviceType.internetCloud) {
        cfgs[d.id] = BgpConfig(asNumber: extAs++);
      }
    }
    for (final link in topology.links) {
      if (!link.isActive) continue;
      for (final pair in [(link.deviceAId, link.deviceBId),
                          (link.deviceBId, link.deviceAId)]) {
        final (a, b) = pair;
        if (cfgs.containsKey(a) && !cfgs.containsKey(b)) {
          final dev = topology.devices.where((d) => d.id == b).firstOrNull;
          if (dev != null && _isBgpCapable(dev.type)) {
            cfgs[b] = const BgpConfig(asNumber: 65001);
          }
        }
      }
    }
    return BgpEngine(configs: cfgs);
  }

  static bool _isBgpCapable(DeviceType t) => {
    DeviceType.router, DeviceType.l3Switch,
    DeviceType.vpnGateway, DeviceType.natGateway,
  }.contains(t);

  /// Computes BGP routes for all configured devices.
  /// Returns deviceId → list of RIBEntries.
  Map<String, List<RIBEntry>> computeRoutes(Topology topology) {
    if (_configs.isEmpty) {
      log('BGP: no configs — skipping', name: 'BgpEngine');
      return {};
    }

    final result = <String, List<RIBEntry>>{};

    for (final entry in _configs.entries) {
      final deviceId = entry.key;
      final myConfig = entry.value;
      final device = topology.devices.where((d) => d.id == deviceId).firstOrNull;
      if (device == null) continue;

      final ribs = <RIBEntry>[];

      // Scan links for BGP-peered neighbors.
      for (final link in topology.links) {
        if (!link.isActive) continue;
        final peerId = link.deviceAId == deviceId
            ? link.deviceBId
            : link.deviceBId == deviceId
                ? link.deviceAId
                : null;
        if (peerId == null) continue;
        final peerConfig = _configs[peerId];
        if (peerConfig == null) continue;

        final peerDev = topology.devices
            .where((d) => d.id == peerId).firstOrNull;
        if (peerDev == null) continue;

        final isEbgp = myConfig.asNumber != peerConfig.asNumber;
        final ad = isEbgp ? 20 : 200;

        // eBGP: internetCloud advertises default route (0.0.0.0/0).
        if (isEbgp && peerDev.type == DeviceType.internetCloud) {
          final cloudIp = peerDev.interfaces
              .where((i) => i.ip != '0.0.0.0' && i.status == InterfaceStatus.up)
              .firstOrNull?.ip;
          if (cloudIp != null) {
            ribs.add(RIBEntry(
              prefix: '0.0.0.0', mask: 0,
              nextHop: cloudIp,
              metric: peerConfig.localPref, // AS path length proxy
              protocol: RoutingProtocol.bgp,
              adminDistance: ad,
            ));
          }
        }

        // Share peer's interfaces as reachable prefixes.
        for (final iface in peerDev.interfaces) {
          if (iface.ip == '0.0.0.0' || iface.status == InterfaceStatus.down) continue;
          final nexthopIp = peerDev.interfaces
              .where((i) => i.status == InterfaceStatus.up && i.ip != '0.0.0.0')
              .firstOrNull?.ip ?? iface.ip;
          ribs.add(RIBEntry(
            prefix: iface.ip, mask: iface.subnet,
            nextHop: nexthopIp,
            metric: isEbgp ? 1 : peerConfig.localPref,
            protocol: RoutingProtocol.bgp,
            adminDistance: ad,
          ));
        }
      }

      // Sort: higher localPref first, then shorter metric (AS path).
      ribs.sort((a, b) {
        final lp = b.metric.compareTo(a.metric); // higher metric = higher localPref
        return lp != 0 ? lp : a.adminDistance.compareTo(b.adminDistance);
      });
      result[deviceId] = ribs;
    }

    final total = result.values.fold(0, (s, l) => s + l.length);
    log('BGP: computed $total route entries across ${_configs.length} devices',
        name: 'BgpEngine');
    return result;
  }
}
