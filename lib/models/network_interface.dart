// lib/models/network_interface.dart

enum InterfaceStatus { up, down }

enum VlanMode { access, trunk }

enum Duplex { half, full }

class NetworkInterface {
  final String name;
  final String ip;
  final int subnet;
  final String mac;
  final InterfaceStatus status;
  final int queueSize;
  final int? vlan;
  final int bandwidth; // bps
  final VlanMode? vlanMode;
  final int mtu;          // bytes, default 1500 (range 576–9000)
  final Duplex duplex;    // half / full

  const NetworkInterface({
    required this.name,
    required this.ip,
    required this.subnet,
    required this.mac,
    this.status = InterfaceStatus.up,
    this.queueSize = 100,
    this.vlan,
    this.bandwidth = 1000000,
    this.vlanMode,
    this.mtu = 1500,
    this.duplex = Duplex.full,
  });

  NetworkInterface copyWith({
    String? name,
    String? ip,
    int? subnet,
    String? mac,
    InterfaceStatus? status,
    int? queueSize,
    int? vlan,
    int? bandwidth,
    VlanMode? vlanMode,
    int? mtu,
    Duplex? duplex,
  }) {
    return NetworkInterface(
      name: name ?? this.name,
      ip: ip ?? this.ip,
      subnet: subnet ?? this.subnet,
      mac: mac ?? this.mac,
      status: status ?? this.status,
      queueSize: queueSize ?? this.queueSize,
      vlan: vlan ?? this.vlan,
      bandwidth: bandwidth ?? this.bandwidth,
      vlanMode: vlanMode ?? this.vlanMode,
      mtu: mtu ?? this.mtu,
      duplex: duplex ?? this.duplex,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'ip': ip,
        'subnet': subnet,
        'mac': mac,
        'status': status.name,
        'queueSize': queueSize,
        'vlan': vlan,
        'bandwidth': bandwidth,
        'vlanMode': vlanMode?.name,
        'mtu': mtu,
        'duplex': duplex.name,
      };

  factory NetworkInterface.fromJson(Map<String, dynamic> json) {
    return NetworkInterface(
      name: json['name'] as String,
      ip: json['ip'] as String,
      subnet: json['subnet'] as int,
      mac: json['mac'] as String,
      status: InterfaceStatus.values.firstWhere(
        (e) => e.name == (json['status'] ?? 'up'),
        orElse: () => InterfaceStatus.up,
      ),
      queueSize: json['queueSize'] as int? ?? 100,
      vlan: json['vlan'] as int?,
      bandwidth: json['bandwidth'] as int? ?? 1000000,
      vlanMode: json['vlanMode'] != null
          ? VlanMode.values.firstWhere((e) => e.name == json['vlanMode'])
          : null,
      mtu: json['mtu'] as int? ?? 1500,
      duplex: json['duplex'] != null
          ? Duplex.values.firstWhere((e) => e.name == json['duplex'],
              orElse: () => Duplex.full)
          : Duplex.full,
    );
  }

  @override
  String toString() => 'NetworkInterface($name, $ip/$subnet, ${status.name})';
}
