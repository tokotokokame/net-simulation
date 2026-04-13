// lib/models/topology.dart
import 'device.dart';
import 'link.dart';

const int kMaxDevices = 100;
const int kMaxLinks = 200;

class TopologyValidationError implements Exception {
  final String message;
  const TopologyValidationError(this.message);
  @override
  String toString() => 'TopologyValidationError: $message';
}

class Topology {
  final String id;
  final String name;
  final List<Device> devices;
  final List<Link> links;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Topology({
    required this.id,
    required this.name,
    required this.devices,
    required this.links,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Throws [TopologyValidationError] if constraints are violated.
  void validate() {
    if (devices.length > kMaxDevices) {
      throw TopologyValidationError(
          'Device count ${devices.length} exceeds max $kMaxDevices');
    }
    if (links.length > kMaxLinks) {
      throw TopologyValidationError(
          'Link count ${links.length} exceeds max $kMaxLinks');
    }
  }

  Topology copyWith({
    String? id,
    String? name,
    List<Device>? devices,
    List<Link>? links,
    DateTime? updatedAt,
  }) {
    final updated = Topology(
      id: id ?? this.id,
      name: name ?? this.name,
      devices: devices ?? this.devices,
      links: links ?? this.links,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
    updated.validate();
    return updated;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'devices': devices.map((d) => d.toJson()).toList(),
        'links': links.map((l) => l.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Topology.fromJson(Map<String, dynamic> json) {
    final topology = Topology(
      id: json['id'] as String,
      name: json['name'] as String,
      devices: (json['devices'] as List<dynamic>)
          .map((e) => Device.fromJson(e as Map<String, dynamic>))
          .toList(),
      links: (json['links'] as List<dynamic>)
          .map((e) => Link.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
    topology.validate();
    return topology;
  }

  factory Topology.empty({required String id, required String name}) {
    final now = DateTime.now();
    return Topology(
      id: id,
      name: name,
      devices: const [],
      links: const [],
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  String toString() =>
      'Topology($id, "$name", ${devices.length} devices, ${links.length} links)';
}
