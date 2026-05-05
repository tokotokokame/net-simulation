// lib/ui/screens/scenario_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../scenarios/scenario_list.dart';
import '../../scenarios/scenario_data.dart';

class ScenarioScreen extends StatelessWidget {
  const ScenarioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = kScenarios.map((s) => s.category).toSet().toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        title: const Text('シナリオ学習'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.white12),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2D3D),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.school, color: Color(0xFF64B5F6), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'シナリオを選んでステップごとに学習できます。\n'
                      '解説パネルで「なぜそうなるか」を確認しながら進めましょう。',
                      style: TextStyle(
                          fontSize: 12, color: Colors.white70, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ...categories.map((cat) {
              final items =
                  kScenarios.where((s) => s.category == cat).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(cat,
                        style: const TextStyle(
                          color: Color(0xFF64B5F6),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        )),
                  ),
                  ...items.map((s) => _ScenarioCard(scenario: s)),
                  const SizedBox(height: 20),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  final ScenarioData scenario;
  const _ScenarioCard({required this.scenario});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/scenario/${scenario.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2D3D),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scenario.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(scenario.icon, color: scenario.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(scenario.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(scenario.description,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _diffColor(scenario.difficulty).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(scenario.difficulty,
                      style: TextStyle(
                          color: _diffColor(scenario.difficulty),
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 4),
                Text('${scenario.steps.length}ステップ',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _diffColor(String d) => switch (d) {
        '初級' => const Color(0xFF4CAF50),
        '中級' => const Color(0xFFFF9800),
        _ => const Color(0xFFF44336),
      };
}
