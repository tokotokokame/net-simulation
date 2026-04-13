// lib/ui/widgets/device_palette.dart
import 'package:flutter/material.dart';
import '../../models/device.dart';
import '../../visualization/device_style.dart';

// ── Category definitions ───────────────────────────────────────────────────────

const _categories = [
  ('エンドポイント', [DeviceType.pc, DeviceType.laptop, DeviceType.server, DeviceType.iotDevice]),
  ('インフラ', [DeviceType.router, DeviceType.l3Switch, DeviceType.switch_, DeviceType.hub,
               DeviceType.bridge, DeviceType.wirelessAP, DeviceType.natGateway]),
  ('セキュリティ', [DeviceType.firewall, DeviceType.ids, DeviceType.ips,
                  DeviceType.vpnGateway, DeviceType.ipSecTunnel, DeviceType.greTunnel]),
  ('WAN/キャリア', [DeviceType.internetCloud, DeviceType.mplsCloud, DeviceType.lteNetwork,
                   DeviceType.fiveGNetwork, DeviceType.satelliteNetwork,
                   DeviceType.activeDirectoryServer]),
  ('SDN', [DeviceType.openFlowSwitch, DeviceType.sdnController]),
];

// ── DevicePalette ─────────────────────────────────────────────────────────────

class DevicePalette extends StatefulWidget {
  const DevicePalette({super.key});

  @override
  State<DevicePalette> createState() => _DevicePaletteState();
}

class _DevicePaletteState extends State<DevicePalette>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.22,
      minChildSize: 0.08,
      maxChildSize: 0.5,
      snap: true,
      builder: (ctx, ctrl) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
        ),
        child: Column(
          children: [
            _Handle(),
            TabBar(
              controller: _tab,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: _categories.map((c) => Tab(text: c.$1, height: 32)).toList(),
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: _categories.map((c) => _PaletteGrid(types: c.$2)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      width: 36, height: 4,
      decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
    ),
  );
}

// ── Grid of draggable device cards ────────────────────────────────────────────

class _PaletteGrid extends StatelessWidget {
  final List<DeviceType> types;
  const _PaletteGrid({required this.types});

  @override
  Widget build(BuildContext context) => GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, childAspectRatio: 0.85, crossAxisSpacing: 4, mainAxisSpacing: 4),
        itemCount: types.length,
        itemBuilder: (_, i) => _DeviceCard(type: types[i]),
      );
}

class _DeviceCard extends StatelessWidget {
  final DeviceType type;
  const _DeviceCard({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = deviceColor(type);
    final icon = deviceIcon(type);
    final label = type.name.replaceAllMapped(
        RegExp(r'([A-Z])'), (m) => ' ${m[0]}').trim();

    return Draggable<DeviceType>(
      data: type,
      feedback: Material(
        shape: const CircleBorder(),
        color: color,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _card(color, icon, label)),
      child: _card(color, icon, label),
    );
  }

  Widget _card(Color color, IconData icon, String label) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      CircleAvatar(backgroundColor: color, radius: 20,
          child: Icon(icon, color: Colors.white, size: 20)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 9), textAlign: TextAlign.center, maxLines: 2),
    ],
  );
}
