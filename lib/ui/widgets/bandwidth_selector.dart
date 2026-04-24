// lib/ui/widgets/bandwidth_selector.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Presets ───────────────────────────────────────────────────────────────────

class _Preset {
  final String label;
  final int bytesPerSec;
  const _Preset(this.label, this.bytesPerSec);
}

const _presets = [
  _Preset('50 KB/s',   51200),
  _Preset('100 KB/s',  102400),
  _Preset('512 KB/s',  524288),
  _Preset('1 MB/s',    1048576),
  _Preset('10 MB/s',   10485760),
  _Preset('100 MB/s',  104857600),
  _Preset('1 GB/s',    1073741824),
];

const _kMin = 51200;        // 50 KB/s
const _kMax = 1073741824;   // 1 GB/s

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Formats [bytesPerSec] as a human-readable string (e.g. "10 MB/s").
String formatBandwidth(int bytesPerSec) {
  if (bytesPerSec >= 1073741824) {
    return '${(bytesPerSec / 1073741824).toStringAsFixed(bytesPerSec % 1073741824 == 0 ? 0 : 1)} GB/s';
  }
  if (bytesPerSec >= 1048576) {
    return '${(bytesPerSec / 1048576).toStringAsFixed(bytesPerSec % 1048576 == 0 ? 0 : 1)} MB/s';
  }
  return '${(bytesPerSec / 1024).toStringAsFixed(bytesPerSec % 1024 == 0 ? 0 : 1)} KB/s';
}

// ── Widget ────────────────────────────────────────────────────────────────────

class BandwidthSelector extends StatefulWidget {
  final int currentBandwidth;
  final ValueChanged<int> onChanged;

  const BandwidthSelector({
    super.key,
    required this.currentBandwidth,
    required this.onChanged,
  });

  @override
  State<BandwidthSelector> createState() => _BandwidthSelectorState();
}

class _BandwidthSelectorState extends State<BandwidthSelector> {
  late bool _custom;
  late int _value;
  final _ctrl = TextEditingController();
  int _unit = 1024; // KB/s by default

  @override
  void initState() {
    super.initState();
    _value = widget.currentBandwidth;
    _custom = !_presets.any((p) => p.bytesPerSec == _value);
    if (_custom) _ctrl.text = (_value ~/ _unit).toString();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  int? get _presetIndex =>
      _presets.indexWhere((p) => p.bytesPerSec == _value).let((i) => i >= 0 ? i : null);

  void _selectPreset(int index) {
    setState(() { _custom = false; _value = _presets[index].bytesPerSec; });
    widget.onChanged(_value);
  }

  void _applyCustom() {
    final n = int.tryParse(_ctrl.text.trim());
    if (n == null) return;
    final bps = (n * _unit).clamp(_kMin, _kMax);
    setState(() => _value = bps);
    widget.onChanged(bps);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Preset chips ───────────────────────────────────────────────────
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            ..._presets.asMap().entries.map((e) => ChoiceChip(
                  label: Text(e.value.label,
                      style: const TextStyle(fontSize: 11)),
                  selected: !_custom && _presetIndex == e.key,
                  onSelected: (_) => _selectPreset(e.key),
                )),
            ChoiceChip(
              label: const Text('カスタム', style: TextStyle(fontSize: 11)),
              selected: _custom,
              onSelected: (_) {
                setState(() {
                  _custom = true;
                  _ctrl.text = (_value ~/ _unit).toString();
                });
              },
            ),
          ],
        ),
        // ── Custom input ───────────────────────────────────────────────────
        if (_custom) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: '帯域幅',
                  hintText: '例: 100',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  errorText: () {
                    final n = int.tryParse(_ctrl.text);
                    if (n == null) return null;
                    final bps = n * _unit;
                    if (bps < _kMin || bps > _kMax) return '50KB〜1GB';
                    return null;
                  }(),
                ),
                onSubmitted: (_) => _applyCustom(),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1024,       label: Text('KB/s')),
                ButtonSegment(value: 1048576,    label: Text('MB/s')),
                ButtonSegment(value: 1073741824, label: Text('GB/s')),
              ],
              selected: {_unit},
              onSelectionChanged: (s) {
                setState(() => _unit = s.first);
                _applyCustom();
              },
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _applyCustom,
              child: const Text('適用'),
            ),
          ]),
        ],
        // ── Current value display ──────────────────────────────────────────
        const SizedBox(height: 4),
        Text('現在: ${formatBandwidth(_value)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}

extension<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
