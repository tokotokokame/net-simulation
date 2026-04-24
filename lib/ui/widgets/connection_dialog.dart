// lib/ui/widgets/connection_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/device.dart';
import '../../models/link.dart';
import '../../models/network_interface.dart' show NetworkInterface, InterfaceStatus;
import 'bandwidth_selector.dart';

typedef OnConnect = void Function(
    String ifA, String ifB, LinkType type,
    int bandwidth, double latency, double packetLoss);

typedef OnLinkUpdate = void Function(
    LinkType type, int bandwidth, double latency, double packetLoss);

class ConnectionDialog extends StatefulWidget {
  final Device deviceA;
  final Device deviceB;
  final OnConnect onConnect;

  /// Pre-filled values when editing an existing link.
  final Link? existingLink;
  final OnLinkUpdate? onLinkUpdate;

  const ConnectionDialog({
    super.key,
    required this.deviceA,
    required this.deviceB,
    required this.onConnect,
    this.existingLink,
    this.onLinkUpdate,
  });

  static Future<void> show(
      BuildContext context, Device a, Device b, OnConnect cb) =>
      showDialog(
          context: context,
          builder: (_) => ConnectionDialog(deviceA: a, deviceB: b, onConnect: cb));

  /// Opens dialog to edit an existing link's parameters.
  static Future<void> showForLink(
      BuildContext context, Device a, Device b, Link link, OnLinkUpdate cb) =>
      showDialog(
          context: context,
          builder: (_) => ConnectionDialog(
              deviceA: a, deviceB: b,
              onConnect: (_, __, ___, ____, _____, ______) {},
              existingLink: link, onLinkUpdate: cb));

  @override
  State<ConnectionDialog> createState() => _ConnectionDialogState();
}

class _ConnectionDialogState extends State<ConnectionDialog> {
  String? _ifA, _ifB;
  late LinkType _linkType;
  late int _bandwidth;
  late double _latency;
  late double _packetLoss;
  final _latencyCtrl = TextEditingController();

  bool get _editing => widget.existingLink != null;

  @override
  void initState() {
    super.initState();
    final ex = widget.existingLink;
    _linkType   = ex?.type        ?? LinkType.standard;
    _bandwidth  = ex?.bandwidth   ?? 10485760; // 10 MB/s default
    _latency    = ex?.latency     ?? 1.0;
    _packetLoss = ex?.packetLoss  ?? 0.0;
    if (_editing) {
      _ifA = ex!.interfaceAName;
      _ifB = ex.interfaceBName;
    }
    _latencyCtrl.text = _latency.toStringAsFixed(1);
  }

  @override
  void dispose() { _latencyCtrl.dispose(); super.dispose(); }

  List<NetworkInterface> get _ifsA => widget.deviceA.interfaces;
  List<NetworkInterface> get _ifsB => widget.deviceB.interfaces;

  void _confirm() {
    Navigator.pop(context);
    if (_editing) {
      widget.onLinkUpdate?.call(_linkType, _bandwidth, _latency, _packetLoss);
    } else {
      widget.onConnect(_ifA!, _ifB!, _linkType, _bandwidth, _latency, _packetLoss);
    }
  }

  bool get _canConfirm => _editing || (_ifA != null && _ifB != null);

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(
            _editing
                ? '${widget.deviceA.name} ↔ ${widget.deviceB.name}（編集）'
                : '${widget.deviceA.name} ↔ ${widget.deviceB.name}',
            style: const TextStyle(fontSize: 15)),
        content: SizedBox(
          width: 340,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Interface pickers (new link only) ────────────────────
                if (!_editing) ...[
                  Row(children: [
                    Expanded(child: _IfPicker(label: widget.deviceA.name,
                        interfaces: _ifsA, selected: _ifA,
                        onChanged: (v) => setState(() => _ifA = v))),
                    const SizedBox(width: 8),
                    Expanded(child: _IfPicker(label: widget.deviceB.name,
                        interfaces: _ifsB, selected: _ifB,
                        onChanged: (v) => setState(() => _ifB = v))),
                  ]),
                  const SizedBox(height: 12),
                ],
                // ── Link type ────────────────────────────────────────────
                SegmentedButton<LinkType>(
                  segments: const [
                    ButtonSegment(value: LinkType.standard, label: Text('標準'), icon: Icon(Icons.cable)),
                    ButtonSegment(value: LinkType.logical,  label: Text('論理'), icon: Icon(Icons.route)),
                  ],
                  selected: {_linkType},
                  onSelectionChanged: (s) => setState(() => _linkType = s.first),
                ),
                const SizedBox(height: 12),
                // ── Bandwidth ────────────────────────────────────────────
                const Text('帯域幅', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                BandwidthSelector(
                  currentBandwidth: _bandwidth,
                  onChanged: (v) => setState(() => _bandwidth = v),
                ),
                const SizedBox(height: 12),
                // ── Latency ──────────────────────────────────────────────
                TextField(
                  controller: _latencyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: const InputDecoration(
                    labelText: 'レイテンシ (ms)',
                    hintText: '1.0',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    final d = double.tryParse(v);
                    if (d != null) setState(() => _latency = d.clamp(0, 1000));
                  },
                ),
                const SizedBox(height: 12),
                // ── Packet loss ──────────────────────────────────────────
                Row(children: [
                  const Text('パケットロス率', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('${(_packetLoss * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 12)),
                ]),
                Slider(
                  value: _packetLoss,
                  min: 0, max: 0.5, divisions: 50,
                  label: '${(_packetLoss * 100).toStringAsFixed(1)}%',
                  onChanged: (v) => setState(() => _packetLoss = v),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
          FilledButton(
            onPressed: _canConfirm ? _confirm : null,
            child: Text(_editing ? '更新' : '接続'),
          ),
        ],
      );
}

// ── Interface picker ──────────────────────────────────────────────────────────

class _IfPicker extends StatelessWidget {
  final String label;
  final List<NetworkInterface> interfaces;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _IfPicker({
    required this.label,
    required this.interfaces,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      ...interfaces.map((iface) => _IfTile(iface: iface, selected: selected == iface.name,
          onTap: () => onChanged(selected == iface.name ? null : iface.name))),
    ],
  );
}

class _IfTile extends StatelessWidget {
  final NetworkInterface iface;
  final bool selected;
  final VoidCallback onTap;
  const _IfTile({required this.iface, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isUp = iface.status == InterfaceStatus.up;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: selected ? Colors.blue.withValues(alpha: 0.15) : null,
          border: Border.all(color: selected ? Colors.blue : Colors.grey[300]!),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(children: [
          Icon(Icons.circle, size: 8, color: isUp ? Colors.green : Colors.red),
          const SizedBox(width: 4),
          Expanded(child: Text(iface.name, style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }
}
