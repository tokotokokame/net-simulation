// lib/ui/screens/scenario_play_screen.dart
import 'package:flutter/material.dart';
import '../../scenarios/scenario_data.dart';
import '../../scenarios/scenario_list.dart';

class ScenarioPlayScreen extends StatefulWidget {
  final String id;
  const ScenarioPlayScreen({super.key, required this.id});

  @override
  State<ScenarioPlayScreen> createState() => _ScenarioPlayScreenState();
}

class _ScenarioPlayScreenState extends State<ScenarioPlayScreen> {
  int  _currentStep    = 0;
  bool _showExplanation = true;

  ScenarioData get _scenario =>
      kScenarios.firstWhere((s) => s.id == widget.id);

  ScenarioStep get _step => _scenario.steps[_currentStep];

  bool get _isLast => _currentStep == _scenario.steps.length - 1;

  @override
  Widget build(BuildContext context) {
    final scenario = _scenario;
    final step     = _step;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        title: Text(scenario.title,
            style: const TextStyle(fontSize: 15)),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_currentStep + 1} / ${scenario.steps.length}',
                style: const TextStyle(
                    color: Colors.white54, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_currentStep + 1) / scenario.steps.length,
              backgroundColor: Colors.white12,
              color: scenario.color,
              minHeight: 3,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ステップタイトル
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: scenario.color,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text('${_currentStep + 1}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(step.title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 指示カード
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2D3D),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: scenario.color.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.task_alt,
                                color: scenario.color, size: 16),
                            const SizedBox(width: 6),
                            Text('やること',
                                style: TextStyle(
                                    color: scenario.color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ]),
                          const SizedBox(height: 8),
                          Text(step.instruction,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  height: 1.6)),
                          if (step.cliHint != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  const Text('\$ ',
                                      style: TextStyle(
                                          color: Color(0xFF00FF41),
                                          fontFamily: 'monospace',
                                          fontSize: 13)),
                                  Text(step.cliHint!,
                                      style: const TextStyle(
                                          color: Color(0xFF00FF41),
                                          fontFamily: 'monospace',
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 解説パネル（トグル）
                    GestureDetector(
                      onTap: () => setState(
                          () => _showExplanation = !_showExplanation),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A1929),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(children: [
                                  Icon(Icons.lightbulb_outline,
                                      color: Color(0xFFFFC107), size: 16),
                                  SizedBox(width: 6),
                                  Text('解説',
                                      style: TextStyle(
                                          color: Color(0xFFFFC107),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                ]),
                                Icon(
                                  _showExplanation
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: Colors.white38,
                                  size: 18),
                              ],
                            ),
                            if (_showExplanation) ...[
                              const SizedBox(height: 8),
                              Text(step.explanation,
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                      height: 1.7)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ナビゲーションボタン
            Container(
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16,
                  MediaQuery.of(context).padding.bottom + 12),
              decoration: const BoxDecoration(
                color: Color(0xFF0D1B2A),
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            setState(() => _currentStep--),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white54,
                          side: const BorderSide(color: Colors.white24),
                        ),
                        child: const Text('← 前へ'),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLast
                          ? () => Navigator.pop(context)
                          : () => setState(() {
                                _currentStep++;
                                _showExplanation = true;
                              }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scenario.color,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(_isLast ? '✓ 完了' : '次へ →'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
