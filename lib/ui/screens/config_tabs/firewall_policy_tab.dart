// lib/ui/screens/config_tabs/firewall_policy_tab.dart
import 'package:flutter/material.dart';
import '../../../models/device.dart';

class FirewallPolicyTab extends StatefulWidget {
  final Device device;
  const FirewallPolicyTab({super.key, required this.device});
  @override
  State<FirewallPolicyTab> createState() => _FirewallPolicyTabState();
}

class _FirewallPolicyTabState extends State<FirewallPolicyTab> {
  final _policies = <_Policy>[];
  String _defaultAction = 'deny';

  // Form controllers
  final _nameCtrl = TextEditingController();
  String _srcZone = 'untrust', _dstZone = 'trust';
  String _action = 'permit', _proto = 'any';
  final _dstPortCtrl = TextEditingController(text: '80');

  @override
  void dispose() {
    _nameCtrl.dispose(); _dstPortCtrl.dispose(); super.dispose();
  }

  void _addPolicy() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _policies.add(_Policy(
        name: name, srcZone: _srcZone, dstZone: _dstZone,
        action: _action, proto: _proto,
        dstPort: int.tryParse(_dstPortCtrl.text.trim()) ?? 0,
      ));
      _nameCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(12), children: [
      // ── ゾーン設定 ────────────────────────────────────────────────────────
      _header('ゾーン設定'),
      const ListTile(dense: true,
        leading: Icon(Icons.security, color: Colors.green, size: 18),
        title: Text('Trust ゾーン'),
        subtitle: Text('内部インターフェース'),
      ),
      const ListTile(dense: true,
        leading: Icon(Icons.public, color: Colors.red, size: 18),
        title: Text('Untrust ゾーン'),
        subtitle: Text('外部インターフェース'),
      ),
      const SizedBox(height: 8),

      // ── ポリシー一覧 ──────────────────────────────────────────────────────
      _header('セキュリティポリシー'),
      ..._policies.asMap().entries.map((e) => Dismissible(
        key: ValueKey(e.key),
        onDismissed: (_) => setState(() => _policies.removeAt(e.key)),
        background: Container(color: Colors.red, alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(Icons.delete, color: Colors.white)),
        child: Card(child: ListTile(dense: true,
          leading: Icon(e.value.action == 'permit' ? Icons.check_circle : Icons.cancel,
              color: e.value.action == 'permit' ? Colors.green : Colors.red, size: 20),
          title: Text(e.value.name, style: const TextStyle(fontSize: 13)),
          subtitle: Text('${e.value.srcZone}→${e.value.dstZone}  ${e.value.proto}:${e.value.dstPort}',
              style: const TextStyle(fontSize: 11)),
        )),
      )),
      const Divider(),

      // ── ポリシー追加フォーム ────────────────────────────────────────────
      _header('ポリシー追加'),
      TextField(controller: _nameCtrl, decoration: const InputDecoration(
          labelText: 'ポリシー名', isDense: true, border: OutlineInputBorder())),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _zoneDropdown('送信元', _srcZone, (v) => setState(() => _srcZone = v!))),
        const SizedBox(width: 8),
        Expanded(child: _zoneDropdown('宛先', _dstZone, (v) => setState(() => _dstZone = v!))),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _dropdown('アクション', _action,
            ['permit', 'deny', 'drop'], (v) => setState(() => _action = v!))),
        const SizedBox(width: 8),
        Expanded(child: _dropdown('プロトコル', _proto,
            ['any', 'tcp', 'udp', 'icmp'], (v) => setState(() => _proto = v!))),
        const SizedBox(width: 8),
        SizedBox(width: 72, child: TextField(controller: _dstPortCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Port', isDense: true,
                border: OutlineInputBorder()))),
      ]),
      const SizedBox(height: 8),
      FilledButton.icon(icon: const Icon(Icons.add), label: const Text('追加'),
          onPressed: _addPolicy),
      const SizedBox(height: 16),

      // ── デフォルトアクション ────────────────────────────────────────────
      _header('デフォルトアクション'),
      Wrap(spacing: 8, children: ['deny', 'permit'].map((a) => ChoiceChip(
        label: Text(a == 'deny' ? 'Deny All' : 'Permit All'),
        selected: _defaultAction == a,
        selectedColor: a == 'deny' ? Colors.red[100] : Colors.green[100],
        onSelected: (_) => setState(() => _defaultAction = a),
      )).toList()),
    ]);
  }

  Widget _header(String t) => Padding(padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(t, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.grey)));

  Widget _zoneDropdown(String label, String value, void Function(String?) onChanged) =>
    DropdownButtonFormField<String>(
      initialValue: value, decoration: InputDecoration(labelText: label, isDense: true,
          border: const OutlineInputBorder()),
      items: ['trust', 'untrust'].map((z) =>
          DropdownMenuItem(value: z, child: Text(z))).toList(),
      onChanged: onChanged);

  Widget _dropdown(String label, String value, List<String> items,
      void Function(String?) onChanged) =>
    DropdownButtonFormField<String>(
      initialValue: value, decoration: InputDecoration(labelText: label, isDense: true,
          border: const OutlineInputBorder()),
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
      onChanged: onChanged);
}

class _Policy {
  final String name, srcZone, dstZone, action, proto;
  final int dstPort;
  const _Policy({required this.name, required this.srcZone, required this.dstZone,
      required this.action, required this.proto, required this.dstPort});
}
