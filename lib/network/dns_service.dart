// lib/network/dns_service.dart
import 'dart:developer';
import '../models/topology.dart';

// ── Data classes ─────────────────────────────────────────────────────────────

enum DnsRecordType { a, cname, ptr }

class DnsRecord {
  /// For A:     hostname = FQDN, ipAddress = IPv4 address.
  /// For CNAME: hostname = alias, ipAddress = canonical hostname.
  /// For PTR:   hostname = reverse notation, ipAddress = FQDN.
  final String hostname;
  final String ipAddress;
  final DnsRecordType type;

  const DnsRecord({
    required this.hostname,
    required this.ipAddress,
    required this.type,
  });

  @override
  String toString() => 'DnsRecord(${type.name} $hostname → $ipAddress)';
}

// ── DnsService ───────────────────────────────────────────────────────────────

class DnsService {
  final _records = <DnsRecord>[];

  DnsService();

  /// Creates a [DnsService] pre-populated with A records for every device
  /// interface that has a non-zero IP.
  factory DnsService.fromTopology(Topology topology) {
    final svc = DnsService();
    for (final device in topology.devices) {
      for (final iface in device.interfaces) {
        if (iface.ip == '0.0.0.0') continue;
        // A record: device.name → interface IP.
        svc.addRecord(DnsRecord(
          hostname: '${device.name.toLowerCase().replaceAll(' ', '-')}.local',
          ipAddress: iface.ip,
          type: DnsRecordType.a,
        ));
        // PTR record: reverse lookup.
        svc.addRecord(DnsRecord(
          hostname: _toPtrName(iface.ip),
          ipAddress: '${device.name.toLowerCase().replaceAll(' ', '-')}.local',
          type: DnsRecordType.ptr,
        ));
      }
    }
    log('DNS: populated ${svc._records.length} records from topology',
        name: 'DnsService');
    return svc;
  }

  /// Resolves [hostname] to an IP address.
  /// Follows CNAME chains (cycle-safe, max 8 hops).
  String? resolve(String hostname) {
    String current = hostname;
    final visited = <String>{};

    while (!visited.contains(current) && visited.length < 8) {
      visited.add(current);
      // Prefer A record.
      for (final r in _records) {
        if (r.hostname != current) continue;
        if (r.type == DnsRecordType.a) {
          log('DNS: $hostname → ${r.ipAddress}', name: 'DnsService');
          return r.ipAddress;
        }
        if (r.type == DnsRecordType.cname) {
          current = r.ipAddress; // follow alias
          break;
        }
      }
    }

    log('DNS: $hostname not found', name: 'DnsService');
    return null;
  }

  /// Returns the hostname for [ip] via PTR records, or by scanning A records.
  String? reverseLookup(String ip) {
    // Check PTR records first.
    final ptrName = _toPtrName(ip);
    for (final r in _records) {
      if (r.type == DnsRecordType.ptr && r.hostname == ptrName) {
        log('DNS: PTR $ip → ${r.ipAddress}', name: 'DnsService');
        return r.ipAddress;
      }
    }
    // Fall back: scan A records.
    for (final r in _records) {
      if (r.type == DnsRecordType.a && r.ipAddress == ip) {
        log('DNS: reverse (A) $ip → ${r.hostname}', name: 'DnsService');
        return r.hostname;
      }
    }
    log('DNS: no reverse record for $ip', name: 'DnsService');
    return null;
  }

  /// Adds a DNS record.
  void addRecord(DnsRecord record) {
    _records.add(record);
    log('DNS: added ${record.type.name} ${record.hostname}', name: 'DnsService');
  }

  /// Removes all records whose [hostname] matches [hostname].
  void removeRecord(String hostname) {
    final before = _records.length;
    _records.removeWhere((r) => r.hostname == hostname);
    final removed = before - _records.length;
    if (removed > 0) {
      log('DNS: removed $removed record(s) for $hostname', name: 'DnsService');
    }
  }

  List<DnsRecord> get records => List.unmodifiable(_records);

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _toPtrName(String ip) {
    final parts = ip.split('.');
    return '${parts.reversed.join('.')}.in-addr.arpa';
  }
}
