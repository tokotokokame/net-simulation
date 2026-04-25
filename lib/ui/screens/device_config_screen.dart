// lib/ui/screens/device_config_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/device.dart';
import 'config_tabs/cli_tab.dart';
import 'config_tabs/firewall_policy_tab.dart';
import 'config_tabs/ids_rules_tab.dart';
import 'config_tabs/physical_tab.dart';
import 'config_tabs/qos_tab.dart';
import 'config_tabs/routing_tab.dart';
import 'config_tabs/security_tab.dart';
import 'config_tabs/vlan_tab.dart';
import 'config_tabs/vpn_tab.dart';
import 'config_tabs/wireless_tab.dart';
import 'topology_state.dart';

class DeviceConfigScreen extends ConsumerWidget {
  final String deviceId;
  const DeviceConfigScreen({super.key, required this.deviceId});

  static List<Tab> _tabs(Device d) {
    final extra = switch (d.type) {
      DeviceType.router || DeviceType.vpnGateway ||
      DeviceType.ipSecTunnel || DeviceType.greTunnel =>
          const Tab(icon: Icon(Icons.vpn_lock), text: 'VPN'),
      DeviceType.firewall =>
          const Tab(icon: Icon(Icons.policy), text: 'ポリシー'),
      DeviceType.ids || DeviceType.ips =>
          const Tab(icon: Icon(Icons.notification_important), text: '検知ルール'),
      DeviceType.switch_ || DeviceType.l3Switch =>
          const Tab(icon: Icon(Icons.lan), text: 'VLAN'),
      DeviceType.wirelessAP =>
          const Tab(icon: Icon(Icons.wifi), text: '無線設定'),
      _ => null,
    };
    return [
      const Tab(icon: Icon(Icons.cable),    text: '物理'),
      const Tab(icon: Icon(Icons.route),    text: 'ルーティング'),
      const Tab(icon: Icon(Icons.shield),   text: 'セキュリティ'),
      const Tab(icon: Icon(Icons.speed),    text: 'QoS'),
      if (extra != null) extra,
      const Tab(icon: Icon(Icons.terminal), text: 'CLI'),
    ];
  }

  static List<Widget> _views(Device d) {
    final extra = switch (d.type) {
      DeviceType.router || DeviceType.vpnGateway ||
      DeviceType.ipSecTunnel || DeviceType.greTunnel => VpnTab(device: d),
      DeviceType.firewall => FirewallPolicyTab(device: d),
      DeviceType.ids || DeviceType.ips => IdsRulesTab(device: d),
      DeviceType.switch_ || DeviceType.l3Switch => VlanTab(device: d),
      DeviceType.wirelessAP => WirelessTab(device: d),
      _ => null,
    };
    return [
      PhysicalTab(device: d),
      RoutingTab(device: d),
      SecurityTab(device: d),
      QosTab(device: d),
      if (extra != null) extra,
      CliTab(device: d),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch provider so changes in physical_tab are reflected immediately.
    final device = ref.watch(topologyProvider)
        .devices.where((d) => d.id == deviceId).firstOrNull;

    if (device == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('デバイス設定')),
        body: const Center(child: Text('デバイスが見つかりません')),
      );
    }

    final tabs  = _tabs(device);
    final views = _views(device);

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(device.name, style: const TextStyle(fontSize: 16)),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: tabs,
          ),
        ),
        body: TabBarView(children: views),
      ),
    );
  }
}
