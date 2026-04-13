// lib/ui/screens/statistics_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../simulation/simulation_engine.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(simulationEngineProvider);
    final stats = engine.stats;
    final total = stats.totalPackets;
    final successRate = total == 0 ? 0.0 : stats.deliveredPackets / total * 100;
    final lossRate = total == 0 ? 0.0 : stats.droppedPackets / total * 100;

    return Scaffold(
      appBar: AppBar(
        title: const Text('統計ダッシュボード'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'クリア',
              onPressed: () => ref.read(simulationEngineProvider.notifier).stop()),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusChip(state: engine.simState),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.6,
            children: [
              _MetricCard('パケット成功率', '${successRate.toStringAsFixed(1)}%', Icons.check_circle_outline, Colors.green),
              _MetricCard('平均レイテンシ', '${stats.avgLatencyMs.toStringAsFixed(1)} ms', Icons.timer_outlined, Colors.blue),
              _MetricCard('帯域幅使用率', '${(stats.bandwidthUtilization * 100).toStringAsFixed(1)}%', Icons.show_chart, Colors.orange),
              _MetricCard('パケットロス率', '${lossRate.toStringAsFixed(1)}%', Icons.error_outline, Colors.red),
            ],
          ),
          const SizedBox(height: 16),
          Text('パケット概要', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _SummaryRow('合計', total),
          _SummaryRow('到達', stats.deliveredPackets, color: Colors.green),
          _SummaryRow('ドロップ', stats.droppedPackets, color: Colors.red),
          const SizedBox(height: 16),
          Text('最近のパケット (${engine.activePackets.length}件)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...engine.activePackets.reversed.take(10).map((p) => ListTile(
                dense: true,
                leading: Icon(p.status.name == 'dropped' ? Icons.cancel : Icons.check_circle,
                    color: p.status.name == 'dropped' ? Colors.red : Colors.green, size: 20),
                title: Text('${p.sourceIp} → ${p.destinationIp}', style: const TextStyle(fontSize: 13)),
                subtitle: Text('${p.protocol.name.toUpperCase()} :${p.destinationPort}', style: const TextStyle(fontSize: 11)),
                trailing: Text(p.status.name, style: const TextStyle(fontSize: 11)),
              )),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _MetricCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(12), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: color, size: 26),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(fontSize: 10), textAlign: TextAlign.center),
    ])),
  );
}

class _SummaryRow extends StatelessWidget {
  final String label; final int count; final Color? color;
  const _SummaryRow(this.label, this.count, {this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [Expanded(child: Text(label)),
      Text('$count', style: TextStyle(fontWeight: FontWeight.bold, color: color))]),
  );
}

class _StatusChip extends StatelessWidget {
  final SimulationState state;
  const _StatusChip({required this.state});
  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      SimulationState.running => ('実行中', Colors.green),
      SimulationState.paused => ('一時停止', Colors.orange),
      SimulationState.stopped => ('停止', Colors.red),
      SimulationState.idle => ('待機中', Colors.grey),
    };
    return Chip(label: Text(label), backgroundColor: color.withValues(alpha: 0.2),
        side: BorderSide(color: color), avatar: Icon(Icons.circle, color: color, size: 10));
  }
}
