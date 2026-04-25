// lib/ui/screens/config_tabs/sdn_tab.dart
import 'package:flutter/material.dart';
import '../../../models/device.dart';

class SdnTab extends StatelessWidget {
  final Device device;
  const SdnTab({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final isController = device.type == DeviceType.sdnController;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(isController ? Icons.developer_board : Icons.device_hub,
                  color: const Color(0xFF00796B), size: 22),
              const SizedBox(width: 8),
              Text(isController ? 'SDNコントローラ設定' : 'OpenFlowスイッチ設定',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
            const Divider(height: 20),
            _info('ロール', isController ? 'SDN Controller' : 'OpenFlow Switch'),
            _info('OpenFlowバージョン', 'OpenFlow 1.3'),
            _info('コントローラ接続', isController ? '待受中 (port 6653)' : '未接続'),
            if (!isController) ...[
              const SizedBox(height: 12),
              const Text('フローテーブル',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              const Text('（シミュレーション中にフローエントリが自動インストールされます）',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ]),
        )),
        if (isController) ...[
          const SizedBox(height: 12),
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('管理対象スイッチ',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('（トポロジ上の OpenFlow スイッチが自動登録されます）',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
          )),
        ],
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
