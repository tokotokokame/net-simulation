// lib/models/link.dart

enum LinkType { standard, logical }

class Link {
  final String id;
  final String deviceAId;
  final String deviceBId;
  final String interfaceAName;
  final String interfaceBName;
  final int bandwidth; // bps
  final double latency; // ms
  final double packetLoss; // 0.0–1.0
  final LinkType type;
  final bool isActive;

  const Link({
    required this.id,
    required this.deviceAId,
    required this.deviceBId,
    required this.interfaceAName,
    required this.interfaceBName,
    this.bandwidth = 1000000,
    this.latency = 1.0,
    this.packetLoss = 0.0,
    this.type = LinkType.standard,
    this.isActive = true,
  });

  Link copyWith({
    String? id,
    String? deviceAId,
    String? deviceBId,
    String? interfaceAName,
    String? interfaceBName,
    int? bandwidth,
    double? latency,
    double? packetLoss,
    LinkType? type,
    bool? isActive,
  }) {
    return Link(
      id: id ?? this.id,
      deviceAId: deviceAId ?? this.deviceAId,
      deviceBId: deviceBId ?? this.deviceBId,
      interfaceAName: interfaceAName ?? this.interfaceAName,
      interfaceBName: interfaceBName ?? this.interfaceBName,
      bandwidth: bandwidth ?? this.bandwidth,
      latency: latency ?? this.latency,
      packetLoss: packetLoss ?? this.packetLoss,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'deviceAId': deviceAId,
        'deviceBId': deviceBId,
        'interfaceAName': interfaceAName,
        'interfaceBName': interfaceBName,
        'bandwidth': bandwidth,
        'latency': latency,
        'packetLoss': packetLoss,
        'type': type.name,
        'isActive': isActive,
      };

  factory Link.fromJson(Map<String, dynamic> json) {
    return Link(
      id: json['id'] as String,
      deviceAId: json['deviceAId'] as String,
      deviceBId: json['deviceBId'] as String,
      interfaceAName: json['interfaceAName'] as String,
      interfaceBName: json['interfaceBName'] as String,
      bandwidth: json['bandwidth'] as int? ?? 1000000,
      latency: (json['latency'] as num?)?.toDouble() ?? 1.0,
      packetLoss: (json['packetLoss'] as num?)?.toDouble() ?? 0.0,
      type: LinkType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => LinkType.standard,
      ),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  @override
  String toString() =>
      'Link($id, $deviceAId:$interfaceAName ↔ $deviceBId:$interfaceBName)';
}
