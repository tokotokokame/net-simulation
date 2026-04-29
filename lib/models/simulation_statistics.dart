// lib/models/simulation_statistics.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SimulationStatistics {
  final int    totalPackets;
  final int    deliveredPackets;
  final int    droppedPackets;
  final double avgLatencyMs;

  const SimulationStatistics({
    this.totalPackets     = 0,
    this.deliveredPackets = 0,
    this.droppedPackets   = 0,
    this.avgLatencyMs     = 0.0,
  });

  double get successRate =>
      totalPackets == 0 ? 0.0 : deliveredPackets / totalPackets * 100;
  double get lossRate =>
      totalPackets == 0 ? 0.0 : droppedPackets   / totalPackets * 100;
}

class StatisticsNotifier extends Notifier<SimulationStatistics> {
  int _totalLatencyMs = 0;

  @override
  SimulationStatistics build() => const SimulationStatistics();

  void reset() {
    _totalLatencyMs = 0;
    state = const SimulationStatistics();
  }

  void recordPacket({required bool success, int latencyMs = 0}) {
    final delivered = state.deliveredPackets + (success ? 1 : 0);
    final dropped   = state.droppedPackets   + (success ? 0 : 1);
    final total     = state.totalPackets + 1;
    if (success) _totalLatencyMs += latencyMs;
    final avg = delivered == 0 ? 0.0 : _totalLatencyMs / delivered;
    state = SimulationStatistics(
      totalPackets:     total,
      deliveredPackets: delivered,
      droppedPackets:   dropped,
      avgLatencyMs:     avg,
    );
  }
}

final statisticsNotifierProvider =
    NotifierProvider<StatisticsNotifier, SimulationStatistics>(
        StatisticsNotifier.new);
