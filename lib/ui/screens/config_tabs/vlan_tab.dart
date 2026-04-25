// lib/ui/screens/config_tabs/vlan_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/device.dart';

class VlanTab extends StatefulWidget {
  final Device device;
  const VlanTab({super.key, required this.device});
  @override
  State<VlanTab> createState() => _VlanTabState();
}

class _VlanTabState extends State<VlanTab> {
  final _vlans = <_Vlan>[
    const _Vlan(id: 1, name: 'default'),
    const _Vlan(id: 10, name: 'MGMT'),
  ];
  final _vlanIdCtrl = TextEditingController();
  final _vlanNameCtrl = TextEditingController();

  // Per-interface mode and VLAN assignment
  late final Map<String, _PortCfg> _portCfg = {
    for (final iface in widget.device.interfaces)
      iface.name: _PortCfg(mode: 'access', accessVlan: 1, trunkVlans: {1}),
  };

  void _addVlan() {
    final id = int.tryParse(_vlanIdCtrl.text.trim());
    final name = _vlanNameCtrl.text.trim();
    if (id == null || id < 1 || id > 4094) return;
    if (_vlans.any((v) => v.id == id)) return;
    setState(() {
      _vlans.add(_Vlan(id: id, name: name.isEmpty ? 'VLAN$id' : name));
      _vlanIdCtrl.clear(); _vlanNameCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(12), children: [
      // ── VLAN DB ───────────────────────────────────────────────────────────
      Text('VLANデータベース',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.grey)),
      const SizedBox(height: 8),
      ..._vlans.asMap().entries.map((e) {
        final v = e.value;
        return Dismissible(
          key: ValueKey(v.id),
          onDismissed: (_) => setState(() => _vlans.removeAt(e.key)),
          background: Container(color: Colors.red, alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              child: const Icon(Icons.delete, color: Colors.white)),
          child: ListTile(dense: true,
            leading: CircleAvatar(radius: 14,
                child: Text('${v.id}', style: const TextStyle(fontSize: 11))),
            title: Text(v.name),
            subtitle: Text('VLAN ${v.id}'),
          ),
        );
      }),
      const Divider(),
      Row(children: [
        SizedBox(width: 72, child: TextField(controller: _vlanIdCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'ID', isDense: true,
                border: OutlineInputBorder()))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: _vlanNameCtrl,
            decoration: const InputDecoration(labelText: '名前', isDense: true,
                border: OutlineInputBorder()))),
        const SizedBox(width: 8),
        IconButton.filled(icon: const Icon(Icons.add, size: 18), onPressed: _addVlan),
      ]),
      const SizedBox(height: 16),

      // ── ポート割り当て ────────────────────────────────────────────────────
      Text('ポートVLAN割り当て',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.grey)),
      const SizedBox(height: 8),
      ...widget.device.interfaces.map((iface) {
        final cfg = _portCfg[iface.name] ??
            _PortCfg(mode: 'access', accessVlan: 1, trunkVlans: {1});
        return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(iface.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: ['access', 'trunk'].map((m) => ChoiceChip(
              label: Text(m[0].toUpperCase() + m.substring(1)),
              selected: cfg.mode == m,
              onSelected: (_) => setState(
                  () => _portCfg[iface.name] = cfg.copyWith(mode: m)),
            )).toList()),
            if (cfg.mode == 'access') ...[
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Access VLAN',
                    isDense: true, border: OutlineInputBorder()),
                items: _vlans.map((v) => DropdownMenuItem(
                    value: v.id, child: Text('VLAN ${v.id} (${v.name})'))).toList(),
                initialValue: _vlans.any((v) => v.id == cfg.accessVlan) ? cfg.accessVlan : _vlans.first.id,
                onChanged: (id) => setState(
                    () => _portCfg[iface.name] = cfg.copyWith(accessVlan: id ?? 1)),
              ),
            ] else ...[
              const SizedBox(height: 6),
              Wrap(spacing: 6, children: _vlans.map((v) => FilterChip(
                label: Text('${v.id}'),
                selected: cfg.trunkVlans.contains(v.id),
                onSelected: (sel) => setState(() {
                  final s = Set<int>.from(cfg.trunkVlans);
                  sel ? s.add(v.id) : s.remove(v.id);
                  _portCfg[iface.name] = cfg.copyWith(trunkVlans: s);
                }),
              )).toList()),
            ],
          ]),
        ));
      }),
    ]);
  }
}

class _Vlan {
  final int id; final String name;
  const _Vlan({required this.id, required this.name});
}

class _PortCfg {
  final String mode; final int accessVlan; final Set<int> trunkVlans;
  const _PortCfg({required this.mode, required this.accessVlan, required this.trunkVlans});
  _PortCfg copyWith({String? mode, int? accessVlan, Set<int>? trunkVlans}) =>
      _PortCfg(mode: mode ?? this.mode, accessVlan: accessVlan ?? this.accessVlan,
          trunkVlans: trunkVlans ?? this.trunkVlans);
}
