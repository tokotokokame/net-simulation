// lib/visualization/topology_painter.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/device.dart';
import '../models/link.dart';
import '../models/topology.dart';
import 'device_style.dart';

// ── Shared packet types (consumed by topology_editor_screen.dart) ─────────────

enum PktStatus { moving, dwelling, success, blocked }

class Pkt {
  final List<Offset> path;
  int       segIndex   = 0;
  double    progress   = 0.0;
  double    dwellTimer = 0.0;
  double    doneTimer  = 0.0; // counts up after success / blocked
  PktStatus status     = PktStatus.moving;
  Offset    position;

  final Stopwatch _sw = Stopwatch()..start();
  int get elapsedMs => _sw.elapsedMilliseconds;

  static const double kDoneDuration = 0.5; // seconds to show before removal

  Offset get currentNode => path[segIndex];
  Offset get nextNode    => path[segIndex + 1];

  Pkt({required this.path}) : position = path.first;

  bool get isFinished =>
      status == PktStatus.success || status == PktStatus.blocked;
}

// ── TopologyPainter ───────────────────────────────────────────────────────────

class TopologyPainter extends CustomPainter {
  final Topology  topology;
  final String?   selectedDeviceId;
  final List<Pkt> packets;

  static const double kR    = 28.0;
  static const double kGrid = 20.0;

  const TopologyPainter({
    required this.topology,
    this.selectedDeviceId,
    this.packets = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    _grid(canvas, size);
    _drawLinks(canvas);
    _drawDevices(canvas);
    _drawPackets(canvas);
  }

  // ── Grid ──────────────────────────────────────────────────────────────────
  void _grid(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.grey[300]!;
    for (int c = 0; c <= size.width ~/ kGrid + 1; c++) {
      for (int r = 0; r <= size.height ~/ kGrid + 1; r++) {
        canvas.drawCircle(Offset(c * kGrid, r * kGrid), 1.5, p);
      }
    }
  }

  // ── Links ─────────────────────────────────────────────────────────────────
  void _drawLinks(Canvas canvas) {
    for (final link in topology.links) {
      final a = _pos(link.deviceAId);
      final b = _pos(link.deviceBId);
      if (a == null || b == null) continue;
      final paint = Paint()
        ..color       = link.isActive ? Colors.grey[700]! : Colors.red.withValues(alpha: 0.85)
        ..strokeWidth = link.isActive
            ? (link.type == LinkType.standard ? 2.0 : 1.5)
            : 2.5
        ..style = PaintingStyle.stroke;
      link.isActive && link.type == LinkType.standard
          ? canvas.drawLine(a, b, paint)
          : _dashed(canvas, a, b, paint);
    }
  }

  // ── Devices ───────────────────────────────────────────────────────────────
  void _drawDevices(Canvas canvas) {
    for (final d in topology.devices) { _device(canvas, d); }
  }

  void _device(Canvas canvas, Device d) {
    final c = Offset(d.x, d.y);
    if (d.id == selectedDeviceId) {
      canvas.drawCircle(c, kR + 6,
          Paint()
            ..color       = Colors.blue
            ..style       = PaintingStyle.stroke
            ..strokeWidth = 3);
    }
    _shape(canvas, c, d.type);
    _icon(canvas, c, d.type);
    _label(canvas, c, d.name);
    final allDown = d.interfaces.isNotEmpty &&
        d.interfaces.every((i) => i.status.name == 'down');
    if (allDown) _crossMark(canvas, c, kR, Colors.red);
  }

  // ── Packets ───────────────────────────────────────────────────────────────
  void _drawPackets(Canvas canvas) {
    for (final pkt in packets) {
      final color = switch (pkt.status) {
        PktStatus.moving   => const Color(0xFF2196F3),
        PktStatus.dwelling => const Color(0xFFFF9800),
        PktStatus.success  => const Color(0xFF4CAF50),
        PktStatus.blocked  => const Color(0xFFF44336),
      };
      final radius = pkt.status == PktStatus.dwelling ? 7.0 : 5.0;

      // Glow
      canvas.drawCircle(pkt.position, radius * 2.5,
          Paint()
            ..color      = color.withValues(alpha: 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      // Body
      canvas.drawCircle(pkt.position, radius, Paint()..color = color);

      if (pkt.status == PktStatus.blocked) {
        _crossMark(canvas, pkt.position, radius, Colors.red);
      }
    }
  }

  // ── Shape helpers ─────────────────────────────────────────────────────────
  void _shape(Canvas canvas, Offset c, DeviceType t) {
    final color  = deviceColor(t);
    final fill   = Paint()..color = color;
    final stroke = Paint()
      ..color       = color.withValues(alpha: 0.7)
      ..strokeWidth = 2
      ..style       = PaintingStyle.stroke;
    switch (deviceShape(t)) {
      case DeviceShape.circle:
        canvas.drawCircle(c, kR, fill);
        canvas.drawCircle(c, kR, stroke);
      case DeviceShape.hexagon:
        final hex = _hex(c);
        canvas.drawPath(hex, fill);
        canvas.drawPath(hex, stroke);
      case DeviceShape.roundRect:
        final rr = RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: kR * 2, height: kR * 2),
            const Radius.circular(8));
        canvas.drawRRect(rr, fill);
        canvas.drawRRect(rr, stroke);
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
      text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(fontSize: 20, fontFamily: icon.fontFamily,
              package: icon.fontPackage, color: Colors.white)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _label(Canvas canvas, Offset center, String name) {
    final tp = TextPainter(
      text: TextSpan(text: name,
          style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 13,
              fontWeight: FontWeight.w600, height: 1.2)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 100);

    final labelX = center.dx - tp.width / 2;
    final labelY = center.dy + kR + 6;
    final bgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(labelX - 4, labelY - 2, tp.width + 8, tp.height + 4),
        const Radius.circular(4));
    canvas.drawRRect(bgRect,
        Paint()
          ..color      = Colors.black26
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawRRect(bgRect, Paint()..color = const Color(0xEEF5F5F5));
    tp.paint(canvas, Offset(labelX, labelY));
  }

  void _crossMark(Canvas canvas, Offset c, double r, Color color) {
    final p = Paint()..color = color..strokeWidth = 2..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(c.dx - r * 0.6, c.dy - r * 0.6),
        Offset(c.dx + r * 0.6, c.dy + r * 0.6), p);
    canvas.drawLine(Offset(c.dx + r * 0.6, c.dy - r * 0.6),
        Offset(c.dx - r * 0.6, c.dy + r * 0.6), p);
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint p) {
    final dx = b.dx - a.dx, dy = b.dy - a.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len == 0) return;
    final ux = dx / len, uy = dy / len;
    double t = 0; bool draw = true;
    while (t < len) {
      final t2 = math.min(t + (draw ? 8.0 : 5.0), len);
      if (draw) {
        canvas.drawLine(Offset(a.dx + ux * t, a.dy + uy * t),
            Offset(a.dx + ux * t2, a.dy + uy * t2), p);
      }
      t = t2; draw = !draw;
    }
  }

  Offset? _pos(String id) {
    final d = topology.devices.where((e) => e.id == id).firstOrNull;
    return d == null ? null : Offset(d.x, d.y);
  }

  @override
  bool shouldRepaint(TopologyPainter _) => true;

  static String? deviceAt(Offset tap, List<Device> devices,
      {double hitRadius = 30.0}) {
    final r2 = hitRadius * hitRadius;
    for (final d in devices) {
      final dx = d.x - tap.dx, dy = d.y - tap.dy;
      if (dx * dx + dy * dy <= r2) return d.id;
    }
    return null;
  }
}
