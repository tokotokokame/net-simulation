// lib/ui/screens/config_tabs/qos_tab.dart
import 'package:flutter/material.dart';
import '../../../models/device.dart';
import '../../../models/packet.dart';
import '../../../simulation/queue_discipline.dart';

class QosTab extends StatefulWidget {
  final Device device;
  const QosTab({super.key, required this.device});
  @override
  State<QosTab> createState() => _QosTabState();
}

class _QosTabState extends State<QosTab> {
  // ── Queue ──────────────────────────────────────────────────────────────────
  QueueDiscipline _discipline = QueueDiscipline.fifo;
  int _queueSize = 100;
  bool _useRed = false;
  double _redMin = 0.30;
  double _redMax = 0.80;

  // ── PQ priority protocols ──────────────────────────────────────────────────
  final _high   = <ProtocolType>{ProtocolType.ospf, ProtocolType.bgp};
  final _normal = <ProtocolType>{ProtocolType.tcp};
  final _low    = <ProtocolType>{ProtocolType.udp};

  // ── DSCP ──────────────────────────────────────────────────────────────────
  bool _dscpEnabled = false;
  double _dscpValue = 0;
  final _dscpRules  = <_DscpRule>[];
  final _dscpSrcCtrl = TextEditingController();

  @override
  void dispose() { _dscpSrcCtrl.dispose(); super.dispose(); }

  static const _allProtos = ProtocolType.values;
  static String _protoLabel(ProtocolType p) => p.name.toUpperCase();

  Widget _sectionHeader(String t) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 4),
    child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
        color: Colors.blueGrey)),
  );

  // ── Protocol multi-select row ──────────────────────────────────────────────
  Widget _protoSelect(String label, Set<ProtocolType> selected, Color color) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Wrap(spacing: 6, children: _allProtos.map((p) => FilterChip(
          label: Text(_protoLabel(p), style: const TextStyle(fontSize: 11)),
          selected: selected.contains(p),
          selectedColor: color.withValues(alpha: 0.25),
          onSelected: (on) => setState(() => on ? selected.add(p) : selected.remove(p)),
        )).toList()),
      ]);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ── Section 1: Queue ─────────────────────────────────────────────
        _sectionHeader('キュー設定'),
        Wrap(
          spacing: 8, runSpacing: 4,
          children: QueueDiscipline.values.map((d) => ChoiceChip(
            label: Text(switch (d) {
              QueueDiscipline.fifo => 'FIFO',
              QueueDiscipline.pq   => 'Priority Queuing',
              QueueDiscipline.wfq  => 'WFQ',
            }, style: const TextStyle(fontSize: 12)),
            selected: _discipline == d,
            onSelected: (_) => setState(() => _discipline = d),
          )).toList(),
        ),
        const SizedBox(height: 8),
        Row(children: [
          const Text('キューサイズ: ', style: TextStyle(fontSize: 12)),
          Text('$_queueSize pkt', style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        Slider(value: _queueSize.toDouble(), min: 10, max: 1000, divisions: 99,
            label: '$_queueSize',
            onChanged: (v) => setState(() => _queueSize = v.round())),
        const SizedBox(height: 4),
        const Text('輻輳制御', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Wrap(spacing: 8, children: [
          ChoiceChip(label: const Text('Tail Drop'), selected: !_useRed,
              onSelected: (_) => setState(() => _useRed = false)),
          ChoiceChip(label: const Text('RED'), selected: _useRed,
              onSelected: (_) => setState(() => _useRed = true)),
        ]),
        if (_useRed) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Text('min_thresh: ', style: TextStyle(fontSize: 12)),
            Text('${(_redMin * 100).round()}%',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
          Slider(value: _redMin, min: 0.1, max: 0.5, divisions: 8,
              label: '${(_redMin * 100).round()}%',
              onChanged: (v) => setState(() => _redMin = v < _redMax ? v : _redMax - 0.1)),
          Row(children: [
            const Text('max_thresh: ', style: TextStyle(fontSize: 12)),
            Text('${(_redMax * 100).round()}%',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
          Slider(value: _redMax, min: 0.5, max: 1.0, divisions: 10,
              label: '${(_redMax * 100).round()}%',
              onChanged: (v) => setState(() => _redMax = v > _redMin ? v : _redMin + 0.1)),
        ],

        // ── Section 2: PQ priorities (PQ only) ──────────────────────────
        if (_discipline == QueueDiscipline.pq) ...[
          _sectionHeader('優先度設定 (PQ)'),
          _protoSelect('High優先度', _high,   Colors.red),
          const SizedBox(height: 8),
          _protoSelect('Normal優先度', _normal, Colors.blue),
          const SizedBox(height: 8),
          _protoSelect('Low優先度',  _low,    Colors.grey),
        ],

        // ── Section 3: DSCP ──────────────────────────────────────────────
        _sectionHeader('DSCPマーキング'),
        SwitchListTile(dense: true, title: const Text('DSCP有効'),
            value: _dscpEnabled,
            onChanged: (v) => setState(() => _dscpEnabled = v)),
        if (_dscpEnabled) ...[
          Row(children: [
            const Text('DSCP値: ', style: TextStyle(fontSize: 12)),
            Text('${_dscpValue.round()} (${_dscpLabel(_dscpValue.round())})',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
          Slider(value: _dscpValue, min: 0, max: 63, divisions: 63,
              label: '${_dscpValue.round()}',
              onChanged: (v) => setState(() => _dscpValue = v)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(
              controller: _dscpSrcCtrl,
              decoration: const InputDecoration(labelText: '送信元IP',
                  hintText: '192.168.1.0/24', isDense: true,
                  border: OutlineInputBorder()),
            )),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                final src = _dscpSrcCtrl.text.trim();
                if (src.isEmpty) return;
                setState(() {
                  _dscpRules.add(_DscpRule(src, _dscpValue.round()));
                  _dscpSrcCtrl.clear();
                });
              },
              child: const Text('追加'),
            ),
          ]),
          const SizedBox(height: 8),
          ..._dscpRules.map((r) => ListTile(dense: true,
            title: Text('${r.src}  →  DSCP ${r.dscp} (${_dscpLabel(r.dscp)})'),
            trailing: IconButton(icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: () => setState(() => _dscpRules.remove(r))),
          )),
        ],
      ],
    );
  }

  static String _dscpLabel(int v) => switch (v) {
        0  => 'BE',
        8  => 'CS1', 16 => 'CS2', 24 => 'CS3',
        32 => 'CS4', 40 => 'CS5', 48 => 'CS6', 56 => 'CS7',
        10 => 'AF11', 12 => 'AF12', 14 => 'AF13',
        18 => 'AF21', 20 => 'AF22', 22 => 'AF23',
        26 => 'AF31', 28 => 'AF32', 30 => 'AF33',
        34 => 'AF41', 36 => 'AF42', 38 => 'AF43',
        46 => 'EF',
        _  => 'CS${v ~/ 8}',
      };
}

class _DscpRule {
  final String src;
  final int dscp;
  const _DscpRule(this.src, this.dscp);
}
