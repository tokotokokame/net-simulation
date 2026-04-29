// lib/ui/screens/device_config_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/device.dart';
import '../../visualization/device_style.dart';
import 'config_tabs/ad_tab.dart';
import 'config_tabs/cli_tab.dart';
import 'config_tabs/firewall_policy_tab.dart';
import 'config_tabs/ids_rules_tab.dart';
import 'config_tabs/physical_tab.dart';
import 'config_tabs/qos_tab.dart';
import 'config_tabs/routing_tab.dart';
import 'config_tabs/sdn_tab.dart';
import 'config_tabs/security_tab.dart';
import 'config_tabs/vlan_tab.dart';
import 'config_tabs/vpn_tab.dart';
import 'config_tabs/wireless_tab.dart';
import 'topology_state.dart';

// ── Cloud / carrier devices that have no user-configurable settings ───────────

bool isCloudDevice(DeviceType t) => const {
  DeviceType.internetCloud,
  DeviceType.mplsCloud,
  DeviceType.lteNetwork,
  DeviceType.fiveGNetwork,
  DeviceType.satelliteNetwork,
}.contains(t);

// ── Tab capability predicates ─────────────────────────────────────────────────

bool _hasPhysical(DeviceType t) => !isCloudDevice(t);

bool _hasRouting(DeviceType t) => const {
  DeviceType.router, DeviceType.l3Switch, DeviceType.firewall,
  DeviceType.natGateway, DeviceType.vpnGateway,
}.contains(t);

bool _hasAcl(DeviceType t) => const {
  DeviceType.router, DeviceType.l3Switch, DeviceType.firewall,
  DeviceType.natGateway, DeviceType.vpnGateway,
}.contains(t);

bool _hasQos(DeviceType t) => const {
  DeviceType.router, DeviceType.l3Switch, DeviceType.switch_,
  DeviceType.firewall, DeviceType.natGateway, DeviceType.vpnGateway,
  DeviceType.openFlowSwitch,
}.contains(t);

bool _hasVpn(DeviceType t) => const {
  DeviceType.router, DeviceType.firewall, DeviceType.vpnGateway,
  DeviceType.ipSecTunnel, DeviceType.greTunnel,
}.contains(t);

bool _hasVlan(DeviceType t) => const {
  DeviceType.l3Switch, DeviceType.switch_, DeviceType.openFlowSwitch,
}.contains(t);

bool _hasWireless(DeviceType t) =>
    t == DeviceType.wirelessAP || t == DeviceType.iotDevice;

bool _hasSdn(DeviceType t) =>
    t == DeviceType.openFlowSwitch || t == DeviceType.sdnController;

bool _hasCli(DeviceType t) => !isCloudDevice(t) &&
    !const {DeviceType.hub, DeviceType.bridge, DeviceType.iotDevice}.contains(t);

// ── Tab + View pair builder ───────────────────────────────────────────────────

typedef _TabPair = ({Tab tab, Widget view});

List<_TabPair> _buildSpecs(Device d) {
  final t = d.type;
  final specs = <_TabPair>[];

  if (_hasPhysical(t)) {
    specs.add((tab: const Tab(icon: Icon(Icons.cable),    text: '物理'),
               view: PhysicalTab(device: d)));
  }
  if (_hasRouting(t)) {
    specs.add((tab: const Tab(icon: Icon(Icons.route),    text: 'ルーティング'),
               view: RoutingTab(device: d)));
  }
  if (_hasAcl(t)) {
    specs.add((tab: const Tab(icon: Icon(Icons.shield),   text: 'セキュリティ'),
               view: SecurityTab(device: d)));
  }
  if (_hasQos(t)) {
    specs.add((tab: const Tab(icon: Icon(Icons.speed),    text: 'QoS'),
               view: QosTab(device: d)));
  }
  if (_hasVpn(t)) {
    specs.add((tab: const Tab(icon: Icon(Icons.vpn_lock), text: 'VPN'),
               view: VpnTab(device: d)));
  }
  if (t == DeviceType.firewall) {
    specs.add((tab: const Tab(icon: Icon(Icons.policy),   text: 'ポリシー'),
               view: FirewallPolicyTab(device: d)));
  }
  if (t == DeviceType.ids || t == DeviceType.ips) {
    specs.add((tab: const Tab(icon: Icon(Icons.notification_important), text: '検知ルール'),
               view: IdsRulesTab(device: d)));
  }
  if (_hasVlan(t)) {
    specs.add((tab: const Tab(icon: Icon(Icons.lan),      text: 'VLAN'),
               view: VlanTab(device: d)));
  }
  if (_hasWireless(t)) {
    specs.add((tab: const Tab(icon: Icon(Icons.wifi),     text: '無線設定'),
               view: WirelessTab(device: d)));
  }
  if (_hasSdn(t)) {
    specs.add((tab: const Tab(icon: Icon(Icons.developer_board), text: 'SDN/OF'),
               view: SdnTab(device: d)));
  }
  if (t == DeviceType.activeDirectoryServer) {
    specs.add((tab: const Tab(icon: Icon(Icons.domain),   text: 'AD設定'),
               view: AdTab(device: d)));
  }
  if (_hasCli(t)) {
    specs.add((tab: const Tab(icon: Icon(Icons.terminal), text: 'CLI'),
               view: CliTab(device: d)));
  }

  return specs;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class DeviceConfigScreen extends ConsumerWidget {
  final String deviceId;
  const DeviceConfigScreen({super.key, required this.deviceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(topologyProvider)
        .devices.where((d) => d.id == deviceId).firstOrNull;

    if (device == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('デバイス設定')),
        body: const Center(child: Text('デバイスが見つかりません')),
      );
    }

    // Cloud/carrier nodes: no configurable settings.
    if (isCloudDevice(device.type)) {
      return Scaffold(
        appBar: AppBar(title: Text(device.name)),
        body: const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('クラウド/キャリアノードは設定できません',
                style: TextStyle(color: Colors.grey)),
          ]),
        ),
      );
    }

    final specs = _buildSpecs(device);
    final tabs  = specs.map((s) => s.tab).toList();
    final views = specs.map((s) => s.view).toList();

    final badgeColor = deviceColor(device.type);

    // G4: rename dialog.
    Future<void> renameDevice() async {
      final ctrl = TextEditingController(text: device.name);
      final newName = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('デバイス名を変更'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
                labelText: '名前', border: OutlineInputBorder()),
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('キャンセル')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: const Text('保存')),
          ],
        ),
      );
      ctrl.dispose();
      if (newName == null || newName.isEmpty) return;
      ref.read(topologyProvider.notifier).updateDevice(
          device.copyWith(name: newName));
    }

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Row(children: [
            Flexible(child: Text(device.name,
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis)),
            // G4: tap to rename
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.white54),
              tooltip: '名前を変更',
              onPressed: renameDevice,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: badgeColor, width: 0.5),
              ),
              child: Text(device.type.name,
                  style: TextStyle(fontSize: 10, color: badgeColor)),
            ),
          ]),
          bottom: tabs.isEmpty ? null : TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: tabs,
          ),
        ),
        body: tabs.isEmpty
            ? const Center(child: Text('設定項目がありません'))
            : TabBarView(children: views),
      ),
    );
  }
}
