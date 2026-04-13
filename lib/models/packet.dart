// lib/models/packet.dart

enum ProtocolType { tcp, udp, icmp, arp, ospf, bgp }

enum PacketStatus { inTransit, delivered, dropped, delayed }

class TcpFlags {
  final bool syn;
  final bool ack;
  final bool fin;
  final bool rst;

  const TcpFlags({
    this.syn = false,
    this.ack = false,
    this.fin = false,
    this.rst = false,
  });

  Map<String, dynamic> toJson() =>
      {'syn': syn, 'ack': ack, 'fin': fin, 'rst': rst};

  factory TcpFlags.fromJson(Map<String, dynamic> json) => TcpFlags(
        syn: json['syn'] as bool? ?? false,
        ack: json['ack'] as bool? ?? false,
        fin: json['fin'] as bool? ?? false,
        rst: json['rst'] as bool? ?? false,
      );
}

class Packet {
  final String id;
  final String sourceIp;
  final String destinationIp;
  final int sourcePort;
  final int destinationPort;
  final ProtocolType protocol;
  final int size; // bytes
  final int ttl;
  final TcpFlags? tcpFlags;
  final PacketStatus status;
  final int? vlanTag;
  final int? mplsLabel;
  final String? droppedReason;

  const Packet({
    required this.id,
    required this.sourceIp,
    required this.destinationIp,
    required this.sourcePort,
    required this.destinationPort,
    required this.protocol,
    this.size = 64,
    this.ttl = 64,
    this.tcpFlags,
    this.status = PacketStatus.inTransit,
    this.vlanTag,
    this.mplsLabel,
    this.droppedReason,
  });

  Packet copyWith({
    String? id,
    String? sourceIp,
    String? destinationIp,
    int? sourcePort,
    int? destinationPort,
    ProtocolType? protocol,
    int? size,
    int? ttl,
    TcpFlags? tcpFlags,
    PacketStatus? status,
    int? vlanTag,
    int? mplsLabel,
    String? droppedReason,
  }) {
    return Packet(
      id: id ?? this.id,
      sourceIp: sourceIp ?? this.sourceIp,
      destinationIp: destinationIp ?? this.destinationIp,
      sourcePort: sourcePort ?? this.sourcePort,
      destinationPort: destinationPort ?? this.destinationPort,
      protocol: protocol ?? this.protocol,
      size: size ?? this.size,
      ttl: ttl ?? this.ttl,
      tcpFlags: tcpFlags ?? this.tcpFlags,
      status: status ?? this.status,
      vlanTag: vlanTag ?? this.vlanTag,
      mplsLabel: mplsLabel ?? this.mplsLabel,
      droppedReason: droppedReason ?? this.droppedReason,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceIp': sourceIp,
        'destinationIp': destinationIp,
        'sourcePort': sourcePort,
        'destinationPort': destinationPort,
        'protocol': protocol.name,
        'size': size,
        'ttl': ttl,
        'tcpFlags': tcpFlags?.toJson(),
        'status': status.name,
        'vlanTag': vlanTag,
        'mplsLabel': mplsLabel,
        'droppedReason': droppedReason,
      };

  factory Packet.fromJson(Map<String, dynamic> json) {
    return Packet(
      id: json['id'] as String,
      sourceIp: json['sourceIp'] as String,
      destinationIp: json['destinationIp'] as String,
      sourcePort: json['sourcePort'] as int,
      destinationPort: json['destinationPort'] as int,
      protocol: ProtocolType.values
          .firstWhere((e) => e.name == json['protocol']),
      size: json['size'] as int? ?? 64,
      ttl: json['ttl'] as int? ?? 64,
      tcpFlags: json['tcpFlags'] != null
          ? TcpFlags.fromJson(json['tcpFlags'] as Map<String, dynamic>)
          : null,
      status: PacketStatus.values.firstWhere(
        (e) => e.name == (json['status'] ?? 'inTransit'),
        orElse: () => PacketStatus.inTransit,
      ),
      vlanTag: json['vlanTag'] as int?,
      mplsLabel: json['mplsLabel'] as int?,
      droppedReason: json['droppedReason'] as String?,
    );
  }

  @override
  String toString() => 'Packet($id, $sourceIp→$destinationIp, ${protocol.name})';
}
