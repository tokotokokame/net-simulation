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
  final String       id;
  final List<Offset> path;
  /// Device IDs in path order — used for blocked-link detection.
  final List<String> deviceIds;

  int          pathIndex  = 0;
  double       progress   = 0.0;
  int          doneFrames = 0;
  PacketStatus status;
  Offset       position;

  /// True while the packet is paused at an intermediate node (orange glow).
  bool isAtNode   = false;
  int  nodeFrames = 0;
  static const int kNodePauseDuration = 8;

  PacketParticle({
    required this.id,
    required this.path,
    required this.position,
    this.deviceIds = const [],
    this.status = PacketStatus.inTransit,
  });

  void reset() {
    pathIndex  = 0;
    progress   = 0.0;
    doneFrames = 0;
    status     = PacketStatus.inTransit;
    position   = path.first;
    isAtNode   = false;
    nodeFrames = 0;
  }

  Offset get currentPosition => position;
  Color  get color  => packetColor(status);
  double get radius => 5.0;
}
