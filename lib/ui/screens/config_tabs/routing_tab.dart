// lib/ui/screens/config_tabs/routing_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/device.dart';
import '../../../routing/rib.dart';
import '../topology_state.dart';

enum _RoutingMode { router, host }

class RoutingTab extends ConsumerStatefulWidget {
  final Device device;
  const RoutingTab({super.key, required this.device});
  @override
  ConsumerState<RoutingTab> createState() => _RoutingTabState();
}

class _RoutingTabState extends ConsumerState<RoutingTab> {
  final RIB _rib = RIB();

  // ── Default GW / Hostname / Mode ──────────────────────────────────────────
  late final TextEditingController _gwCtrl;
  late final TextEditingController _hostCtrl;
  _RoutingMode _mode = _RoutingMode.router;

  // ── Static route form ─────────────────────────────────────────────────────
  final _prefixCtrl = TextEditingController(text: '0.0.0.0');
  final _maskCtrl   = TextEditingController(text: '0');
  final _hopCtrl    = TextEditingController(text: '0.0.0.0');

  // ── Protocol toggles ──────────────────────────────────────────────────────
  bool _ospfEnabled = false;
  final _bgpAsCtrl  = TextEditingController();

  @override
  void initState() {
    super.initState();
    _gwCtrl   = TextEditingController();
    _hostCtrl = TextEditingController(text: widget.device.name);
    // Detect existing default route
    final defRoute = _rib.routes.where(
        (r) => r.prefix == '0.0.0.0' && r.mask == 0).firstOrNull;
    if (defRoute != null) _gwCtrl.text = defRoute.nextHop;
  }

  @override
  void dispose() {
    _gwCtrl.dispose(); _hostCtrl.dispose();
    _prefixCtrl.dispose(); _maskCtrl.dispose();
    _hopCtrl.dispose(); _bgpAsCtrl.dispose();
    super.dispose();
  }

  void _applyGateway() {
    final gw = _gwCtrl.text.trim();
    if (gw.isEmpty) return;
    _rib.removeRoute('0.0.0.0');
    _rib.addRoute(RIBEntry(
      prefix: '0.0.0.0', mask: 0, nextHop: gw,
      metric: 1, protocol: RoutingProtocol.static,
    ));
    setState(() {});
  }

  void _applyHostname() {
    final name = _hostCtrl.text.trim();
    if (name.isEmpty) return;
    final d = widget.device.copyWith(name: name);
    ref.read(topologyProvider.notifier).updateDevice(d);
  }

  void _addRoute() {
    _rib.addRoute(RIBEntry(
      prefix: _prefixCtrl.text.trim(),
      mask: int.tryParse(_maskCtrl.text.trim()) ?? 0,
      nextHop: _hopCtrl.text.trim(),
      metric: 1,
      protocol: RoutingProtocol.static,
    ));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final routes = _rib.routes;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ── Section: Basic network settings ──────────────────────────────
        const _SectionHeader('基本設定'),
        TextField(
          controller: _hostCtrl,
          decoration: InputDecoration(
            labelText: 'ホスト名',
            isDense: true,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.check, size: 18),
              onPressed: _applyHostname,
            ),
          ),
          onSubmitted: (_) => _applyHostname(),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _gwCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'デフォルトゲートウェイ',
            hintText: '192.168.1.1',
            isDense: true,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.check, size: 18),
              onPressed: _applyGateway,
            ),
          ),
          onSubmitted: (_) => _applyGateway(),
        ),
        const SizedBox(height: 8),
        const Text('ルーティングモード', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: _RoutingMode.values.map((m) => ChoiceChip(
            label: Text(m == _RoutingMode.router ? 'ルーター（転送有効）' : 'ホスト（転送無効）',
                style: const TextStyle(fontSize: 12)),
            selected: _mode == m,
            onSelected: (_) => setState(() => _mode = m),
          )).toList(),
        ),
        const SizedBox(height: 12),

        // ── Section: Static routes ────────────────────────────────────────
        const _SectionHeader('スタティックルート'),
        ...routes.map((r) => Dismissible(
          key: ValueKey('${r.prefix}/${r.mask}'),
          onDismissed: (_) => setState(() => _rib.removeRoute(r.prefix)),
          background: Container(color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              child: const Icon(Icons.delete, color: Colors.white)),
          child: ListTile(dense: true,
            title: Text('${r.prefix}/${r.mask} → ${r.nextHop}'),
            subtitle: Text(r.protocol.name)),
        )),
        const Divider(),
        _RouteForm(prefix: _prefixCtrl, mask: _maskCtrl, hop: _hopCtrl, onAdd: _addRoute),
        const SizedBox(height: 12),

        // ── Section: Routing protocols ────────────────────────────────────
        const _SectionHeader('プロトコル'),
        SwitchListTile(
          title: const Text('OSPF'),
          value: _ospfEnabled,
          onChanged: (v) => setState(() => _ospfEnabled = v),
        ),
        ListTile(
          title: const Text('BGP AS番号'),
          trailing: SizedBox(width: 80, child: TextField(
            controller: _bgpAsCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(isDense: true, hintText: '65001'),
          )),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text(text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.grey)),
  );
}

class _RouteForm extends StatelessWidget {
  final TextEditingController prefix, mask, hop;
  final VoidCallback onAdd;
  const _RouteForm({required this.prefix, required this.mask, required this.hop, required this.onAdd});
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: _field(prefix, 'Prefix')),
    const SizedBox(width: 4),
    SizedBox(width: 48, child: _field(mask, '/Mask')),
    const SizedBox(width: 4),
    Expanded(child: _field(hop, 'Next Hop')),
    const SizedBox(width: 4),
    IconButton.filled(icon: const Icon(Icons.add, size: 18), onPressed: onAdd),
  ]);

  Widget _field(TextEditingController c, String h) =>
      TextField(controller: c,
          decoration: InputDecoration(labelText: h, isDense: true,
              border: const OutlineInputBorder()),
          style: const TextStyle(fontSize: 12));
}
