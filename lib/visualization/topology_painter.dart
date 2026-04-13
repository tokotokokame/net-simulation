// lib/visualization/topology_painter.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
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
  static const double kR = 28.0;
  static const double kGrid = 20.0;

  const TopologyPainter({
    required this.topology,
    this.selectedDeviceId,
    this.particles = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    _grid(canvas, size);
    for (final l in topology.links) { _link(canvas, l); }
    for (final d in topology.devices) { _device(canvas, d); }
    for (final p in particles) { _particle(canvas, p); }
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
      canvas.drawCircle(c, kR + 5, Paint()..color = Colors.blue.withValues(alpha: 0.35));
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
      text: TextSpan(text: name, style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w500)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 80);
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy + kR + 4));
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
      old.topology != topology || old.selectedDeviceId != selectedDeviceId || old.particles != particles;
}
