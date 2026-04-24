// lib/ui/screens/config_tabs/vpn_tab.dart
import 'package:flutter/material.dart';
import '../../../models/device.dart';

// ── Data classes ──────────────────────────────────────────────────────────────

class _IpsecEntry {
  String localGw  = '';
  String remoteGw = '';
  String localNet = '';
  String remoteNet = '';
  String psk    = '';
  String cipher = 'AES-256';
  String auth   = 'SHA-256';
}

class _GreEntry {
  String ifName   = 'tun0';
  String localIp  = '';
  String remoteIp = '';
  String keyId    = '';
}

// ── VPN Tab ───────────────────────────────────────────────────────────────────

class VpnTab extends StatefulWidget {
  final Device device;
  const VpnTab({super.key, required this.device});
  @override
  State<VpnTab> createState() => _VpnTabState();
}

class _VpnTabState extends State<VpnTab> {
  final _tunnels = <_IpsecEntry>[];
  final _gre     = _GreEntry();
  int _passedPkts = 0;

  static const _ciphers = ['AES-128', 'AES-256', '3DES'];
  static const _auths   = ['SHA-1', 'SHA-256', 'MD5'];

  bool get _isVpnDevice =>
      widget.device.type == DeviceType.vpnGateway ||
      widget.device.type == DeviceType.router ||
      widget.device.type == DeviceType.ipSecTunnel;

  Widget _sectionHeader(String t) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 6),
    child: Text(t, style: const TextStyle(
        fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
  );

  Widget _tf(String label, String init, bool obscure,
      ValueChanged<String> onChanged) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: TextField(
          obscureText: obscure,
          controller: TextEditingController(text: init),
          decoration: InputDecoration(labelText: label,
              isDense: true, border: const OutlineInputBorder()),
          onChanged: onChanged,
        ),
      );

  Widget _ipsecCard(_IpsecEntry e, int i) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ExpansionTile(
      title: Text('トンネル ${i + 1}: ${e.localNet.isEmpty ? "(未設定)" : e.localNet} ↔ ${e.remoteNet}',
          style: const TextStyle(fontSize: 13)),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _tf('ローカルゲートウェイIP', e.localGw,  false, (v) => e.localGw  = v),
            _tf('リモートゲートウェイIP', e.remoteGw, false, (v) => e.remoteGw = v),
            _tf('ローカルネットワーク (CIDR)', e.localNet, false, (v) => e.localNet = v),
            _tf('リモートネットワーク (CIDR)', e.remoteNet, false, (v) => e.remoteNet = v),
            _tf('PSK（事前共有鍵）', e.psk, true, (v) => e.psk = v),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: '暗号化方式',
                    isDense: true, border: OutlineInputBorder()),
                initialValue: e.cipher,
                items: _ciphers.map((c) =>
                    DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => e.cipher = v!),
              )),
              const SizedBox(width: 8),
              Expanded(child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: '認証方式',
                    isDense: true, border: OutlineInputBorder()),
                initialValue: e.auth,
                items: _auths.map((a) =>
                    DropdownMenuItem(value: a, child: Text(a))).toList(),
                onChanged: (v) => setState(() => e.auth = v!),
              )),
            ]),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('削除'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => setState(() => _tunnels.removeAt(i)),
              )),
          ]),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (!_isVpnDevice) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(24),
          child: Text('このデバイスではVPN設定は利用できません。\nVPNゲートウェイまたはルーターデバイスで使用できます。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey))),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ── Section 1: IPSec tunnels ─────────────────────────────────────
        _sectionHeader('IPSecトンネル設定'),
        ..._tunnels.asMap().entries.map((e) => _ipsecCard(e.value, e.key)),
        FilledButton.icon(
          icon: const Icon(Icons.add), label: const Text('トンネル追加'),
          onPressed: () => setState(() => _tunnels.add(_IpsecEntry())),
        ),

        // ── Section 2: GRE tunnel ────────────────────────────────────────
        _sectionHeader('GREトンネル設定'),
        Card(child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _tf('インターフェース名', _gre.ifName, false, (v) => _gre.ifName  = v),
            _tf('ローカルIP',        _gre.localIp, false, (v) => _gre.localIp = v),
            _tf('リモートIP',        _gre.remoteIp, false, (v) => _gre.remoteIp = v),
            _tf('キーID（省略可）',  _gre.keyId, false, (v) => _gre.keyId   = v),
          ]),
        )),

        // ── Section 3: VPN status ────────────────────────────────────────
        _sectionHeader('VPN状態'),
        Card(child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Row(children: [
              const Icon(Icons.circle, size: 10,
                  color: Colors.green), // simplified: always "connected"
              const SizedBox(width: 8),
              const Text('接続状態: '),
              Text(_tunnels.isEmpty ? 'Disconnected' : 'Connected',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _tunnels.isEmpty ? Colors.red : Colors.green,
                  )),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.swap_horiz, size: 16),
              const SizedBox(width: 8),
              Text('通過パケット数: $_passedPkts'),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _passedPkts++),
                child: const Text('テスト +1'),
              ),
            ]),
          ]),
        )),
      ],
    );
  }
}
