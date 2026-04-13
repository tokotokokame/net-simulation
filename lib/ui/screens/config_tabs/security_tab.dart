// lib/ui/screens/config_tabs/security_tab.dart
import 'package:flutter/material.dart';
import '../../../models/device.dart';

class SecurityTab extends StatefulWidget {
  final Device device;
  const SecurityTab({super.key, required this.device});

  @override
  State<SecurityTab> createState() => _SecurityTabState();
}

class _SecurityTabState extends State<SecurityTab> {
  bool _natEnabled = false;
  final _natInsideCtrl = TextEditingController(text: '192.168.1.0/24');
  final _natOutsideCtrl = TextEditingController(text: '0.0.0.0/0');
  final _aclList = <_AclRule>[];
  bool _dhcpEnabled = false;
  final _dhcpStartCtrl = TextEditingController(text: '192.168.1.100');
  final _dhcpEndCtrl = TextEditingController(text: '192.168.1.200');

  @override
  void dispose() {
    _natInsideCtrl.dispose(); _natOutsideCtrl.dispose();
    _dhcpStartCtrl.dispose(); _dhcpEndCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(12),
    children: [
      _section('NAT'),
      SwitchListTile(title: const Text('NAT有効'), value: _natEnabled,
          onChanged: (v) => setState(() => _natEnabled = v)),
      if (_natEnabled) ...[
        _labeledField('Inside', _natInsideCtrl),
        const SizedBox(height: 4),
        _labeledField('Outside', _natOutsideCtrl),
      ],
      const Divider(height: 24),
      _section('ファイアウォール ACL'),
      ..._aclList.asMap().entries.map((e) => ListTile(dense: true,
        title: Text('${e.value.action} ${e.value.proto} ${e.value.src} → ${e.value.dst}'),
        trailing: IconButton(icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () => setState(() => _aclList.removeAt(e.key))),
      )),
      OutlinedButton.icon(
        icon: const Icon(Icons.add),
        label: const Text('ACLルール追加'),
        onPressed: () => setState(() =>
            _aclList.add(const _AclRule(action: 'permit', proto: 'tcp', src: 'any', dst: 'any'))),
      ),
      const Divider(height: 24),
      _section('DHCP'),
      SwitchListTile(title: const Text('DHCPスコープ有効'), value: _dhcpEnabled,
          onChanged: (v) => setState(() => _dhcpEnabled = v)),
      if (_dhcpEnabled) Row(children: [
        Expanded(child: _labeledField('開始IP', _dhcpStartCtrl)),
        const SizedBox(width: 8),
        Expanded(child: _labeledField('終了IP', _dhcpEndCtrl)),
      ]),
    ],
  );

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.grey)),
  );

  Widget _labeledField(String label, TextEditingController ctrl) =>
      TextField(controller: ctrl,
          decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()));
}

class _AclRule {
  final String action, proto, src, dst;
  const _AclRule({required this.action, required this.proto, required this.src, required this.dst});
}
