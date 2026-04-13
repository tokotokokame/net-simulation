// lib/ui/screens/config_tabs/routing_tab.dart
import 'package:flutter/material.dart';
import '../../../models/device.dart';
import '../../../routing/rib.dart';

class RoutingTab extends StatefulWidget {
  final Device device;
  const RoutingTab({super.key, required this.device});

  @override
  State<RoutingTab> createState() => _RoutingTabState();
}

class _RoutingTabState extends State<RoutingTab> {
  final RIB _rib = RIB();
  final _prefixCtrl = TextEditingController(text: '0.0.0.0');
  final _maskCtrl = TextEditingController(text: '0');
  final _hopCtrl = TextEditingController(text: '0.0.0.0');
  bool _ospfEnabled = false;
  final _bgpAsCtrl = TextEditingController();

  @override
  void dispose() {
    _prefixCtrl.dispose(); _maskCtrl.dispose();
    _hopCtrl.dispose(); _bgpAsCtrl.dispose();
    super.dispose();
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
        const _SectionHeader('スタティックルート'),
        ...routes.map((r) => Dismissible(
          key: ValueKey('${r.prefix}/${r.mask}'),
          onDismissed: (_) => setState(() => _rib.removeRoute(r.prefix)),
          background: Container(color: Colors.red, alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16), child: const Icon(Icons.delete, color: Colors.white)),
          child: ListTile(dense: true,
            title: Text('${r.prefix}/${r.mask} → ${r.nextHop}'),
            subtitle: Text(r.protocol.name)),
        )),
        const Divider(),
        _RouteForm(prefix: _prefixCtrl, mask: _maskCtrl, hop: _hopCtrl, onAdd: _addRoute),
        const SizedBox(height: 12),
        const _SectionHeader('プロトコル'),
        SwitchListTile(title: const Text('OSPF'), value: _ospfEnabled,
            onChanged: (v) => setState(() => _ospfEnabled = v)),
        ListTile(title: const Text('BGP AS番号'),
            trailing: SizedBox(width: 80, child: TextField(
              controller: _bgpAsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(isDense: true, hintText: '65001'),
            ))),
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
    child: Text(text, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.grey)),
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
      TextField(controller: c, decoration: InputDecoration(labelText: h, isDense: true,
          border: const OutlineInputBorder()), style: const TextStyle(fontSize: 12));
}
