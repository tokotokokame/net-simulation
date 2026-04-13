// lib/simulation/traffic_generator.dart
import 'dart:async';
import 'dart:developer';
import 'package:uuid/uuid.dart';
import '../models/packet.dart';

enum TrafficType { ping, http, dns, customUdp }

class TrafficConfig {
  final TrafficType type;
  final String sourceDeviceId;
  final String sourceIp;
  final String destinationIp;
  final int packetRate; // packets / second
  final int packetSize; // bytes
  final Duration duration;

  const TrafficConfig({
    required this.type,
    required this.sourceDeviceId,
    required this.sourceIp,
    required this.destinationIp,
    this.packetRate = 1,
    this.packetSize = 64,
    this.duration = const Duration(seconds: 60),
  });
}

const _uuid = Uuid();

class TrafficGenerator {
  /// Emits packets according to [cfg] over [cfg.duration].
  /// Uses async generator (Dart event loop — no OS threads).
  Stream<Packet> generatePackets(TrafficConfig cfg) async* {
    final rate = cfg.packetRate.clamp(1, 1000);
    final interval = Duration(milliseconds: 1000 ~/ rate);
    final deadline = DateTime.now().add(cfg.duration);

    while (DateTime.now().isBefore(deadline)) {
      for (final p in _makePackets(cfg)) {
        log('TrafficGen [${cfg.type.name}]: ${p.id}', name: 'TrafficGenerator');
        yield p;
      }
      await Future<void>.delayed(interval);
    }
  }

  List<Packet> _makePackets(TrafficConfig cfg) {
    final id = _uuid.v4().substring(0, 8);
    final sport = 49152 + id.hashCode.abs() % 16383;
    return switch (cfg.type) {
      TrafficType.ping => [
          Packet(
            id: 'icmp-$id',
            sourceIp: cfg.sourceIp,
            destinationIp: cfg.destinationIp,
            sourcePort: 0,
            destinationPort: 0,
            protocol: ProtocolType.icmp,
            size: cfg.packetSize,
          ),
        ],
      TrafficType.http => [
          Packet(
            id: 'tcp-syn-$id',
            sourceIp: cfg.sourceIp,
            destinationIp: cfg.destinationIp,
            sourcePort: sport,
            destinationPort: 80,
            protocol: ProtocolType.tcp,
            tcpFlags: const TcpFlags(syn: true),
            size: cfg.packetSize,
          ),
          Packet(
            id: 'tcp-ack-$id',
            sourceIp: cfg.sourceIp,
            destinationIp: cfg.destinationIp,
            sourcePort: sport,
            destinationPort: 80,
            protocol: ProtocolType.tcp,
            tcpFlags: const TcpFlags(syn: true, ack: true),
            size: cfg.packetSize,
          ),
        ],
      TrafficType.dns => [
          Packet(
            id: 'dns-$id',
            sourceIp: cfg.sourceIp,
            destinationIp: cfg.destinationIp,
            sourcePort: sport,
            destinationPort: 53,
            protocol: ProtocolType.udp,
            size: cfg.packetSize,
          ),
        ],
      TrafficType.customUdp => [
          Packet(
            id: 'udp-$id',
            sourceIp: cfg.sourceIp,
            destinationIp: cfg.destinationIp,
            sourcePort: sport,
            destinationPort: 5000,
            protocol: ProtocolType.udp,
            size: cfg.packetSize,
          ),
        ],
    };
  }
}
