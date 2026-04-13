// lib/visualization/packet_particle.dart
import 'package:flutter/material.dart';
import '../models/packet.dart';

Color packetColor(PacketStatus status) => switch (status) {
      PacketStatus.inTransit => Colors.blue,
      PacketStatus.delivered => Colors.green,
      PacketStatus.dropped => Colors.red,
      PacketStatus.delayed => Colors.yellow,
    };

class PacketParticle {
  final String packetId;
  final Offset sourcePosition;
  final Offset destinationPosition;
  final double radius;

  double progress; // 0.0 → 1.0
  PacketStatus status;
  double lingerMs; // ms since terminal state reached

  PacketParticle({
    required this.packetId,
    required this.sourcePosition,
    required this.destinationPosition,
    this.radius = 5.0,
    this.progress = 0.0,
    this.status = PacketStatus.inTransit,
    this.lingerMs = 0.0,
  });

  Color get color => packetColor(status);

  /// Linearly interpolated position on the source → destination segment.
  Offset get currentPosition => Offset.lerp(sourcePosition, destinationPosition, progress.clamp(0.0, 1.0))!;

  bool get isTerminal => status == PacketStatus.delivered || status == PacketStatus.dropped;

  /// Advance progress and linger timer. Returns true if the particle should be removed.
  bool advance(double deltaMs, {double travelMs = 500.0, double lingerLimitMs = 800.0}) {
    if (!isTerminal) {
      progress = (progress + deltaMs / travelMs).clamp(0.0, 1.0);
      if (progress >= 1.0 && status == PacketStatus.inTransit) {
        status = PacketStatus.delivered;
      }
    } else {
      lingerMs += deltaMs;
      if (lingerMs >= lingerLimitMs) return true; // remove
    }
    return false;
  }

  PacketParticle copyWith({
    double? progress,
    PacketStatus? status,
    double? lingerMs,
  }) => PacketParticle(
        packetId: packetId,
        sourcePosition: sourcePosition,
        destinationPosition: destinationPosition,
        radius: radius,
        progress: progress ?? this.progress,
        status: status ?? this.status,
        lingerMs: lingerMs ?? this.lingerMs,
      );
}
