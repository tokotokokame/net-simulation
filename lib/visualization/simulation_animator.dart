// lib/visualization/simulation_animator.dart
// Particle animation is now driven by SimulationEngine._updateParticles.
// This file is retained for API compatibility but is no longer active.
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../models/packet.dart';
import '../models/topology.dart';
import 'packet_particle.dart';

class SimulationAnimator with ChangeNotifier {
  final TickerProvider vsync;

  Ticker? _ticker;

  SimulationAnimator(this.vsync);

  List<PacketParticle> get activeParticles => const [];

  void start() {
    _ticker ??= vsync.createTicker(_onTick);
    if (!_ticker!.isActive) {
      _ticker!.start();
      log('SimulationAnimator started', name: 'Animator');
    }
  }

  void stop() {
    _ticker?.stop();
    notifyListeners();
    log('SimulationAnimator stopped', name: 'Animator');
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  void updateParticles(List<Packet> packets, Topology topology) {
    // No-op: particle management moved to SimulationEngine.
  }

  void _onTick(Duration elapsed) {
    notifyListeners();
  }
}
