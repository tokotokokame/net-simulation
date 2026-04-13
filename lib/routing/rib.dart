// lib/routing/rib.dart
import 'dart:developer';

enum RoutingProtocol { connected, static, rip, ospf, bgp }

const _defaultAdminDistance = {
  RoutingProtocol.connected: 0,
  RoutingProtocol.static: 1,
  RoutingProtocol.bgp: 20,
  RoutingProtocol.ospf: 110,
  RoutingProtocol.rip: 120,
};

class RIBEntry {
  final String prefix; // e.g. "192.168.1.0"
  final int mask; // prefix length, e.g. 24
  final String nextHop; // IP of next hop, "0.0.0.0" for connected
  final int metric;
  final RoutingProtocol protocol;
  final int adminDistance;

  RIBEntry({
    required this.prefix,
    required this.mask,
    required this.nextHop,
    this.metric = 0,
    required this.protocol,
    int? adminDistance,
  }) : adminDistance = adminDistance ?? _defaultAdminDistance[protocol]!;

  Map<String, dynamic> toJson() => {
        'prefix': prefix,
        'mask': mask,
        'nextHop': nextHop,
        'metric': metric,
        'protocol': protocol.name,
        'adminDistance': adminDistance,
      };

  factory RIBEntry.fromJson(Map<String, dynamic> json) => RIBEntry(
        prefix: json['prefix'] as String,
        mask: json['mask'] as int,
        nextHop: json['nextHop'] as String,
        metric: json['metric'] as int? ?? 0,
        protocol: RoutingProtocol.values
            .firstWhere((e) => e.name == json['protocol']),
        adminDistance: json['adminDistance'] as int?,
      );

  @override
  String toString() =>
      'RIBEntry($prefix/$mask via $nextHop, ${protocol.name}, AD=$adminDistance)';
}

int _ipToInt(String ip) {
  final p = ip.split('.').map(int.parse).toList();
  return (p[0] << 24) | (p[1] << 16) | (p[2] << 8) | p[3];
}

bool _matchesPrefix(String ip, String prefix, int maskBits) {
  if (maskBits == 0) return true;
  final mask = maskBits >= 32
      ? 0xFFFFFFFF
      : ~(0xFFFFFFFF >>> maskBits) & 0xFFFFFFFF;
  return (_ipToInt(ip) & mask) == (_ipToInt(prefix) & mask);
}

class RIB {
  final List<RIBEntry> _routes = [];

  List<RIBEntry> get routes => List.unmodifiable(_routes);

  void addRoute(RIBEntry entry) {
    _routes.add(entry);
    log('RIB: added $entry', name: 'RIB');
  }

  void removeRoute(String prefix) {
    final before = _routes.length;
    _routes.removeWhere((r) => r.prefix == prefix);
    if (_routes.length < before) {
      log('RIB: removed route $prefix', name: 'RIB');
    }
  }

  /// Returns the best matching route using longest-prefix match,
  /// then lowest adminDistance, then lowest metric.
  RIBEntry? getBestRoute(String destinationIp) {
    final matches =
        _routes.where((r) => _matchesPrefix(destinationIp, r.prefix, r.mask)).toList();
    if (matches.isEmpty) return null;

    final maxMask = matches.fold(0, (m, r) => r.mask > m ? r.mask : m);
    final longestMatches = matches.where((r) => r.mask == maxMask).toList()
      ..sort((a, b) {
        final ad = a.adminDistance.compareTo(b.adminDistance);
        return ad != 0 ? ad : a.metric.compareTo(b.metric);
      });
    return longestMatches.first;
  }

  List<Map<String, dynamic>> toJson() =>
      _routes.map((r) => r.toJson()).toList();

  void loadFromJson(List<dynamic> json) {
    _routes.clear();
    for (final e in json) {
      _routes.add(RIBEntry.fromJson(e as Map<String, dynamic>));
    }
  }
}
