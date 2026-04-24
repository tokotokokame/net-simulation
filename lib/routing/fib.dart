// lib/routing/fib.dart
import 'dart:developer';
import 'rib.dart';
import '../network/arp_table.dart';

class FIBEntry {
  final String prefix;
  final int mask;
  final String nextHopIp;
  final String outputInterface;
  final String? resolvedMac;

  const FIBEntry({
    required this.prefix,
    required this.mask,
    required this.nextHopIp,
    required this.outputInterface,
    this.resolvedMac,
  });

  Map<String, dynamic> toJson() => {
        'prefix': prefix,
        'mask': mask,
        'nextHopIp': nextHopIp,
        'outputInterface': outputInterface,
        'resolvedMac': resolvedMac,
      };

  factory FIBEntry.fromJson(Map<String, dynamic> json) => FIBEntry(
        prefix: json['prefix'] as String,
        mask: json['mask'] as int,
        nextHopIp: json['nextHopIp'] as String,
        outputInterface: json['outputInterface'] as String,
        resolvedMac: json['resolvedMac'] as String?,
      );

  @override
  String toString() =>
      'FIBEntry($prefix/$mask via $nextHopIp on $outputInterface, MAC=$resolvedMac)';
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

class FIB {
  final List<FIBEntry> _entries = [];

  List<FIBEntry> get entries => List.unmodifiable(_entries);

  /// Rebuilds FIB from [rib] best routes, resolving MACs via [arpTable].
  void buildFrom(RIB rib, ARPTable arpTable) {
    _entries.clear();

    // Collect unique prefixes then take best route per prefix.
    final seen = <String>{};
    for (final route in rib.routes) {
      final key = '${route.prefix}/${route.mask}';
      if (seen.contains(key)) continue;
      seen.add(key);

      final best = rib.getBestRoute(route.prefix);
      if (best == null) continue;

      final mac = arpTable.lookup(best.nextHop);
      final entry = FIBEntry(
        prefix: best.prefix,
        mask: best.mask,
        nextHopIp: best.nextHop,
        outputInterface: 'eth0', // resolved by packet processor in Phase 3
        resolvedMac: mac,
      );
      _entries.add(entry);
      log('FIB: installed $entry', name: 'FIB');
    }
  }

  /// Directly installs a pre-computed entry (e.g., from OSPF/RIP/BGP engines).
  void install(FIBEntry entry) {
    _entries.add(entry);
    log('FIB: installed (dynamic) $entry', name: 'FIB');
  }

  /// Returns best FIB entry (longest prefix match).
  FIBEntry? lookup(String destinationIp) {
    final matches = _entries
        .where((e) => _matchesPrefix(destinationIp, e.prefix, e.mask))
        .toList();
    if (matches.isEmpty) return null;
    final maxMask = matches.fold(0, (m, e) => e.mask > m ? e.mask : m);
    return matches.firstWhere((e) => e.mask == maxMask);
  }

  List<Map<String, dynamic>> toJson() =>
      _entries.map((e) => e.toJson()).toList();

  void loadFromJson(List<dynamic> json) {
    _entries.clear();
    for (final e in json) {
      _entries.add(FIBEntry.fromJson(e as Map<String, dynamic>));
    }
  }
}
