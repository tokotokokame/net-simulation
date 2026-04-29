// lib/ui/screens/statistics_screen.dart
import 'dart:math' show max;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/attack_packet.dart';
import '../../models/simulation_statistics.dart';
import '../../simulation/attack_event.dart';
import '../../simulation/simulation_engine.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(simulationEngineProvider);
    final stats  = ref.watch(statisticsNotifierProvider);
    final total  = stats.totalPackets;

    return Scaffold(
      appBar: AppBar(
        title: const Text('統計'),
        actions: [
          IconButton(icon: const Icon(Icons.article_outlined), tooltip: 'Syslog',
              onPressed: () => context.push('/syslog')),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'クリア',
            onPressed: () {
              ref.read(statisticsNotifierProvider.notifier).reset();
              ref.read(simulationEngineProvider.notifier).stop();
            },
          ),
        ],
      ),
      body: total == 0
          ? const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.bar_chart, size: 48, color: Colors.white24),
                SizedBox(height: 12),
                Text('シミュレーションを開始するとデータが表示されます',
                    style: TextStyle(color: Colors.white38, fontSize: 13)),
              ]),
            )
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusChip(state: engine.simState),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.6,
            children: [
              _MetricCard('パケット成功率', '${stats.successRate.toStringAsFixed(1)}%', Icons.check_circle_outline, Colors.green),
              _MetricCard('平均レイテンシ', '${stats.avgLatencyMs.toStringAsFixed(1)} ms', Icons.timer_outlined, Colors.blue),
              _MetricCard('合計パケット数', '$total', Icons.show_chart, Colors.orange),
              _MetricCard('パケットロス率', '${stats.lossRate.toStringAsFixed(1)}%', Icons.error_outline, Colors.red),
            ],
          ),
          const SizedBox(height: 16),
          Text('パケット概要', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _SummaryRow('合計', total),
          _SummaryRow('到達', stats.deliveredPackets, color: Colors.green),
          _SummaryRow('ドロップ', stats.droppedPackets, color: Colors.red),
          // ── Attack stats section ────────────────────────────────────
          if (engine.attackResults.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.security, size: 18, color: Colors.purple),
              const SizedBox(width: 6),
              Text('セキュリティテスト統計',
                  style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 8),
            Builder(builder: (ctx) {
              final atkResults = engine.attackResults;
              final sent     = atkResults.fold(0, (s, r) => s + r.packetsGenerated);
              final detected = atkResults.where((r) => r.detectedBy.isNotEmpty).length;
              final blocked  = atkResults.where((r) => r.packetsBlocked > 0).length;
              final blockRate = detected == 0 ? 0.0 : blocked / detected * 100;
              return GridView.count(
                crossAxisCount: 2, shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.6,
                children: [
                  _MetricCard('攻撃パケット総数', '$sent', Icons.send, Colors.purple),
                  _MetricCard('IDS検知数', '$detected', Icons.radar, Colors.orange),
                  _MetricCard('IPS遮断数', '$blocked', Icons.block, Colors.red),
                  _MetricCard('遮断率', '${blockRate.toStringAsFixed(1)}%',
                      Icons.shield, blockRate > 80 ? Colors.green : Colors.amber),
                ],
              );
            }),
            const SizedBox(height: 12),
            _AttackTypeChart(
              typeCount: Map.fromEntries(
                AttackType.values.map((t) {
                  final n = engine.attackResults.where((r) => r.attackType == t).length;
                  return MapEntry(t, n);
                }).where((e) => e.value > 0),
              ),
            ),
            const SizedBox(height: 8),
          ],
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
      FittedBox(fit: BoxFit.scaleDown,
          child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color))),
      FittedBox(fit: BoxFit.scaleDown,
          child: Text(label, style: const TextStyle(fontSize: 10), textAlign: TextAlign.center)),
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

class _AttackTypeChart extends StatelessWidget {
  final Map<AttackType, int> typeCount;
  const _AttackTypeChart({required this.typeCount});

  @override
  Widget build(BuildContext context) {
    if (typeCount.isEmpty) return const SizedBox.shrink();
    final maxCount = typeCount.values.reduce(max).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('攻撃タイプ別実行回数',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          ...typeCount.entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              SizedBox(width: 130,
                  child: Text(e.key.label,
                      style: const TextStyle(fontSize: 11),
                      overflow: TextOverflow.ellipsis)),
              Expanded(child: LinearProgressIndicator(
                value: maxCount == 0 ? 0 : e.value / maxCount,
                backgroundColor: Colors.white12,
                color: Colors.purple,
                minHeight: 10,
              )),
              const SizedBox(width: 8),
              Text('${e.value}', style: const TextStyle(fontSize: 11)),
            ]),
          )),
        ]),
      ),
    );
  }
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
