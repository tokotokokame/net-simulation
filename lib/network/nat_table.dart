// lib/network/nat_table.dart
import 'dart:developer';
import '../models/packet.dart';

enum NATState { active, timeWait, closed }

class NATEntry {
  final ProtocolType protocol;
  final String insideLocal; // "192.168.1.10:12345"
  final String insideGlobal; // "203.0.113.1:45678"
  final String outsideGlobal; // "8.8.8.8:53"
  final NATState state;
  final DateTime createdAt;

  const NATEntry({
    required this.protocol,
    required this.insideLocal,
    required this.insideGlobal,
    required this.outsideGlobal,
    this.state = NATState.active,
    required this.createdAt,
  });

  NATEntry copyWith({NATState? state}) => NATEntry(
        protocol: protocol,
        insideLocal: insideLocal,
        insideGlobal: insideGlobal,
        outsideGlobal: outsideGlobal,
        state: state ?? this.state,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'protocol': protocol.name,
        'insideLocal': insideLocal,
        'insideGlobal': insideGlobal,
        'outsideGlobal': outsideGlobal,
        'state': state.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory NATEntry.fromJson(Map<String, dynamic> json) => NATEntry(
        protocol: ProtocolType.values
            .firstWhere((e) => e.name == json['protocol']),
        insideLocal: json['insideLocal'] as String,
        insideGlobal: json['insideGlobal'] as String,
        outsideGlobal: json['outsideGlobal'] as String,
        state: NATState.values
            .firstWhere((e) => e.name == (json['state'] ?? 'active')),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

(String, int) _parseEndpoint(String ep) {
  final idx = ep.lastIndexOf(':');
  return (ep.substring(0, idx), int.parse(ep.substring(idx + 1)));
}

class NATTable {
  final List<NATEntry> _entries = [];

  List<NATEntry> get entries => List.unmodifiable(_entries);

  void addEntry(NATEntry entry) {
    _entries.add(entry);
    log('NAT: added ${entry.insideLocal} → ${entry.insideGlobal}',
        name: 'NATTable');
  }

  /// Translates outbound packet (inside→outside). Returns translated copy or null.
  Packet? translate(Packet packet) {
    final srcEp = '${packet.sourceIp}:${packet.sourcePort}';
    final entry = _entries
        .where((e) =>
            e.protocol == packet.protocol &&
            e.insideLocal == srcEp &&
            e.state == NATState.active)
        .cast<NATEntry?>()
        .firstOrNull;

    if (entry == null) return null;

    final (globalIp, globalPort) = _parseEndpoint(entry.insideGlobal);
    log('NAT: translate $srcEp → ${entry.insideGlobal}', name: 'NATTable');
    return packet.copyWith(sourceIp: globalIp, sourcePort: globalPort);
  }

  /// Removes all entries matching [state].
  int removeByState(NATState state) {
    final before = _entries.length;
    _entries.removeWhere((e) => e.state == state);
    final removed = before - _entries.length;
    if (removed > 0) {
      log('NAT: removed $removed ${state.name} entries', name: 'NATTable');
    }
    return removed;
  }

  List<Map<String, dynamic>> toJson() =>
      _entries.map((e) => e.toJson()).toList();

  void loadFromJson(List<dynamic> json) {
    _entries.clear();
    for (final e in json) {
      _entries.add(NATEntry.fromJson(e as Map<String, dynamic>));
    }
  }
}
