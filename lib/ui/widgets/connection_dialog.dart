// lib/ui/widgets/connection_dialog.dart
import 'package:flutter/material.dart';
import '../../models/device.dart';
import '../../models/link.dart';
import '../../models/network_interface.dart' show NetworkInterface, InterfaceStatus;

typedef OnConnect = void Function(String ifA, String ifB, LinkType type);

class ConnectionDialog extends StatefulWidget {
  final Device deviceA;
  final Device deviceB;
  final OnConnect onConnect;

  const ConnectionDialog({
    super.key,
    required this.deviceA,
    required this.deviceB,
    required this.onConnect,
  });

  static Future<void> show(
      BuildContext context, Device a, Device b, OnConnect cb) =>
      showDialog(context: context,
          builder: (_) => ConnectionDialog(deviceA: a, deviceB: b, onConnect: cb));

  @override
  State<ConnectionDialog> createState() => _ConnectionDialogState();
}

class _ConnectionDialogState extends State<ConnectionDialog> {
  String? _ifA, _ifB;
  LinkType _linkType = LinkType.standard;

  List<NetworkInterface> get _ifsA => widget.deviceA.interfaces;
  List<NetworkInterface> get _ifsB => widget.deviceB.interfaces;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('${widget.deviceA.name} ↔ ${widget.deviceB.name}',
            style: const TextStyle(fontSize: 15)),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              SegmentedButton<LinkType>(
                segments: const [
                  ButtonSegment(value: LinkType.standard, label: Text('標準'), icon: Icon(Icons.cable)),
                  ButtonSegment(value: LinkType.logical, label: Text('論理'), icon: Icon(Icons.route)),
                ],
                selected: {_linkType},
                onSelectionChanged: (s) => setState(() => _linkType = s.first),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
          FilledButton(
            onPressed: (_ifA != null && _ifB != null)
                ? () { Navigator.pop(context); widget.onConnect(_ifA!, _ifB!, _linkType); }
                : null,
            child: const Text('接続'),
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
          Expanded(child: Text(iface.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }
}
