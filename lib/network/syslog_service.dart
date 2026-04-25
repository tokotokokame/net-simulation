// lib/network/syslog_service.dart
import 'dart:async';
import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attack_packet.dart';
import '../simulation/attack_event.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum SyslogSeverity {
  emergency, // 0 – system unusable
  alert,     // 1 – immediate action needed
  critical,  // 2 – critical conditions
  error,     // 3 – error conditions
  warning,   // 4 – warning conditions
  notice,    // 5 – normal but significant
  info,      // 6 – informational
  debug,     // 7 – debug-level messages
}

// ── Data class ────────────────────────────────────────────────────────────────

class SyslogEntry {
  final DateTime timestamp;
  final SyslogSeverity severity;

  /// Originating device name or subsystem.
  final String facility;
  final String message;

  const SyslogEntry({
    required this.timestamp,
    required this.severity,
    required this.facility,
    required this.message,
  });

  @override
  String toString() =>
      '[${severity.name.toUpperCase()}] $facility: $message';
}

// ── Service ───────────────────────────────────────────────────────────────────

class SyslogService extends StateNotifier<List<SyslogEntry>> {
  SyslogService() : super(const []);

  final _controller = StreamController<SyslogEntry>.broadcast();

  /// Stream of individual new entries (use for real-time UI updates).
  Stream<SyslogEntry> get entryStream => _controller.stream;

  /// Appends a syslog entry and emits it on the stream.
  void addEntry(SyslogSeverity severity, String facility, String message) {
    final entry = SyslogEntry(
      timestamp: DateTime.now(),
      severity:  severity,
      facility:  facility,
      message:   message,
    );
    state = [entry, ...state];
    _controller.add(entry);
    log('$entry', name: 'SyslogService');
  }

  // ── Convenience helpers (simulation engine hooks) ─────────────────────────

  void packetDropped(String facility, String reason) =>
      addEntry(SyslogSeverity.error, facility, 'Packet dropped: $reason');

  void routeChanged(String facility, String route) =>
      addEntry(SyslogSeverity.notice, facility, 'Route changed: $route');

  void linkFailure(String facility, String link) =>
      addEntry(SyslogSeverity.critical, facility, 'Link failure: $link');

  void idsAlert(String facility, String detail) =>
      addEntry(SyslogSeverity.alert, facility, 'IDS alert: $detail');

  void attackStarted(String facility, String attackType) =>
      addEntry(SyslogSeverity.alert, facility, 'Attack started: $attackType');

  void connectionEstablished(String facility, String detail) =>
      addEntry(SyslogSeverity.info, facility, 'Connection established: $detail');

  /// Logs an attack cycle result with appropriate severity.
  void logAttackResult(
    AttackResult result, {
    required String attackerName,
    required String targetName,
  }) {
    final outcome = outcomeOf(result);
    final typeName = result.attackType.label;
    final (severity, message) = switch (outcome) {
      AttackOutcome.blocked =>
        (SyslogSeverity.critical,
         '[IPS BLOCK] $typeName 遮断: $attackerName → $targetName'
         ' (blocked=${result.packetsBlocked})'),
      AttackOutcome.detected =>
        (SyslogSeverity.alert,
         '[IDS ALERT] $typeName 検知: $attackerName → $targetName'
         ' (gen=${result.packetsGenerated})'),
      AttackOutcome.rateLimited =>
        (SyslogSeverity.warning,
         '[IPS RATE] $typeName レート制限: $attackerName → $targetName'
         ' (blocked=${result.packetsBlocked})'),
      AttackOutcome.sent =>
        (SyslogSeverity.notice,
         '[ATTACK] $typeName: $attackerName → $targetName'
         ' (${result.packetsGenerated} pkts)'),
    };
    addEntry(severity, attackerName, message);
  }

  // ── Query ─────────────────────────────────────────────────────────────────

  /// Returns entries optionally filtered by minimum severity and/or facility.
  List<SyslogEntry> getEntries({
    SyslogSeverity? minSeverity,
    String? facility,
  }) {
    return state.where((e) {
      if (minSeverity != null &&
          e.severity.index > minSeverity.index) { return false; }
      if (facility != null &&
          facility.isNotEmpty &&
          e.facility != facility) { return false; }
      return true;
    }).toList();
  }

  void clear() {
    state = const [];
    log('Syslog cleared', name: 'SyslogService');
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final syslogProvider =
    StateNotifierProvider<SyslogService, List<SyslogEntry>>(
        (_) => SyslogService());
