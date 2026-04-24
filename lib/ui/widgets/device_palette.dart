// lib/ui/widgets/device_palette.dart
import 'package:flutter/material.dart';
import '../../models/device.dart';
import '../../app/theme.dart';
import '../../visualization/device_style.dart';

// ── Category data ─────────────────────────────────────────────────────────────

const _categories = [
  ('エンドポイント', [
    (DeviceType.pc, 'PC'), (DeviceType.laptop, 'Laptop'),
    (DeviceType.server, 'Server'), (DeviceType.iotDevice, 'IoT'),
  ]),
  ('インフラ', [
    (DeviceType.router, 'Router'), (DeviceType.l3Switch, 'L3SW'),
    (DeviceType.switch_, 'Switch'), (DeviceType.hub, 'Hub'),
    (DeviceType.wirelessAP, 'AP'), (DeviceType.natGateway, 'NAT'),
  ]),
  ('セキュリティ', [
    (DeviceType.firewall, 'FW'), (DeviceType.ids, 'IDS'),
    (DeviceType.ips, 'IPS'), (DeviceType.vpnGateway, 'VPN'),
  ]),
  ('WAN', [
    (DeviceType.internetCloud, 'Internet'), (DeviceType.lteNetwork, 'LTE'),
    (DeviceType.fiveGNetwork, '5G'), (DeviceType.mplsCloud, 'MPLS'),
  ]),
  ('SDN', [
    (DeviceType.sdnController, 'SDNC'), (DeviceType.openFlowSwitch, 'OFSwitch'),
  ]),
];

// ── DevicePalette ─────────────────────────────────────────────────────────────

class DevicePalette extends StatefulWidget {
  final void Function(DeviceType type)? onDeviceSelected;
  const DevicePalette({super.key, this.onDeviceSelected});

  @override
  State<DevicePalette> createState() => _DevicePaletteState();
}

class _DevicePaletteState extends State<DevicePalette> {
  int _cat = 0;

  @override
  Widget build(BuildContext context) {
    final fs = AppTheme.fontSize(context);
    final pad = AppTheme.palettePadding(context);
    final surface = Theme.of(context).colorScheme.surface;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(child: Container(margin: const EdgeInsets.symmetric(vertical: 8),
              width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
          // Category tabs
          SizedBox(
            height: 34,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: pad),
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final sel = i == _cat;
                return GestureDetector(
                  onTap: () => setState(() => _cat = i),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: pad * 1.5, vertical: 4),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(
                        color: sel ? Colors.blue : Colors.transparent, width: 2))),
                    child: Text(_categories[i].$1,
                        style: TextStyle(color: sel ? Colors.blue : Colors.white54, fontSize: fs)),
                  ),
                );
              },
            ),
          ),
          // Device items
          SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: pad / 2),
              itemCount: _categories[_cat].$2.length,
              itemBuilder: (_, i) {
                final (type, label) = _categories[_cat].$2[i];
                final color = deviceColor(type);
                final icon = deviceIcon(type);
                return _DeviceTile(
                  type: type, color: color, icon: icon, label: label,
                  onTap: () => widget.onDeviceSelected?.call(type),
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final DeviceType type;
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DeviceTile({required this.type, required this.color, required this.icon,
      required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fs = AppTheme.fontSize(context);
    return Draggable<DeviceType>(
      data: type,
      feedback: Material(shape: const CircleBorder(), color: color,
          child: Padding(padding: const EdgeInsets.all(10), child: Icon(icon, color: Colors.white, size: 22))),
      childWhenDragging: Opacity(opacity: 0.3, child: _tile(fs)),
      child: GestureDetector(onTap: onTap, child: _tile(fs)),
    );
  }

  Widget _tile(double fs) => SizedBox(
    width: 64,
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      CircleAvatar(backgroundColor: color, radius: 18, child: Icon(icon, color: Colors.white, size: 18)),
      const SizedBox(height: 3),
      Text(label, style: TextStyle(fontSize: fs - 2), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
    ]),
  );
}
