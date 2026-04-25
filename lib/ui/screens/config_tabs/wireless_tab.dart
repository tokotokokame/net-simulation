// lib/ui/screens/config_tabs/wireless_tab.dart
import 'package:flutter/material.dart';
import '../../../models/device.dart';

class WirelessTab extends StatefulWidget {
  final Device device;
  const WirelessTab({super.key, required this.device});
  @override
  State<WirelessTab> createState() => _WirelessTabState();
}

class _WirelessTabState extends State<WirelessTab> {
  final _ssidCtrl = TextEditingController(text: 'NetSim-AP');
  final _passCtrl = TextEditingController(text: 'password123');
  bool _obscure = true;
  String _security = 'WPA2';
  String _band = '5GHz';
  String _channel = 'auto';
  double _maxClients = 32;
  double _txPower = 20;

  static const _bands = ['2.4GHz', '5GHz', '6GHz'];
  static const _securities = ['Open', 'WPA2', 'WPA3'];

  List<String> get _channels {
    if (_band == '2.4GHz') {
      return ['auto', ...List.generate(13, (i) => '${i + 1}')];
    } else if (_band == '5GHz') {
      return ['auto', '36', '40', '44', '48', '52', '56', '60', '64',
          '100', '104', '108', '112', '116', '132', '136', '140', '149',
          '153', '157', '161', '165'];
    }
    return ['auto', '1', '5', '9', '13', '17', '21', '25', '29'];
  }

  @override
  void dispose() { _ssidCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(12), children: [
      // ── SSID ─────────────────────────────────────────────────────────────
      TextField(controller: _ssidCtrl,
          decoration: const InputDecoration(labelText: 'SSID', isDense: true,
              border: OutlineInputBorder())),
      const SizedBox(height: 10),

      // ── Password ──────────────────────────────────────────────────────────
      TextField(
        controller: _passCtrl, obscureText: _obscure,
        decoration: InputDecoration(
          labelText: 'パスワード', isDense: true, border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
      const SizedBox(height: 10),

      // ── Security ──────────────────────────────────────────────────────────
      const Text('セキュリティ方式', style: TextStyle(fontSize: 12, color: Colors.grey)),
      const SizedBox(height: 4),
      Wrap(spacing: 8, children: _securities.map((s) => ChoiceChip(
        label: Text(s),
        selected: _security == s,
        onSelected: (_) => setState(() => _security = s),
      )).toList()),
      const SizedBox(height: 10),

      // ── Band ─────────────────────────────────────────────────────────────
      const Text('周波数帯', style: TextStyle(fontSize: 12, color: Colors.grey)),
      const SizedBox(height: 4),
      Wrap(spacing: 8, children: _bands.map((b) => ChoiceChip(
        label: Text(b),
        selected: _band == b,
        onSelected: (_) => setState(() { _band = b; _channel = 'auto'; }),
      )).toList()),
      const SizedBox(height: 10),

      // ── Channel ──────────────────────────────────────────────────────────
      DropdownButtonFormField<String>(
        initialValue: _channels.contains(_channel) ? _channel : 'auto',
        decoration: const InputDecoration(labelText: 'チャンネル', isDense: true,
            border: OutlineInputBorder()),
        items: _channels.map((c) =>
            DropdownMenuItem(value: c, child: Text(c))).toList(),
        onChanged: (v) => setState(() => _channel = v ?? 'auto'),
      ),
      const SizedBox(height: 10),

      // ── Max clients ──────────────────────────────────────────────────────
      Row(children: [
        const Text('最大接続台数', style: TextStyle(fontSize: 12)),
        Expanded(child: Slider(
          value: _maxClients, min: 1, max: 254, divisions: 253,
          label: '${_maxClients.round()}',
          onChanged: (v) => setState(() => _maxClients = v),
        )),
        SizedBox(width: 36,
            child: Text('${_maxClients.round()}台', style: const TextStyle(fontSize: 12))),
      ]),

      // ── TX power ─────────────────────────────────────────────────────────
      Row(children: [
        const Text('送信電力', style: TextStyle(fontSize: 12)),
        Expanded(child: Slider(
          value: _txPower, min: 1, max: 100, divisions: 99,
          label: '${_txPower.round()} mW',
          onChanged: (v) => setState(() => _txPower = v),
        )),
        SizedBox(width: 52,
            child: Text('${_txPower.round()} mW', style: const TextStyle(fontSize: 12))),
      ]),
      const SizedBox(height: 12),

      // ── Save ─────────────────────────────────────────────────────────────
      FilledButton.icon(
        icon: const Icon(Icons.save),
        label: const Text('保存'),
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✓ 無線設定を保存しました'),
                backgroundColor: Colors.green, duration: Duration(seconds: 1))),
      ),
    ]);
  }
}
