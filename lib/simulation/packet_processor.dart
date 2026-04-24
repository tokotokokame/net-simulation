// lib/simulation/packet_processor.dart
import 'dart:developer';
import '../models/device.dart';
import '../models/packet.dart';
import '../models/topology.dart';
import '../network/arp_table.dart';
import '../network/nat_table.dart';
import '../routing/dijkstra.dart';
import '../routing/fib.dart';

class PacketProcessResult {
  final bool success;
  final String? nextDeviceId;
  final String? droppedReason;
  /// TTL-decremented packet to forward on next hop. Null on drop.
  final Packet? packet;

  const PacketProcessResult._({
    required this.success,
    this.nextDeviceId,
    this.droppedReason,
    this.packet,
  });

  factory PacketProcessResult.success(String? nextDeviceId, {Packet? packet}) =>
      PacketProcessResult._(success: true, nextDeviceId: nextDeviceId, packet: packet);

  factory PacketProcessResult.drop(String reason) =>
      PacketProcessResult._(success: false, droppedReason: reason);

  @override
  String toString() => success
      ? 'Result(success, next=$nextDeviceId, ttl=${packet?.ttl})'
      : 'Result(drop, reason=$droppedReason)';
}

/// Per-device routing / NAT / ARP state injected into [PacketProcessor].
class DeviceContext {
  final ARPTable arpTable;
  final NATTable natTable;
  final FIB fib;
  final bool isNatEnabled;

  DeviceContext({
    ARPTable? arpTable,
    NATTable? natTable,
    FIB? fib,
    this.isNatEnabled = false,
  })  : arpTable = arpTable ?? ARPTable(),
        natTable = natTable ?? NATTable(),
        fib = fib ?? FIB();
}

class PacketProcessor {
  final _contexts = <String, DeviceContext>{};
  /// Cache: "deviceId:destIp" → next-hop device ID computed by Dijkstra.
  final _pathCache = <String, String?>{};

  void setContext(String deviceId, DeviceContext ctx) =>
      _contexts[deviceId] = ctx;

  DeviceContext contextFor(String deviceId) =>
      _contexts.putIfAbsent(deviceId, DeviceContext.new);

  /// Processes [packet] at [device] within [topology].
  /// Never throws — exceptions are caught, logged, and returned as Drop.
  PacketProcessResult processPacket(
    Packet packet,
    Device device,
    Topology topology,
  ) {
    try {
      // 1. TTL check and decrement.
      if (packet.ttl <= 0) {
        log('Drop TTL=0: ${packet.id}', name: 'PacketProcessor');
        return PacketProcessResult.drop('TTL expired');
      }
      final pktHop = packet.copyWith(ttl: packet.ttl - 1);
      log('Hop ${device.name} TTL ${packet.ttl}→${pktHop.ttl} pkt=${pktHop.id}',
          name: 'PacketProcessor');

      final ctx = contextFor(device.id);

      // 2. Firewall (placeholder — implemented Phase 4+).

      // 3. NAT translation.
      var pkt = pktHop;
      if (ctx.isNatEnabled) {
        pkt = ctx.natTable.translate(pktHop) ?? pktHop;
      }

      // 4. FIB lookup.
      FIBEntry? fibEntry = ctx.fib.lookup(pkt.destinationIp);

      // 4b. FIB miss → Dijkstra dynamic route computation.
      if (fibEntry == null) {
        final cacheKey = '${device.id}:${pkt.destinationIp}';
        String? nextId = _pathCache[cacheKey];
        if (nextId == null) {
          final path = Dijkstra.findPath(device.id, pkt.destinationIp, topology);
          nextId = path.length >= 2 ? path[1] : null;
          _pathCache[cacheKey] = nextId;
          log('Dijkstra: ${device.id}→${pkt.destinationIp} nextHop=$nextId',
              name: 'PacketProcessor');
        }
        if (nextId != null) {
          return PacketProcessResult.success(nextId, packet: pkt);
        }
        log('Drop no-route: ${pkt.destinationIp}', name: 'PacketProcessor');
        return PacketProcessResult.drop('No route to host');
      }

      // 5. ARP resolution.
      final mac = ctx.arpTable.lookup(fibEntry.nextHopIp);
      if (mac == null) {
        log('Drop ARP miss: ${fibEntry.nextHopIp}', name: 'PacketProcessor');
        return PacketProcessResult.drop('ARP unresolved');
      }

      // 6. Resolve next-hop device from topology.
      final nextId = _resolveNextDevice(fibEntry.nextHopIp, topology);
      log('Forward ${pkt.id} → $nextId via ${fibEntry.nextHopIp} (MAC $mac)',
          name: 'PacketProcessor');
      return PacketProcessResult.success(nextId, packet: pkt);
    } catch (e, st) {
      log('PacketProcessor exception: $e\n$st', name: 'PacketProcessor');
      return PacketProcessResult.drop('Internal error: $e');
    }
  }

  String? _resolveNextDevice(String nextHopIp, Topology topology) {
    for (final d in topology.devices) {
      for (final iface in d.interfaces) {
        if (iface.ip == nextHopIp) return d.id;
      }
    }
    return null;
  }
}
