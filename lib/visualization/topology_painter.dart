// lib/visualization/topology_painter.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/attack_packet.dart';
import '../models/device.dart';
import '../models/link.dart';
import '../models/packet.dart';
import '../models/topology.dart';
import 'device_style.dart';
import 'packet_particle.dart';

class TopologyPainter extends CustomPainter {
  final Topology topology;
  final String? selectedDeviceId;
  final List<PacketParticle> particles;

  /// Attack packets currently in flight (for overlay rendering).
  final List<AttackPacket> attackPackets;

  /// IDs of devices that have been detected/alerted by IDS.
  final Set<String> alertedDeviceIds;

  static const double kR = 28.0;
  static const double kGrid = 20.0;

  const TopologyPainter({
    required this.topology,
    this.selectedDeviceId,
    this.particles = const [],
    this.attackPackets = const [],
    this.alertedDeviceIds = const {},
  });

  @override
  void paint(Canvas canvas, Size size) {
    _grid(canvas, size);
    for (final l in topology.links) { _link(canvas, l); }
    for (final d in topology.devices) { _device(canvas, d); }
    for (final p in particles) { _particle(canvas, p); }
    _attackOverlay(canvas);
  }

  // ── Attack overlay ────────────────────────────────────────────────────────

  void _attackOverlay(Canvas canvas) {
    // Warning rings on alerted devices.
    for (final id in alertedDeviceIds) {
      final pos = _pos(id);
      if (pos == null) continue;
      _alertRing(canvas, pos);
    }
    // Attack particles.
    for (final pkt in attackPackets) {
      final src = _pos(pkt.attackerId);
      final dst = _pos(pkt.targetId);
      if (src == null || dst == null) continue;
      _attackParticle(canvas, pkt, src, dst);
    }
  }

  void _attackParticle(Canvas canvas, AttackPacket pkt, Offset src, Offset dst) {
    // Lerp position based on a repeatable deterministic offset per packet id.
    final seed = pkt.id.hashCode & 0xFF;
    final t = (seed / 255.0);
    final pos = Offset.lerp(src, dst, t)!;

    switch (pkt.attackType) {
      // DoS floods → red dots
      case AttackType.dosSynFlood:
      case AttackType.dosUdpFlood:
      case AttackType.dosIcmpFlood:
        canvas.drawCircle(pos, 3,
            Paint()..color = Colors.red.withValues(alpha: 0.85));
      // Port scans → yellow fan
      case AttackType.portScanTcp:
      case AttackType.portScanUdp:
      case AttackType.portScanStealth:
        final angle = (seed / 255.0) * math.pi / 4 - math.pi / 8;
        final fanned = pos + Offset(math.cos(angle) * 6, math.sin(angle) * 6);
        canvas.drawCircle(fanned, 3,
            Paint()..color = Colors.yellow[700]!.withValues(alpha: 0.9));
      // ARP / MitM → purple
      case AttackType.arpSpoofing:
      case AttackType.manInTheMiddle:
        canvas.drawCircle(pos, 4,
            Paint()..color = Colors.purple.withValues(alpha: 0.85));
      // DNS amplification → orange
      case AttackType.dnsAmplification:
        canvas.drawCircle(pos, 3,
            Paint()..color = Colors.orange.withValues(alpha: 0.9));
    }

    // Dropped / blocked → red ✕
    if (pkt.status == PacketStatus.dropped) {
      _crossMark(canvas, pos, 5, Colors.red);
    }
  }

  /// Red pulsing ring around a device that triggered an IDS alert.
  void _alertRing(Canvas canvas, Offset center) {
    canvas.drawCircle(
      center,
      kR + 10,
      Paint()
        ..color = Colors.red.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(
      center,
      kR + 16,
      Paint()
        ..color = Colors.red.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _grid(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.grey[300]!;
    for (int c = 0; c <= size.width ~/ kGrid + 1; c++) {
      for (int r = 0; r <= size.height ~/ kGrid + 1; r++) {
        canvas.drawCircle(Offset(c * kGrid, r * kGrid), 1.5, p);
      }
    }
  }

  void _link(Canvas canvas, Link link) {
    final a = _pos(link.deviceAId), b = _pos(link.deviceBId);
    if (a == null || b == null) return;
    final color = link.isActive ? Colors.grey[700]! : Colors.red;
    final p = Paint()..color = color..strokeWidth = link.isActive ? 2 : 2.5..style = PaintingStyle.stroke;
    link.isActive && link.type == LinkType.standard
        ? canvas.drawLine(a, b, p)
        : _dashed(canvas, a, b, p);
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint p) {
    final dx = b.dx - a.dx, dy = b.dy - a.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len == 0) return;
    final ux = dx / len, uy = dy / len;
    double t = 0; bool draw = true;
    while (t < len) {
      final t2 = math.min(t + (draw ? 8.0 : 5.0), len);
      if (draw) canvas.drawLine(Offset(a.dx + ux * t, a.dy + uy * t), Offset(a.dx + ux * t2, a.dy + uy * t2), p);
      t = t2; draw = !draw;
    }
  }

  void _device(Canvas canvas, Device d) {
    final c = Offset(d.x, d.y);
    if (d.id == selectedDeviceId) {
      canvas.drawCircle(c, kR + 6,
          Paint()
            ..color = Colors.blue
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
    }
    _shape(canvas, c, d.type);
    _icon(canvas, c, d.type);
    _label(canvas, c, d.name);
    // Crashed device overlay (all interfaces down)
    final allDown = d.interfaces.isNotEmpty && d.interfaces.every((i) => i.status.name == 'down');
    if (allDown) { _crossMark(canvas, c, kR, Colors.red); }
  }

  void _shape(Canvas canvas, Offset c, DeviceType t) {
    final color = deviceColor(t);
    final fill = Paint()..color = color;
    final stroke = Paint()..color = color.withValues(alpha: 0.7)..strokeWidth = 2..style = PaintingStyle.stroke;
    switch (deviceShape(t)) {
      case DeviceShape.circle:
        canvas.drawCircle(c, kR, fill); canvas.drawCircle(c, kR, stroke);
      case DeviceShape.hexagon:
        final hex = _hex(c);
        canvas.drawPath(hex, fill); canvas.drawPath(hex, stroke);
      case DeviceShape.roundRect:
        final rr = RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: kR * 2, height: kR * 2), const Radius.circular(8));
        canvas.drawRRect(rr, fill); canvas.drawRRect(rr, stroke);
    }
  }

  Path _hex(Offset center) {
    final p = Path();
    for (int i = 0; i < 6; i++) {
      final a = math.pi / 180 * (60 * i - 30);
      final pt = Offset(center.dx + kR * math.cos(a), center.dy + kR * math.sin(a));
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  void _icon(Canvas canvas, Offset center, DeviceType type) {
    final icon = deviceIcon(type);
    final tp = TextPainter(
      text: TextSpan(text: String.fromCharCode(icon.codePoint),
          style: TextStyle(fontSize: 20, fontFamily: icon.fontFamily, package: icon.fontPackage, color: Colors.white)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _label(Canvas canvas, Offset center, String name) {
    final tp = TextPainter(
      text: TextSpan(
        text: name,
        style: const TextStyle(
          color: Color(0xFF1A1A2E),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 100);

    final labelX = center.dx - tp.width / 2;
    final labelY = center.dy + kR + 6;

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(labelX - 4, labelY - 2, tp.width + 8, tp.height + 4),
      const Radius.circular(4),
    );

    canvas.drawRRect(bgRect,
        Paint()
          ..color = Colors.black26
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawRRect(bgRect,
        Paint()..color = const Color(0xEEF5F5F5));
    tp.paint(canvas, Offset(labelX, labelY));
  }

  void _particle(Canvas canvas, PacketParticle p) {
    final opacity = p.status == PacketStatus.delivered ? (1.0 - p.progress * 0.5).clamp(0.0, 1.0) : 1.0;
    final paint = Paint()..color = p.color.withValues(alpha: opacity);
    canvas.drawCircle(p.currentPosition, p.radius, paint);
    if (p.status == PacketStatus.dropped) { _crossMark(canvas, p.currentPosition, p.radius, Colors.red); }
  }

  void _crossMark(Canvas canvas, Offset c, double r, Color color) {
    final p = Paint()..color = color..strokeWidth = 2..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(c.dx - r * 0.6, c.dy - r * 0.6), Offset(c.dx + r * 0.6, c.dy + r * 0.6), p);
    canvas.drawLine(Offset(c.dx + r * 0.6, c.dy - r * 0.6), Offset(c.dx - r * 0.6, c.dy + r * 0.6), p);
  }

  Offset? _pos(String id) {
    final d = topology.devices.where((e) => e.id == id).firstOrNull;
    return d == null ? null : Offset(d.x, d.y);
  }

  @override
  bool shouldRepaint(TopologyPainter old) =>
      old.topology != topology ||
      old.selectedDeviceId != selectedDeviceId ||
      old.particles != particles ||
      old.attackPackets != attackPackets ||
      old.alertedDeviceIds != alertedDeviceIds;

  /// Returns the ID of the first device within [hitRadius]px of [tap], or null.
  static String? deviceAt(
    Offset tap,
    List<Device> devices, {
    double hitRadius = 30.0,
  }) {
    final r2 = hitRadius * hitRadius;
    for (final d in devices) {
      final dx = d.x - tap.dx, dy = d.y - tap.dy;
      if (dx * dx + dy * dy <= r2) return d.id;
    }
    return null;
  }
}
