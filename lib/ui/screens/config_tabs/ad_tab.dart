// lib/ui/screens/config_tabs/ad_tab.dart
import 'package:flutter/material.dart';
import '../../../models/device.dart';

class AdTab extends StatelessWidget {
  final Device device;
  const AdTab({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.domain, color: Colors.indigo, size: 22),
              SizedBox(width: 8),
              Text('Active Directory設定',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
            const Divider(height: 20),
            _info('ドメイン名', 'corp.local'),
            _info('DCロール', 'Primary Domain Controller'),
            _info('LDAP ポート', '389 (LDAP) / 636 (LDAPS)'),
            _info('Kerberos ポート', '88'),
            _info('DNS統合', '有効'),
          ]),
        )),
        const SizedBox(height: 12),
        Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('グループポリシー',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('（シミュレーション環境では GPO は参照のみです）',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
        )),
      ],
    );
  }

  Widget _info(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      SizedBox(width: 160,
          child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
    ]),
  );
}
