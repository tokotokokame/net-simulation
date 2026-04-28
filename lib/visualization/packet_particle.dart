// lib/visualization/packet_particle.dart
import 'package:flutter/material.dart';
import '../models/packet.dart';

const Color kColorForwarding = Color(0xFF2196F3); // blue
const Color kColorSuccess    = Color(0xFF4CAF50); // green
const Color kColorDropped    = Color(0xFFF44336); // red
const Color kColorDelayed    = Color(0xFFFFC107); // amber

Color packetColor(PacketStatus status) => switch (status) {
  PacketStatus.inTransit => kColorForwarding,
  PacketStatus.delivered => kColorSuccess,
  PacketStatus.dropped   => kColorDropped,
  PacketStatus.delayed   => kColorDelayed,
};

/// Multi-hop packet particle that traverses a full device-to-device path.
class PacketParticle {
  final String         id;
  final List<Offset>   path;

  int          pathIndex  = 0;
  double       progress   = 0.0;
  int          doneFrames = 0;
  PacketStatus status;
  Offset       position;

  PacketParticle({
    required this.id,
    required this.path,
    required this.position,
    this.status = PacketStatus.inTransit,
  });

  /// Resets the particle to the beginning of its path for looped playback.
  void reset() {
    pathIndex  = 0;
    progress   = 0.0;
    doneFrames = 0;
    status     = PacketStatus.inTransit;
    position   = path.first;
  }

  /// Current interpolated canvas position (used by TopologyPainter).
  Offset get currentPosition => position;

  Color  get color  => packetColor(status);
  double get radius => 5.0;
}
