// lib/simulation/packet_processor.dart
import 'dart:developer';
import '../models/device.dart';
import '../models/packet.dart';
import '../models/topology.dart';
import '../network/arp_table.dart';
import '../network/nat_table.dart';
import '../routing/fib.dart';

class PacketProcessResult {
  final bool success;
  final String? nextDeviceId;
  final String? droppedReason;

  const PacketProcessResult._({
    required this.success,
    this.nextDeviceId,
    this.droppedReason,
  });

  factory PacketProcessResult.success(String? nextDeviceId) =>
      PacketProcessResult._(success: true, nextDeviceId: nextDeviceId);

  factory PacketProcessResult.drop(String reason) =>
      PacketProcessResult._(success: false, droppedReason: reason);

  @override
  String toString() => success
      ? 'Result(success, next=$nextDeviceId)'
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
      // 1. TTL check.
      if (packet.ttl <= 0) {
        log('Drop TTL=0: ${packet.id}', name: 'PacketProcessor');
        return PacketProcessResult.drop('TTL expired');
      }

      final ctx = contextFor(device.id);

      // 2. Firewall (placeholder — implemented Phase 4+).

      // 3. NAT translation.
      var pkt = packet;
      if (ctx.isNatEnabled) {
        pkt = ctx.natTable.translate(packet) ?? packet;
      }

      // 4. FIB lookup.
      final fibEntry = ctx.fib.lookup(pkt.destinationIp);
      if (fibEntry == null) {
        log('Drop no-route: ${pkt.destinationIp}', name: 'PacketProcessor');
        return PacketProcessResult.drop('No route to host');
      }

      // 5. ARP resolution.
      final mac = ctx.arpTable.lookup(fibEntry.nextHopIp);
      if (mac == null) {
        log('Drop ARP miss: ${fibEntry.nextHopIp}', name: 'PacketProcessor');
        return PacketProcessResult.drop('ARP unresolved');
      }

      // Resolve next hop device from topology.
      final nextId = _resolveNextDevice(fibEntry.nextHopIp, topology);
      log(
        'Forward ${pkt.id} → $nextId via ${fibEntry.nextHopIp} (MAC $mac)',
        name: 'PacketProcessor',
      );
      return PacketProcessResult.success(nextId);
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
