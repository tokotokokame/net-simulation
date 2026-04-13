// lib/visualization/simulation_animator.dart
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/rendering.dart' show Offset;
import '../models/packet.dart';
import '../models/topology.dart';
import 'packet_particle.dart';

const int kMaxParticles = 2000;
const double kTravelMs = 600.0;  // ms for a particle to traverse one link
const double kLingerMs = 800.0;  // ms terminal particles remain visible

class SimulationAnimator with ChangeNotifier {
  final TickerProvider vsync;

  Ticker? _ticker;
  Duration _prev = Duration.zero;
  final List<PacketParticle> _particles = [];
  final Set<String> _knownIds = {};

  SimulationAnimator(this.vsync);

  List<PacketParticle> get activeParticles => List.unmodifiable(_particles);

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  void start() {
    _ticker ??= vsync.createTicker(_onTick);
    if (!_ticker!.isActive) {
      _prev = Duration.zero;
      _ticker!.start();
      log('SimulationAnimator started', name: 'Animator');
    }
  }

  void stop() {
    _ticker?.stop();
    _particles.clear();
    _knownIds.clear();
    notifyListeners();
    log('SimulationAnimator stopped', name: 'Animator');
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  // ── Sync with engine packets ───────────────────────────────────────────────

  void updateParticles(List<Packet> packets, Topology topology) {
    final deviceMap = {for (final d in topology.devices) d.id: d};

    for (final pkt in packets) {
      if (_knownIds.contains(pkt.id)) {
        // Update status for already-tracked particles
        final idx = _particles.indexWhere((p) => p.packetId == pkt.id);
        if (idx >= 0 && !_particles[idx].isTerminal) {
          _particles[idx].status = pkt.status;
        }
        continue;
      }

      // Determine source + destination positions from topology
      final src = deviceMap[pkt.sourceIp] ?? deviceMap.values.firstOrNull;
      final dst = deviceMap[pkt.destinationIp] ?? deviceMap.values.lastOrNull;
      if (src == null || dst == null) continue;

      // Cap particle count
      if (_particles.length >= kMaxParticles) {
        final removeCount = _particles.length - kMaxParticles + 1;
        _particles.removeRange(0, removeCount);
        _knownIds.removeAll(_knownIds.take(removeCount).toList());
      }

      _particles.add(PacketParticle(
        packetId: pkt.id,
        sourcePosition: Offset(src.x, src.y),
        destinationPosition: Offset(dst.x, dst.y),
        status: pkt.status,
      ));
      _knownIds.add(pkt.id);
    }
  }

  // ── Ticker callback ───────────────────────────────────────────────────────

  void _onTick(Duration elapsed) {
    final deltaMs = _prev == Duration.zero
        ? 16.0
        : (elapsed - _prev).inMicroseconds / 1000.0;
    _prev = elapsed;

    _particles.removeWhere(
      (p) => p.advance(deltaMs, travelMs: kTravelMs, lingerLimitMs: kLingerMs),
    );

    notifyListeners();
  }
}
