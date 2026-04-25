// lib/ui/screens/config_tabs/ids_rules_tab.dart
import 'package:flutter/material.dart';
import '../../../models/device.dart';

class IdsRulesTab extends StatefulWidget {
  final Device device;
  const IdsRulesTab({super.key, required this.device});
  @override
  State<IdsRulesTab> createState() => _IdsRulesTabState();
}

class _IdsRulesTabState extends State<IdsRulesTab> {
  final _rules = [
    _Rule(name: 'SYNフラッド検知', type: 'syn_flood', enabled: true, threshold: 50, action: 'alert'),
    _Rule(name: 'ポートスキャン検知', type: 'port_scan', enabled: true, threshold: 10, action: 'alert'),
    _Rule(name: 'ARPスプーフィング検知', type: 'arp_spoof', enabled: true, threshold: 3, action: 'block'),
  ];

  void _addCustomRule() {
    setState(() => _rules.add(_Rule(
      name: 'カスタムルール-${_rules.length + 1}',
      type: 'custom', enabled: true, threshold: 100, action: 'alert',
    )));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(12), children: [
      Text('検知ルール', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.grey)),
      const SizedBox(height: 8),
      ..._rules.asMap().entries.map((e) {
        final rule = e.value;
        return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(rule.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
              Switch(value: rule.enabled,
                  onChanged: (v) => setState(() => _rules[e.key] = rule.copyWith(enabled: v))),
            ]),
            const SizedBox(height: 4),
            Text('タイプ: ${rule.type}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 8),
            Row(children: [
              const Text('閾値:', style: TextStyle(fontSize: 12)),
              Expanded(child: Slider(
                value: rule.threshold.toDouble(),
                min: 1, max: 500, divisions: 50,
                label: '${rule.threshold}',
                onChanged: (v) => setState(
                    () => _rules[e.key] = rule.copyWith(threshold: v.round())),
              )),
              SizedBox(width: 36,
                  child: Text('${rule.threshold}', style: const TextStyle(fontSize: 12))),
            ]),
            const SizedBox(height: 4),
            const Text('アクション:', style: TextStyle(fontSize: 12)),
            Wrap(spacing: 6, children: ['alert', 'block', 'rate_limit'].map((a) =>
              ChoiceChip(
                label: Text(a, style: const TextStyle(fontSize: 11)),
                selected: rule.action == a,
                onSelected: (_) => setState(
                    () => _rules[e.key] = rule.copyWith(action: a)),
              )).toList()),
          ]),
        ));
      }),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        icon: const Icon(Icons.add),
        label: const Text('カスタムルール追加'),
        onPressed: _addCustomRule,
      ),
    ]);
  }
}

class _Rule {
  final String name, type, action;
  final bool enabled;
  final int threshold;
  const _Rule({required this.name, required this.type, required this.enabled,
      required this.threshold, required this.action});
  _Rule copyWith({String? name, String? type, bool? enabled, int? threshold, String? action}) =>
      _Rule(name: name ?? this.name, type: type ?? this.type, enabled: enabled ?? this.enabled,
          threshold: threshold ?? this.threshold, action: action ?? this.action);
}
