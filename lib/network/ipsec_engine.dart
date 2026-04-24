// lib/network/ipsec_engine.dart
import 'dart:developer';
import '../models/device.dart';
import '../models/packet.dart';
import '../models/topology.dart';

// ── IpsecTunnel ───────────────────────────────────────────────────────────────

/// Represents a site-to-site IPSec tunnel between two VPN gateways.
class IpsecTunnel {
  final String id;

  /// Device ID of the local VPN gateway.
  final String localGatewayId;

  /// Device ID of the remote VPN gateway.
  final String remoteGatewayId;

  /// CIDR of the local protected network (e.g. "10.0.1.0/24").
  final String localNetwork;

  /// CIDR of the remote protected network (e.g. "10.0.2.0/24").
  final String remoteNetwork;

  /// Pre-shared key (used for log output only in this simulation).
  final String psk;

  const IpsecTunnel({
    required this.id,
    required this.localGatewayId,
    required this.remoteGatewayId,
    required this.localNetwork,
    required this.remoteNetwork,
    required this.psk,
  });

  @override
  String toString() =>
      'IpsecTunnel($id $localNetwork↔$remoteNetwork '
      'gw=$localGatewayId→$remoteGatewayId)';
}

// ── IpsecEngine ───────────────────────────────────────────────────────────────

class IpsecEngine {
  final _tunnels = <IpsecTunnel>[];

  // ── Tunnel management ──────────────────────────────────────────────────────

  void addTunnel(IpsecTunnel tunnel) {
    _tunnels.add(tunnel);
    log('IPSec: registered $tunnel', name: 'IpsecEngine');
  }

  void removeTunnel(String tunnelId) {
    final before = _tunnels.length;
    _tunnels.removeWhere((t) => t.id == tunnelId);
    if (_tunnels.length < before) {
      log('IPSec: removed tunnel=$tunnelId', name: 'IpsecEngine');
    }
  }

  List<IpsecTunnel> get tunnels => List.unmodifiable(_tunnels);

  /// Auto-detects VPN gateway pairs from [topology] and registers tunnels.
  /// Each pair of adjacent [DeviceType.vpnGateway] nodes gets one tunnel.
  void autoDetect(Topology topology) {
    final gateways =
        topology.devices.where((d) => d.type == DeviceType.vpnGateway).toList();

    for (var i = 0; i < gateways.length; i++) {
      for (var j = i + 1; j < gateways.length; j++) {
        final a = gateways[i];
        final b = gateways[j];
        final connected = topology.links.any(
          (l) =>
              (l.deviceAId == a.id && l.deviceBId == b.id) ||
              (l.deviceAId == b.id && l.deviceBId == a.id),
        );
        if (!connected) continue;

        final aNet = _gatewayNetwork(a);
        final bNet = _gatewayNetwork(b);
        final tunnel = IpsecTunnel(
          id: 'ipsec-${a.id}-${b.id}',
          localGatewayId: a.id,
          remoteGatewayId: b.id,
          localNetwork: aNet,
          remoteNetwork: bNet,
          psk: 'auto-psk-${a.id.substring(0, 4)}',
        );
        addTunnel(tunnel);
      }
    }
  }

  // ── Packet processing ──────────────────────────────────────────────────────

  /// Returns the tunnel that should be applied to [packet] leaving [device],
  /// or null if no tunnel matches.
  IpsecTunnel? shouldEncapsulate(Packet packet, Device device) {
    for (final tunnel in _tunnels) {
      if (tunnel.localGatewayId != device.id) continue;
      if (_inNetwork(packet.destinationIp, tunnel.remoteNetwork)) {
        return tunnel;
      }
    }
    return null;
  }

  /// Encapsulates [packet] inside the IPSec tunnel by rewriting the source IP
  /// to the local gateway's IP address.  The original IPs are preserved in
  /// [Packet.sourceIp] / [Packet.destinationIp] so that [decapsulate] can
  /// reverse the operation without additional state (simplified model).
  Packet encapsulate(Packet packet, IpsecTunnel tunnel, Topology topology) {
    final localGw = topology.devices
        .where((d) => d.id == tunnel.localGatewayId)
        .firstOrNull;
    final remoteGw = topology.devices
        .where((d) => d.id == tunnel.remoteGatewayId)
        .firstOrNull;

    final newSrc = localGw?.interfaces.firstOrNull?.ip ?? packet.sourceIp;
    final newDst = remoteGw?.interfaces.firstOrNull?.ip ?? packet.destinationIp;

    log('IPSec: encapsulate pkt=${packet.id} '
        '${packet.sourceIp}→${packet.destinationIp} '
        'via tunnel=${tunnel.id} outer=$newSrc→$newDst',
        name: 'IpsecEngine');

    return packet.copyWith(
      sourceIp: newSrc,
      destinationIp: newDst,
    );
  }

  /// Decapsulates [packet] at the remote gateway, restoring the original
  /// inner source IP (local protected network gateway).
  Packet decapsulate(Packet packet, IpsecTunnel tunnel, Topology topology) {
    final localGw = topology.devices
        .where((d) => d.id == tunnel.localGatewayId)
        .firstOrNull;

    final innerSrc = localGw?.interfaces.firstOrNull?.ip ?? packet.sourceIp;

    log('IPSec: decapsulate pkt=${packet.id} '
        'outer=${packet.sourceIp}→${packet.destinationIp} '
        'inner=$innerSrc via tunnel=${tunnel.id}',
        name: 'IpsecEngine');

    return packet.copyWith(sourceIp: innerSrc);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Derives a /24 network CIDR from the gateway's first interface IP.
  static String _gatewayNetwork(Device gw) {
    final ip = gw.interfaces.firstOrNull?.ip ?? '0.0.0.0';
    final parts = ip.split('.');
    if (parts.length != 4) return '0.0.0.0/24';
    return '${parts[0]}.${parts[1]}.${parts[2]}.0/24';
  }

  static bool _inNetwork(String ip, String cidr) {
    if (cidr.contains('/')) {
      final p = cidr.split('/');
      final bits = int.tryParse(p[1]) ?? 32;
      if (bits == 0) return true;
      final mask =
          bits >= 32 ? 0xFFFFFFFF : (0xFFFFFFFF << (32 - bits)) & 0xFFFFFFFF;
      return (_toInt(ip) & mask) == (_toInt(p[0]) & mask);
    }
    return ip == cidr;
  }

  static int _toInt(String ip) {
    final p = ip.split('.').map(int.parse).toList();
    return (p[0] << 24) | (p[1] << 16) | (p[2] << 8) | p[3];
  }
}
