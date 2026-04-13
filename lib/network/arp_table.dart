// lib/network/arp_table.dart
import 'dart:developer';

class ARPEntry {
  final String ipAddress;
  final String macAddress;
  final String interfaceName;
  final DateTime expiry;

  const ARPEntry({
    required this.ipAddress,
    required this.macAddress,
    required this.interfaceName,
    required this.expiry,
  });

  bool get isExpired => DateTime.now().isAfter(expiry);

  Map<String, dynamic> toJson() => {
        'ipAddress': ipAddress,
        'macAddress': macAddress,
        'interfaceName': interfaceName,
        'expiry': expiry.toIso8601String(),
      };

  factory ARPEntry.fromJson(Map<String, dynamic> json) => ARPEntry(
        ipAddress: json['ipAddress'] as String,
        macAddress: json['macAddress'] as String,
        interfaceName: json['interfaceName'] as String,
        expiry: DateTime.parse(json['expiry'] as String),
      );

  @override
  String toString() => 'ARPEntry($ipAddress → $macAddress on $interfaceName)';
}

class ARPTable {
  final List<ARPEntry> _entries = [];

  List<ARPEntry> get entries => List.unmodifiable(_entries);

  /// Returns MAC address for [ip], or null if not found / expired.
  String? lookup(String ip) {
    final entry = _entries.where((e) => e.ipAddress == ip && !e.isExpired)
        .cast<ARPEntry?>()
        .firstOrNull;
    return entry?.macAddress;
  }

  void addEntry(ARPEntry entry) {
    _entries.removeWhere((e) => e.ipAddress == entry.ipAddress);
    _entries.add(entry);
    log('ARP: added $entry', name: 'ARPTable');
  }

  /// Removes all expired entries. Returns the count removed.
  int removeExpired() {
    final before = _entries.length;
    _entries.removeWhere((e) => e.isExpired);
    final removed = before - _entries.length;
    if (removed > 0) {
      log('ARP: removed $removed expired entries', name: 'ARPTable');
    }
    return removed;
  }

  void clear() => _entries.clear();

  List<Map<String, dynamic>> toJson() =>
      _entries.map((e) => e.toJson()).toList();

  void loadFromJson(List<dynamic> json) {
    _entries.clear();
    for (final e in json) {
      _entries.add(ARPEntry.fromJson(e as Map<String, dynamic>));
    }
  }

  @override
  String toString() => 'ARPTable(${_entries.length} entries)';
}
