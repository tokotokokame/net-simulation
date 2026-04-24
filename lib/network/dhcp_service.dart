// lib/network/dhcp_service.dart
import 'dart:developer';
import '../models/device.dart';
import '../models/topology.dart';

// ── Data classes ─────────────────────────────────────────────────────────────

class DhcpScope {
  final String startIp;
  final String endIp;
  final String gatewayIp;
  final String dnsIp;
  final int leaseSeconds;

  const DhcpScope({
    required this.startIp,
    required this.endIp,
    required this.gatewayIp,
    required this.dnsIp,
    this.leaseSeconds = 86400,
  });
}

class DhcpLease {
  final String ip;
  final String mac;
  final String deviceId;
  final DateTime expiresAt;

  const DhcpLease({
    required this.ip,
    required this.mac,
    required this.deviceId,
    required this.expiresAt,
  });

  bool get isExpired => expiresAt.isBefore(DateTime.now());

  @override
  String toString() => 'DhcpLease($ip, mac=$mac, exp=$expiresAt)';
}

// ── IP helpers ───────────────────────────────────────────────────────────────

int _ipToInt(String ip) {
  final p = ip.split('.').map(int.parse).toList();
  return (p[0] << 24) | (p[1] << 16) | (p[2] << 8) | p[3];
}

String _intToIp(int n) =>
    '${(n >> 24) & 0xFF}.${(n >> 16) & 0xFF}.${(n >> 8) & 0xFF}.${n & 0xFF}';

// ── DhcpService ──────────────────────────────────────────────────────────────

class DhcpService {
  final _leases = <String, DhcpLease>{}; // key = MAC address

  static const _endpointTypes = {
    DeviceType.pc, DeviceType.laptop, DeviceType.server,
    DeviceType.iotDevice, DeviceType.wirelessAP,
  };

  /// Allocates the first available IP in [scope] for [mac]/[deviceId].
  /// Renews an existing lease if [mac] already holds one.
  /// Returns null when the scope is exhausted.
  DhcpLease? requestLease(String mac, String deviceId, DhcpScope scope) {
    // Renew existing valid lease.
    final existing = _leases[mac];
    if (existing != null && !existing.isExpired) {
      final renewed = DhcpLease(
        ip: existing.ip, mac: mac, deviceId: deviceId,
        expiresAt: DateTime.now().add(Duration(seconds: scope.leaseSeconds)),
      );
      _leases[mac] = renewed;
      log('DHCP: renewed ${renewed.ip} → $mac', name: 'DhcpService');
      return renewed;
    }

    // Find first unused IP in the scope range.
    final usedIps = _leases.values
        .where((l) => !l.isExpired)
        .map((l) => l.ip)
        .toSet();

    final start = _ipToInt(scope.startIp);
    final end = _ipToInt(scope.endIp);
    for (int n = start; n <= end; n++) {
      final ip = _intToIp(n);
      if (usedIps.contains(ip)) continue;
      final lease = DhcpLease(
        ip: ip, mac: mac, deviceId: deviceId,
        expiresAt: DateTime.now().add(Duration(seconds: scope.leaseSeconds)),
      );
      _leases[mac] = lease;
      log('DHCP: leased $ip → $mac ($deviceId)', name: 'DhcpService');
      return lease;
    }

    log('DHCP: scope full — no IP available for $mac', name: 'DhcpService');
    return null;
  }

  /// Removes the lease held by [mac].
  void releaseLease(String mac) {
    if (_leases.remove(mac) != null) {
      log('DHCP: released lease for $mac', name: 'DhcpService');
    }
  }

  /// Returns the current lease for [mac], or null if none/expired.
  DhcpLease? getLeaseByMac(String mac) {
    final l = _leases[mac];
    return (l != null && !l.isExpired) ? l : null;
  }

  /// Removes all expired leases. Returns the number removed.
  int removeExpired() {
    final before = _leases.length;
    _leases.removeWhere((_, l) => l.isExpired);
    final removed = before - _leases.length;
    if (removed > 0) log('DHCP: purged $removed expired leases', name: 'DhcpService');
    return removed;
  }

  /// Assigns IPs to all unaddressed endpoints in [topology] using [scope].
  /// Returns deviceId → assigned IP.
  Map<String, String> autoAssign(Topology topology, DhcpScope scope) {
    final result = <String, String>{};
    for (final device in topology.devices) {
      if (!_endpointTypes.contains(device.type)) continue;
      if (device.interfaces.any((i) => i.ip != '0.0.0.0')) continue;
      final mac = device.interfaces.isNotEmpty
          ? device.interfaces.first.mac : device.id;
      final lease = requestLease(mac, device.id, scope);
      if (lease != null) result[device.id] = lease.ip;
    }
    log('DHCP: auto-assigned ${result.length} addresses', name: 'DhcpService');
    return result;
  }

  List<DhcpLease> get allLeases => _leases.values.toList();
}
