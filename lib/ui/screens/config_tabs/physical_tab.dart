// lib/ui/screens/config_tabs/physical_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/device.dart';
import '../../../models/network_interface.dart';
import '../topology_state.dart';
import '../../widgets/bandwidth_selector.dart';

class PhysicalTab extends ConsumerWidget {
  final Device device;
  const PhysicalTab({super.key, required this.device});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void addInterface() {
      final n = device.interfaces.length;
      ref.read(topologyProvider.notifier).updateInterface(device.id, n,
          NetworkInterface(name: 'eth$n', ip: '0.0.0.0', subnet: 24,
              mac: TopologyNotifier.generateMac()));
    }

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
        children: device.interfaces.asMap().entries.map((e) => _IfaceCard(
          device: device, iface: e.value, index: e.key,
          onChanged: (updated) => ref.read(topologyProvider.notifier)
              .updateInterface(device.id, e.key, updated),
        )).toList(),
      ),
      bottomSheet: SizedBox(
        height: 56, width: double.infinity,
        child: FilledButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('インターフェース追加'),
          style: FilledButton.styleFrom(
              shape: const RoundedRectangleBorder()),
          onPressed: addInterface,
        ),
      ),
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
  late final TextEditingController _ip, _subnet, _mac, _mtu;
  late int _bandwidth;
  late Duplex _duplex;

  @override
  void initState() {
    super.initState();
    _ip        = TextEditingController(text: widget.iface.ip);
    _subnet    = TextEditingController(text: widget.iface.subnet.toString());
    _mac       = TextEditingController(text: widget.iface.mac);
    _mtu       = TextEditingController(text: widget.iface.mtu.toString());
    _bandwidth = widget.iface.bandwidth;
    _duplex    = widget.iface.duplex;
  }

  @override
  void dispose() {
    _ip.dispose(); _subnet.dispose(); _mac.dispose(); _mtu.dispose();
    super.dispose();
  }

  static final _ipRe = RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$');

  void _save() {
    final ip = _ip.text.trim();
    if (!_ipRe.hasMatch(ip)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('IPアドレスの形式が正しくありません'),
          backgroundColor: Colors.red));
      return;
    }
    final mtu = int.tryParse(_mtu.text.trim()) ?? 1500;
    widget.onChanged(widget.iface.copyWith(
      ip:        ip,
      subnet:    int.tryParse(_subnet.text.trim()) ?? 24,
      mac:       _mac.text.trim(),
      bandwidth: _bandwidth,
      mtu:       mtu.clamp(576, 9000),
      duplex:    _duplex,
    ));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✓ 設定を保存しました'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final isUp = widget.iface.status == InterfaceStatus.up;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header: name + up/down switch ─────────────────────────────
          Row(children: [
            Icon(Icons.cable, color: isUp ? Colors.green : Colors.red, size: 18),
            const SizedBox(width: 8),
            Text(widget.iface.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Spacer(),
            Switch(
              value: isUp,
              onChanged: (v) => widget.onChanged(widget.iface.copyWith(
                  status: v ? InterfaceStatus.up : InterfaceStatus.down)),
            ),
            Text(isUp ? 'Up' : 'Down',
                style: TextStyle(
                    color: isUp ? Colors.green : Colors.red, fontSize: 12)),
          ]),
          const SizedBox(height: 8),

          // ── IP / Subnet / MAC ─────────────────────────────────────────
          _field('IPアドレス', _ip, '192.168.1.1', TextInputType.number),
          const SizedBox(height: 6),
          _field('サブネット (CIDR)', _subnet, '24', TextInputType.number),
          const SizedBox(height: 6),
          _field('MACアドレス', _mac, 'AA:BB:CC:DD:EE:FF', TextInputType.text),
          const SizedBox(height: 10),

          // ── Bandwidth ─────────────────────────────────────────────────
          const Text('帯域上限', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          BandwidthSelector(
            currentBandwidth: _bandwidth,
            onChanged: (v) => setState(() => _bandwidth = v),
          ),
          const SizedBox(height: 10),

          // ── MTU ───────────────────────────────────────────────────────
          TextField(
            controller: _mtu,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'MTU (576〜9000)',
              hintText: '1500',
              border: const OutlineInputBorder(),
              isDense: true,
              errorText: () {
                final v = int.tryParse(_mtu.text);
                if (v == null) return null;
                return (v < 576 || v > 9000) ? '576〜9000 の範囲で入力' : null;
              }(),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 10),

          // ── Duplex ────────────────────────────────────────────────────
          const Text('デュプレックス', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: Duplex.values.map((d) => ChoiceChip(
              label: Text(d == Duplex.full ? 'Full' : 'Half'),
              selected: _duplex == d,
              onSelected: (_) => setState(() => _duplex = d),
            )).toList(),
          ),
          const SizedBox(height: 10),

          // ── Save ──────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: _save, child: const Text('保存')),
          ),
        ]),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint,
          TextInputType kbType) =>
      TextField(
          controller: ctrl,
          keyboardType: kbType,
          onSubmitted: (_) => _save(),
          decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              border: const OutlineInputBorder(),
              isDense: true));
}
