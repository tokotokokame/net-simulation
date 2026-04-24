// lib/ui/screens/device_config_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/device.dart';
import 'config_tabs/cli_tab.dart';
import 'config_tabs/physical_tab.dart';
import 'config_tabs/qos_tab.dart';
import 'config_tabs/routing_tab.dart';
import 'config_tabs/security_tab.dart';
import 'config_tabs/vpn_tab.dart';
import 'topology_state.dart';

class DeviceConfigScreen extends ConsumerWidget {
  final String deviceId;
  const DeviceConfigScreen({super.key, required this.deviceId});

  static bool _hasVpn(Device d) =>
      d.type == DeviceType.vpnGateway ||
      d.type == DeviceType.router ||
      d.type == DeviceType.ipSecTunnel ||
      d.type == DeviceType.greTunnel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(topologyProvider)
        .devices
        .where((d) => d.id == deviceId)
        .firstOrNull;

    if (device == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('デバイス設定')),
        body: const Center(child: Text('デバイスが見つかりません')),
      );
    }

    final showVpn = _hasVpn(device);
    final tabCount = showVpn ? 6 : 5;

    return DefaultTabController(
      length: tabCount,
      child: Scaffold(
        appBar: AppBar(
          title: Text(device.name, style: const TextStyle(fontSize: 16)),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              const Tab(icon: Icon(Icons.cable),    text: '物理'),
              const Tab(icon: Icon(Icons.route),    text: 'ルーティング'),
              const Tab(icon: Icon(Icons.shield),   text: 'セキュリティ'),
              const Tab(icon: Icon(Icons.speed),    text: 'QoS'),
              const Tab(icon: Icon(Icons.terminal), text: 'CLI'),
              if (showVpn) const Tab(icon: Icon(Icons.vpn_lock), text: 'VPN'),
            ],
          ),
        ),
        body: TabBarView(children: [
          PhysicalTab(device: device),
          RoutingTab(device: device),
          SecurityTab(device: device),
          QosTab(device: device),
          CliTab(device: device),
          if (showVpn) VpnTab(device: device),
        ]),
      ),
    );
  }
}
