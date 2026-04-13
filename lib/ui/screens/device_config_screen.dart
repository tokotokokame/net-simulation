// lib/ui/screens/device_config_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config_tabs/cli_tab.dart';
import 'config_tabs/physical_tab.dart';
import 'config_tabs/routing_tab.dart';
import 'config_tabs/security_tab.dart';
import 'topology_state.dart';

class DeviceConfigScreen extends ConsumerWidget {
  final String deviceId;
  const DeviceConfigScreen({super.key, required this.deviceId});

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

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(device.name, style: const TextStyle(fontSize: 16)),
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.cable), text: '物理'),
            Tab(icon: Icon(Icons.route), text: 'ルーティング'),
            Tab(icon: Icon(Icons.shield), text: 'セキュリティ'),
            Tab(icon: Icon(Icons.terminal), text: 'CLI'),
          ]),
        ),
        body: TabBarView(children: [
          PhysicalTab(device: device),
          RoutingTab(device: device),
          SecurityTab(device: device),
          CliTab(device: device),
        ]),
      ),
    );
  }
}
