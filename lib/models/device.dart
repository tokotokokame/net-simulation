// lib/models/device.dart
import 'network_interface.dart';

enum DeviceType {
  router,
  l3Switch,
  switch_,
  hub,
  bridge,
  pc,
  laptop,
  server,
  iotDevice,
  wirelessAP,
  firewall,
  ids,
  ips,
  natGateway,
  internetCloud,
  mplsCloud,
  lteNetwork,
  fiveGNetwork,
  satelliteNetwork,
  vpnGateway,
  ipSecTunnel,
  greTunnel,
  activeDirectoryServer,
  openFlowSwitch,
  sdnController,
}

class Device {
  final String id;
  final DeviceType type;
  final String name;
  final double x;
  final double y;
  final List<NetworkInterface> interfaces;

  const Device({
    required this.id,
    required this.type,
    required this.name,
    required this.x,
    required this.y,
    this.interfaces = const [],
  });

  Device copyWith({
    String? id,
    DeviceType? type,
    String? name,
    double? x,
    double? y,
    List<NetworkInterface>? interfaces,
  }) {
    return Device(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      x: x ?? this.x,
      y: y ?? this.y,
      interfaces: interfaces ?? this.interfaces,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'name': name,
        'position': {'x': x, 'y': y},
        'interfaces': interfaces.map((i) => i.toJson()).toList(),
        'routing': {'rib': [], 'fib': []},
        'arpTable': [],
        'natTable': [],
        'firewallRules': [],
      };

  factory Device.fromJson(Map<String, dynamic> json) {
    final pos = json['position'] as Map<String, dynamic>;
    return Device(
      id: json['id'] as String,
      type: DeviceType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => DeviceType.pc,
      ),
      name: json['name'] as String,
      x: (pos['x'] as num).toDouble(),
      y: (pos['y'] as num).toDouble(),
      interfaces: (json['interfaces'] as List<dynamic>?)
              ?.map((e) =>
                  NetworkInterface.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  @override
  String toString() => 'Device($id, $name, ${type.name})';
}
