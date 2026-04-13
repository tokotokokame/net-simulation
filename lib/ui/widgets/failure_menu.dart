// lib/ui/widgets/failure_menu.dart
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/device.dart';
import '../../models/link.dart';
import '../../models/network_interface.dart';
import '../screens/topology_state.dart';

/// Shows a context menu for link failure simulation.
Future<void> showLinkFailureMenu(
    BuildContext context, WidgetRef ref, Link link, Offset position) async {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final relPos = RelativeRect.fromRect(
      Rect.fromLTWH(position.dx, position.dy, 0, 0),
      Rect.fromLTWH(0, 0, overlay.size.width, overlay.size.height));

  final result = await showMenu<String>(
    context: context,
    position: relPos,
    items: link.isActive
        ? [const PopupMenuItem(value: 'fail', child: Row(children: [
              Icon(Icons.link_off, color: Colors.red, size: 18),
              SizedBox(width: 8), Text('リンク障害をシミュレート')]))]
        : [const PopupMenuItem(value: 'restore', child: Row(children: [
              Icon(Icons.link, color: Colors.green, size: 18),
              SizedBox(width: 8), Text('リンクを復旧')]))],
  );

  if (result == 'fail') {
    ref.read(topologyProvider.notifier).removeLink(link.id);
    ref.read(topologyProvider.notifier).addLink(link.copyWith(isActive: false));
    log('Link failure simulated: ${link.id}', name: 'Failure');
  } else if (result == 'restore') {
    ref.read(topologyProvider.notifier).removeLink(link.id);
    ref.read(topologyProvider.notifier).addLink(link.copyWith(isActive: true));
    log('Link restored: ${link.id}', name: 'Failure');
  }
}

/// Shows a context menu for device crash simulation.
Future<void> showDeviceFailureMenu(
    BuildContext context, WidgetRef ref, Device device, Offset position) async {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final relPos = RelativeRect.fromRect(
      Rect.fromLTWH(position.dx, position.dy, 0, 0),
      Rect.fromLTWH(0, 0, overlay.size.width, overlay.size.height));

  final allDown = device.interfaces.every((i) => i.status == InterfaceStatus.down);

  final result = await showMenu<String>(
    context: context,
    position: relPos,
    items: allDown
        ? [const PopupMenuItem(value: 'restore', child: Row(children: [
              Icon(Icons.power_settings_new, color: Colors.green, size: 18),
              SizedBox(width: 8), Text('デバイスを復旧')]))]
        : [const PopupMenuItem(value: 'crash', child: Row(children: [
              Icon(Icons.dangerous, color: Colors.red, size: 18),
              SizedBox(width: 8), Text('デバイスクラッシュをシミュレート')]))],
  );

  if (result == 'crash') {
    final crashed = device.copyWith(
      interfaces: device.interfaces.map((i) => i.copyWith(status: InterfaceStatus.down)).toList(),
    );
    ref.read(topologyProvider.notifier).updateDevice(crashed);
    log('Device crash simulated: ${device.id}', name: 'Failure');
  } else if (result == 'restore') {
    final restored = device.copyWith(
      interfaces: device.interfaces.map((i) => i.copyWith(status: InterfaceStatus.up)).toList(),
    );
    ref.read(topologyProvider.notifier).updateDevice(restored);
    log('Device restored: ${device.id}', name: 'Failure');
  }
}

/// Finds the link (if any) nearest to [canvasPos] within [threshold] pixels.
Link? hitTestLink(List<Link> links, Map<String, Offset> positions, Offset canvasPos,
    {double threshold = 12.0}) {
  for (final link in links) {
    final a = positions[link.deviceAId], b = positions[link.deviceBId];
    if (a == null || b == null) continue;
    if (_distToSegment(canvasPos, a, b) < threshold) return link;
  }
  return null;
}

double _distToSegment(Offset p, Offset a, Offset b) {
  final dx = b.dx - a.dx, dy = b.dy - a.dy;
  final lenSq = dx * dx + dy * dy;
  if (lenSq == 0) return (p - a).distance;
  final t = ((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / lenSq;
  final tc = t.clamp(0.0, 1.0);
  return (p - Offset(a.dx + tc * dx, a.dy + tc * dy)).distance;
}
