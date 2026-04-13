// lib/ui/screens/config_tabs/physical_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/device.dart';
import '../../../models/network_interface.dart';
import '../topology_state.dart';

class PhysicalTab extends ConsumerWidget {
  final Device device;
  const PhysicalTab({super.key, required this.device});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ifaces = device.interfaces;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        ...ifaces.map((iface) => _IfaceCard(device: device, iface: iface, ref: ref)),
        const SizedBox(height: 8),
        FilledButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('インターフェース追加'),
          onPressed: () => _addInterface(context, ref),
        ),
      ],
    );
  }

  void _addInterface(BuildContext context, WidgetRef ref) {
    final count = device.interfaces.length;
    final newIface = NetworkInterface(
      name: 'eth$count',
      ip: '0.0.0.0',
      subnet: 24,
      mac: '00:00:00:00:00:${count.toRadixString(16).padLeft(2, '0')}',
    );
    ref.read(topologyProvider.notifier).updateDevice(
          device.copyWith(interfaces: [...device.interfaces, newIface]));
  }
}

class _IfaceCard extends StatelessWidget {
  final Device device;
  final NetworkInterface iface;
  final WidgetRef ref;
  const _IfaceCard({required this.device, required this.iface, required this.ref});

  @override
  Widget build(BuildContext context) {
    final isUp = iface.status == InterfaceStatus.up;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.cable, color: isUp ? Colors.green : Colors.red),
        title: Text(iface.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('IP: ${iface.ip}/${iface.subnet}'),
            Text('MAC: ${iface.mac}'),
            if (iface.vlan != null) Text('VLAN: ${iface.vlan}'),
          ],
        ),
        isThreeLine: true,
        trailing: Switch(
          value: isUp,
          onChanged: (_) => _toggleStatus(),
        ),
      ),
    );
  }

  void _toggleStatus() {
    final updated = iface.copyWith(
      status: iface.status == InterfaceStatus.up ? InterfaceStatus.down : InterfaceStatus.up,
    );
    ref.read(topologyProvider.notifier).updateDevice(device.copyWith(
      interfaces: device.interfaces.map((i) => i.name == iface.name ? updated : i).toList(),
    ));
  }
}
