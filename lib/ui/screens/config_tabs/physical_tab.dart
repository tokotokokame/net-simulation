// lib/ui/screens/config_tabs/physical_tab.dart
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/device.dart';
import '../../../models/network_interface.dart';
import '../topology_state.dart';
import '../../widgets/bandwidth_selector.dart';

// ── Physical capabilities per device type ────────────────────────────────────

class _PhysicalCaps {
  final bool showMac;
  final bool showBandwidth;
  final bool bandwidthEditable;
  final bool showMtu;
  final bool showDuplex;
  final String? duplexFixed; // non-null = fixed label, no selector
  final bool canAddInterface;

  const _PhysicalCaps({
    this.showMac           = true,
    this.showBandwidth     = true,
    this.bandwidthEditable = true,
    this.showMtu           = false,
    this.showDuplex        = false,
    this.duplexFixed,
    this.canAddInterface   = false,
  });
}

_PhysicalCaps _caps(DeviceType t) => switch (t) {
  // Endpoints
  DeviceType.pc || DeviceType.laptop =>
      const _PhysicalCaps(showMac: true),
  DeviceType.server =>
      const _PhysicalCaps(showMac: true, showMtu: true, canAddInterface: true),
  DeviceType.iotDevice =>
      const _PhysicalCaps(showMac: true),
  // Infra
  DeviceType.router =>
      const _PhysicalCaps(showMtu: true, showDuplex: true, canAddInterface: true),
  DeviceType.l3Switch =>
      const _PhysicalCaps(showMtu: true, showDuplex: true, canAddInterface: true),
  DeviceType.switch_ =>
      const _PhysicalCaps(showDuplex: true, canAddInterface: true),
  DeviceType.hub =>
      const _PhysicalCaps(showMac: false, bandwidthEditable: false,
          duplexFixed: 'Half (固定)'),
  DeviceType.bridge =>
      const _PhysicalCaps(showMac: false),
  DeviceType.wirelessAP =>
      const _PhysicalCaps(showMac: true),
  // Security
  DeviceType.firewall =>
      const _PhysicalCaps(showMtu: true, showDuplex: true, canAddInterface: true),
  DeviceType.ids || DeviceType.ips =>
      const _PhysicalCaps(canAddInterface: true),
  DeviceType.natGateway =>
      const _PhysicalCaps(canAddInterface: true),
  // VPN / tunnels
  DeviceType.vpnGateway || DeviceType.ipSecTunnel || DeviceType.greTunnel =>
      const _PhysicalCaps(showMtu: true, showDuplex: true, canAddInterface: true),
  // SDN
  DeviceType.openFlowSwitch =>
      const _PhysicalCaps(canAddInterface: true),
  // Enterprise
  DeviceType.activeDirectoryServer =>
      const _PhysicalCaps(showMtu: true),
  // Others: minimal
  _ => const _PhysicalCaps(showMac: false, showBandwidth: false),
};

class PhysicalTab extends ConsumerStatefulWidget {
  final Device device;
  const PhysicalTab({super.key, required this.device});

  @override
  ConsumerState<PhysicalTab> createState() => _PhysicalTabState();
}

class _PhysicalTabState extends ConsumerState<PhysicalTab> {
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.device.name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _saveName() {
    final newName = _nameCtrl.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('デバイス名を入力してください')));
      return;
    }
    ref.read(topologyProvider.notifier)
        .renameDevice(deviceId: widget.device.id, newName: newName);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✓ デバイス名を保存しました'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1)));
    developer.log('[Config] renamed ${widget.device.id} → $newName');
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;
    final ifaces = device.interfaces;
    final caps   = _caps(device.type);

    void addInterface() {
      final n = device.interfaces.length;
      ref.read(topologyProvider.notifier).updateInterface(device.id, n,
          NetworkInterface(name: 'eth$n', ip: '0.0.0.0', subnet: 24,
              mac: TopologyNotifier.generateMac()));
    }

    void removeInterface(int index) {
      ref.read(topologyProvider.notifier).removeInterface(device.id, index);
    }

    // ── Name field card (all device types) ────────────────────────────────
    final nameCard = Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextFormField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: 'デバイス名',
              hintText: 'Router-1',
              prefixIcon: const Icon(Icons.label_outline, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            onFieldSubmitted: (_) => _saveName(),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
                onPressed: _saveName, child: const Text('名前を保存')),
          ),
        ]),
      ),
    );

    if (ifaces.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          nameCard,
          const SizedBox(height: 16),
          Expanded(child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('インターフェースがありません',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              if (caps.canAddInterface)
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('eth0 を追加'),
                  onPressed: addInterface,
                ),
            ]),
          )),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        nameCard,
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: ifaces.asMap().entries.map((e) => _IfaceCard(
              device: device,
              iface: e.value,
              index: e.key,
              caps: caps,
              isLast: e.key == ifaces.length - 1,
              onChanged: (updated) => ref.read(topologyProvider.notifier)
                  .updateInterface(device.id, e.key, updated),
              onAdd: caps.canAddInterface ? addInterface : null,
              onDelete: () => removeInterface(e.key),
            )).toList(),
          ),
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
  final bool isLast;
  final _PhysicalCaps caps;
  final void Function(NetworkInterface) onChanged;
  final VoidCallback? onAdd;
  final VoidCallback onDelete;

  const _IfaceCard({
    required this.device,
    required this.iface,
    required this.index,
    required this.isLast,
    required this.caps,
    required this.onChanged,
    required this.onAdd,
    required this.onDelete,
  });

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
    final caps = widget.caps;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header: name + Up/Down + delete + add ─────────────────────
          Row(children: [
            Icon(Icons.cable, color: isUp ? Colors.green : Colors.red, size: 18),
            const SizedBox(width: 6),
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
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
              onPressed: widget.onDelete,
              tooltip: 'インターフェース削除',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            if (widget.isLast && widget.onAdd != null) ...[
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.add_circle_outline,
                    color: Color(0xFF64B5F6), size: 22),
                onPressed: widget.onAdd,
                tooltip: 'インターフェース追加',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ]),
          const SizedBox(height: 8),

          // ── IP / Subnet ───────────────────────────────────────────────
          _field('IPアドレス', _ip, '192.168.1.1', TextInputType.number),
          const SizedBox(height: 6),
          _field('サブネット (CIDR)', _subnet, '24', TextInputType.number),

          // ── MAC (conditional) ─────────────────────────────────────────
          if (caps.showMac) ...[
            const SizedBox(height: 6),
            _field('MACアドレス', _mac, 'AA:BB:CC:DD:EE:FF', TextInputType.text),
          ],

          // ── Bandwidth (conditional) ───────────────────────────────────
          if (caps.showBandwidth) ...[
            const SizedBox(height: 10),
            const Text('帯域上限', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            caps.bandwidthEditable
                ? BandwidthSelector(
                    currentBandwidth: _bandwidth,
                    onChanged: (v) => setState(() => _bandwidth = v),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text('10 Mbps（固定）',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ),
          ],

          // ── MTU (conditional) ─────────────────────────────────────────
          if (caps.showMtu) ...[
            const SizedBox(height: 10),
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
          ],

          // ── Duplex (conditional) ──────────────────────────────────────
          if (caps.showDuplex) ...[
            const SizedBox(height: 10),
            const Text('デュプレックス',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: Duplex.values.map((d) => ChoiceChip(
                label: Text(d == Duplex.full ? 'Full' : 'Half'),
                selected: _duplex == d,
                onSelected: (_) => setState(() => _duplex = d),
              )).toList(),
            ),
          ] else if (caps.duplexFixed != null) ...[
            const SizedBox(height: 10),
            const Text('デュプレックス',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(caps.duplexFixed!,
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ],

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
