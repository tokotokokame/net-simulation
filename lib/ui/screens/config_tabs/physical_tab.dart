// lib/ui/screens/config_tabs/physical_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/device.dart';
import '../../../models/network_interface.dart';
import '../topology_state.dart';

class PhysicalTab extends ConsumerWidget {
  final Device device;
  const PhysicalTab({super.key, required this.device});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        ...device.interfaces.asMap().entries.map((e) => _IfaceCard(
          device: device, iface: e.value, index: e.key,
          onChanged: (updated) => ref.read(topologyProvider.notifier)
              .updateInterface(device.id, e.key, updated),
        )),
        const SizedBox(height: 8),
        FilledButton.icon(
          icon: const Icon(Icons.add), label: const Text('インターフェース追加'),
          onPressed: () {
            final n = device.interfaces.length;
            ref.read(topologyProvider.notifier).updateInterface(device.id, n,
                NetworkInterface(name: 'eth$n', ip: '0.0.0.0', subnet: 24,
                    mac: 'AA:BB:CC:DD:EE:${n.toRadixString(16).padLeft(2, '0').toUpperCase()}'));
          },
        ),
      ],
    );
  }
}

// ── Editable interface card ───────────────────────────────────────────────────

class _IfaceCard extends StatefulWidget {
  final Device device;
  final NetworkInterface iface;
  final int index;
  final void Function(NetworkInterface) onChanged;
  const _IfaceCard({required this.device, required this.iface, required this.index, required this.onChanged});

  @override
  State<_IfaceCard> createState() => _IfaceCardState();
}

class _IfaceCardState extends State<_IfaceCard> {
  late final TextEditingController _ip, _subnet, _mac;

  @override
  void initState() {
    super.initState();
    _ip = TextEditingController(text: widget.iface.ip);
    _subnet = TextEditingController(text: widget.iface.subnet.toString());
    _mac = TextEditingController(text: widget.iface.mac);
  }

  @override
  void dispose() { _ip.dispose(); _subnet.dispose(); _mac.dispose(); super.dispose(); }

  void _save() => widget.onChanged(widget.iface.copyWith(
    ip: _ip.text.trim(),
    subnet: int.tryParse(_subnet.text.trim()) ?? 24,
    mac: _mac.text.trim(),
  ));

  @override
  Widget build(BuildContext context) {
    final isUp = widget.iface.status == InterfaceStatus.up;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.cable, color: isUp ? Colors.green : Colors.red, size: 18),
            const SizedBox(width: 8),
            Text(widget.iface.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Spacer(),
            Switch(value: isUp, onChanged: (v) => widget.onChanged(widget.iface.copyWith(
                status: v ? InterfaceStatus.up : InterfaceStatus.down))),
            Text(isUp ? 'Up' : 'Down',
                style: TextStyle(color: isUp ? Colors.green : Colors.red, fontSize: 12)),
          ]),
          const SizedBox(height: 8),
          _field('IPアドレス', _ip, '192.168.1.1', TextInputType.number),
          const SizedBox(height: 6),
          _field('サブネット (CIDR)', _subnet, '24', TextInputType.number),
          const SizedBox(height: 6),
          _field('MACアドレス', _mac, 'AA:BB:CC:DD:EE:FF', TextInputType.text),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity,
              child: ElevatedButton(onPressed: _save, child: const Text('保存'))),
        ]),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint, TextInputType kbType) =>
      TextField(controller: ctrl, keyboardType: kbType, onSubmitted: (_) => _save(),
          decoration: InputDecoration(labelText: label, hintText: hint,
              border: const OutlineInputBorder(), isDense: true));
}
