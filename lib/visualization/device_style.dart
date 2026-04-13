// lib/visualization/device_style.dart
import 'package:flutter/material.dart';
import '../models/device.dart';

enum DeviceShape { circle, hexagon, roundRect }

Color deviceColor(DeviceType t) => switch (t) {
      DeviceType.router => Colors.blue,
      DeviceType.l3Switch || DeviceType.switch_ => Colors.green,
      DeviceType.firewall || DeviceType.ids || DeviceType.ips => Colors.red,
      DeviceType.internetCloud ||
      DeviceType.mplsCloud ||
      DeviceType.lteNetwork ||
      DeviceType.fiveGNetwork ||
      DeviceType.satelliteNetwork =>
        Colors.purple,
      DeviceType.sdnController || DeviceType.openFlowSwitch => Colors.teal,
      DeviceType.vpnGateway ||
      DeviceType.ipSecTunnel ||
      DeviceType.greTunnel =>
        Colors.orange,
      _ => Colors.blueGrey,
    };

IconData deviceIcon(DeviceType t) => switch (t) {
      DeviceType.router => Icons.router,
      DeviceType.l3Switch || DeviceType.switch_ => Icons.device_hub,
      DeviceType.hub || DeviceType.bridge => Icons.hub,
      DeviceType.pc => Icons.computer,
      DeviceType.laptop => Icons.laptop,
      DeviceType.server || DeviceType.activeDirectoryServer => Icons.dns,
      DeviceType.firewall || DeviceType.ids || DeviceType.ips => Icons.shield,
      DeviceType.wirelessAP => Icons.wifi,
      DeviceType.natGateway => Icons.swap_horiz,
      DeviceType.internetCloud => Icons.cloud,
      DeviceType.mplsCloud => Icons.cloud_queue,
      DeviceType.lteNetwork || DeviceType.fiveGNetwork => Icons.cell_tower,
      DeviceType.satelliteNetwork => Icons.satellite_alt,
      DeviceType.vpnGateway => Icons.vpn_lock,
      DeviceType.ipSecTunnel || DeviceType.greTunnel => Icons.lock,
      DeviceType.iotDevice => Icons.sensors,
      DeviceType.openFlowSwitch || DeviceType.sdnController => Icons.account_tree,
    };

DeviceShape deviceShape(DeviceType t) => switch (t) {
      DeviceType.router ||
      DeviceType.internetCloud ||
      DeviceType.mplsCloud =>
        DeviceShape.circle,
      DeviceType.firewall || DeviceType.ids || DeviceType.ips =>
        DeviceShape.hexagon,
      _ => DeviceShape.roundRect,
    };
