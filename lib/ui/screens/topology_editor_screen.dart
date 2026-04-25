// lib/ui/screens/topology_editor_screen.dart
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../auth/demo_timer_service.dart';
import '../../auth/auth_state.dart';
import '../../auth/user_auth_service.dart';
import '../../models/device.dart';
import '../../models/link.dart';
import '../../models/network_interface.dart';
import '../../simulation/simulation_engine.dart';
import '../../visualization/packet_particle.dart' show PacketParticle;
import '../../visualization/simulation_animator.dart';
import '../../visualization/topology_painter.dart';
import '../widgets/connection_dialog.dart'; import '../widgets/device_palette.dart';
import '../widgets/failure_menu.dart'; import '../widgets/paywall_dialog.dart';
import '../widgets/settings_sheet.dart'; import 'topology_state.dart';
import '../../storage/topology_storage.dart';

const _uuid = Uuid();
Offset _toCanvas(Offset local, Matrix4 m) {
  final s = m.storage;
  return Offset((local.dx - s[12]) / s[0], (local.dy - s[13]) / s[5]);
}
Offset _snap(Offset o, {double grid = 20}) =>
    Offset((o.dx / grid).round() * grid, (o.dy / grid).round() * grid);

class TopologyEditorScreen extends ConsumerStatefulWidget {
  const TopologyEditorScreen({super.key});
  @override
  ConsumerState<TopologyEditorScreen> createState() => _TopologyEditorScreenState();
}

class _TopologyEditorScreenState extends ConsumerState<TopologyEditorScreen>
    with SingleTickerProviderStateMixin {
  final _txCtrl = TransformationController();
  late final SimulationAnimator _animator;
  List<PacketParticle> _particles = [];
  String? _draggingDeviceId;

  @override
  void initState() { super.initState(); _animator = SimulationAnimator(this)..addListener(_onAnimFrame); }
  void _onAnimFrame() => setState(() => _particles = List.of(_animator.activeParticles));

  @override
  void dispose() { _animator.dispose(); _txCtrl.dispose(); super.dispose(); }

  Device? _hitTest(Offset local) {
    final c = _toCanvas(local, _txCtrl.value);
    const r = 30.0;
    return ref.read(topologyProvider).devices.where((d) {
      final dx = d.x - c.dx, dy = d.y - c.dy;
      return dx * dx + dy * dy <= r * r;
    }).firstOrNull;
  }

  void _addAtCenter(DeviceType type) {
    final sz = MediaQuery.of(context).size;
    final c = _snap(_toCanvas(Offset(sz.width / 2, sz.height / 2), _txCtrl.value));
    ref.read(topologyProvider.notifier).addDevice(Device(id: _uuid.v4(), type: type, name: type.name,
        x: c.dx, y: c.dy, interfaces: const [NetworkInterface(name: 'eth0', ip: '0.0.0.0', subnet: 24, mac: '00:00:00:00:00:00')]));
    developer.log('Added $type at $c', name: 'Editor');
  }

  void _addAtPosition(DeviceType type, Offset canvasPos) {
    final c = _snap(canvasPos);
    ref.read(topologyProvider.notifier).addDevice(Device(id: _uuid.v4(), type: type, name: type.name,
        x: c.dx, y: c.dy, interfaces: const [NetworkInterface(name: 'eth0', ip: '0.0.0.0', subnet: 24, mac: '00:00:00:00:00:00')]));
    developer.log('Dropped $type at $c', name: 'Editor');
  }

  // ── Long-press: context menu or link menu ─────────────────────────────────────

  void _onLongPressStart(LongPressStartDetails e) {
    final hit = _hitTest(e.localPosition);
    if (hit != null) {
      _showDeviceContextMenu(hit.id);
      return;
    }
    final topo = ref.read(topologyProvider);
    final posMap = {for (final d in topo.devices) d.id: Offset(d.x, d.y)};
    final link = hitTestLink(topo.links, posMap, _toCanvas(e.localPosition, _txCtrl.value));
    if (link != null) { showLinkFailureMenu(context, ref, link, e.globalPosition); }
  }

  void _showDeviceContextMenu(String deviceId) {
    final device = ref.read(topologyProvider).devices
        .where((d) => d.id == deviceId).firstOrNull;
    if (device == null) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.all(16),
            child: Text(device.name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('詳細設定'),
            onTap: () { Navigator.pop(ctx); context.push('/config/${device.id}'); },
          ),
          ListTile(
            leading: const Icon(Icons.open_with),
            title: const Text('移動'),
            onTap: () { Navigator.pop(ctx); setState(() => _draggingDeviceId = deviceId); },
          ),
          ListTile(
            leading: const Icon(Icons.warning_amber, color: Colors.orange),
            title: const Text('クラッシュをシミュレート',
                style: TextStyle(color: Colors.orange)),
            onTap: () {
              Navigator.pop(ctx);
              ref.read(topologyProvider.notifier).crashDevice(deviceId);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('削除', style: TextStyle(color: Colors.red)),
            onTap: () { Navigator.pop(ctx); _confirmDelete(deviceId, device.name); },
          ),
        ]),
      ),
    );
  }

  void _confirmDelete(String deviceId, String name) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('デバイスを削除'),
      content: Text('「$name」を削除しますか？\n接続されているリンクも削除されます。'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            ref.read(topologyProvider.notifier).removeDevice(deviceId);
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('削除'),
        ),
      ],
    ));
  }

  // ── Pan: canvas pan / device move (when _draggingDeviceId set) ───────────────

  void _onPanUpdate(DragUpdateDetails e) {
    if (_draggingDeviceId != null) {
      final pos = _toCanvas(e.localPosition, _txCtrl.value);
      ref.read(topologyProvider.notifier).moveDevice(_draggingDeviceId!, pos);
    } else {
      final m = _txCtrl.value.clone();
      m.storage[12] += e.delta.dx;
      m.storage[13] += e.delta.dy;
      _txCtrl.value = m;
    }
  }

  void _onPanEnd(DragEndDetails e) {
    if (_draggingDeviceId == null) return;
    final dev = ref.read(topologyProvider).devices
        .where((d) => d.id == _draggingDeviceId).firstOrNull;
    if (dev != null) {
      final s = _snap(Offset(dev.x, dev.y));
      ref.read(topologyProvider.notifier).moveDevice(_draggingDeviceId!, s);
    }
    setState(() => _draggingDeviceId = null);
  }

  void _onTap(Offset local) {
    final hit = _hitTest(local);
    final selected = ref.read(selectedDeviceIdProvider);

    // Empty area → deselect.
    if (hit == null) {
      ref.read(selectedDeviceIdProvider.notifier).state = null;
      return;
    }

    // Tap same device → deselect.
    if (selected == hit.id) {
      ref.read(selectedDeviceIdProvider.notifier).state = null;
      return;
    }

    // No device selected → select (highlight).
    if (selected == null) {
      ref.read(selectedDeviceIdProvider.notifier).state = hit.id;
      developer.log('Selected ${hit.name}', name: 'Editor');
      return;
    }

    // Different device already selected → show ConnectionDialog.
    final a = ref.read(topologyProvider).devices
        .where((d) => d.id == selected).firstOrNull;
    if (a != null) {
      ConnectionDialog.show(context, a, hit,
          (ifA, ifB, type, bw, lat, loss) => _addLink(a, hit, ifA, ifB, type, bw, lat, loss));
    }
    ref.read(selectedDeviceIdProvider.notifier).state = null;
  }

  void _addLink(Device a, Device b, String ifA, String ifB, LinkType type,
      int bandwidth, double latency, double packetLoss) {
    final link = Link(
      id: _uuid.v4(),
      deviceAId: a.id,
      deviceBId: b.id,
      interfaceAName: ifA,
      interfaceBName: ifB,
      type: type,
      bandwidth: bandwidth,
      latency: latency,
      packetLoss: packetLoss,
    );
    ref.read(topologyProvider.notifier).addLink(link);
    developer.log('Link added: ${a.name} ↔ ${b.name}', name: 'Editor');
  }

  void _editLink(Link link) {
    final topo = ref.read(topologyProvider);
    final a = topo.devices.where((d) => d.id == link.deviceAId).firstOrNull;
    final b = topo.devices.where((d) => d.id == link.deviceBId).firstOrNull;
    if (a == null || b == null) return;
    ConnectionDialog.showForLink(context, a, b, link, (type, bw, lat, loss) {
      ref.read(topologyProvider.notifier).updateLink(
          link.copyWith(type: type, bandwidth: bw, latency: lat, packetLoss: loss));
      developer.log('Link updated: ${a.name} ↔ ${b.name}', name: 'Editor');
    });
  }

  Future<void> _saveTopology() async {
    final topo = ref.read(topologyProvider);
    final ctrl = TextEditingController(text: topo.name);
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('トポロジを保存'),
          content: TextField(
            controller: ctrl, autofocus: true,
            decoration: const InputDecoration(
                labelText: '名前', border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('キャンセル')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: const Text('保存')),
          ],
        ),
      );
      if (name == null || name.isEmpty || !mounted) return;
      ref.read(topologyProvider.notifier).rename(name);
      await ref
          .read(topologyStorageProvider)
          .saveTopology(ref.read(topologyProvider));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"$name" を保存しました')));
      }
    } finally {
      ctrl.dispose();
    }
  }


  // Double-tap on a link opens the edit dialog.
  void _onDoubleTapLink(Offset local) {
    final topo = ref.read(topologyProvider);
    final posMap = {for (final d in topo.devices) d.id: Offset(d.x, d.y)};
    final link = hitTestLink(topo.links, posMap, _toCanvas(local, _txCtrl.value));
    if (link != null) _editLink(link);
  }

  @override
  Widget build(BuildContext context) {
    final topo = ref.watch(topologyProvider);
    final selected = ref.watch(selectedDeviceIdProvider);
    final engine = ref.watch(simulationEngineProvider);
    final isRunning = engine.simState == SimulationState.running;
    final authState = ref.watch(userAuthProvider);
    final timerSecs = ref.watch(demoRemainingProvider).valueOrNull;

    ref.listen(demoRemainingProvider, (_, next) {
      if (next.valueOrNull == 0) {
        ref.read(simulationEngineProvider.notifier).pause();
        PaywallDialog.show(context);
      }
    });

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(topo.name, style: const TextStyle(fontSize: 16)),
        actions: [
          if (authState is UnauthenticatedState && timerSecs != null)
            Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text('${timerSecs ~/ 60}m ${timerSecs % 60}s',
                  style: TextStyle(fontSize: 12,
                      color: timerSecs < 300 ? Colors.red : Colors.white70)))),
          IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: '保存',
              onPressed: _saveTopology),
          IconButton(
              icon: const Icon(Icons.folder_open_outlined),
              tooltip: '読み込み',
              onPressed: () => context.push('/topologies')),
          IconButton(icon: const Icon(Icons.bar_chart), tooltip: '統計',
              onPressed: () => context.push('/stats')),
          IconButton(icon: const Icon(Icons.security), tooltip: 'セキュリティテスト',
              onPressed: () => context.push('/pentest')),
          IconButton(icon: const Icon(Icons.settings), tooltip: '設定',
              onPressed: () => SettingsSheet.show(context)),
        ],
      ),
      body: Stack(children: [
        DragTarget<DeviceType>(
          onAcceptWithDetails: (details) {
            final box = context.findRenderObject()! as RenderBox;
            final local = box.globalToLocal(details.offset);
            _addAtPosition(details.data, _toCanvas(local, _txCtrl.value));
          },
          builder: (_, __, ___) => GestureDetector(
            onTapUp: (e) => _onTap(e.localPosition),
            onDoubleTapDown: (e) {
              final hit = _hitTest(e.localPosition);
              if (hit != null) { context.push('/config/${hit.id}'); return; }
              _onDoubleTapLink(e.localPosition);
            },
            // Long press: context menu (device) or link failure (empty).
            onLongPressStart: _onLongPressStart,
            // Pan: move device (if selected) or scroll canvas.
            onPanUpdate: _onPanUpdate,
            onPanEnd:    _onPanEnd,
            child: InteractiveViewer(
              transformationController: _txCtrl,
              panEnabled: false,
              minScale: 0.3, maxScale: 4.0, constrained: false,
              child: SizedBox(width: 3000, height: 3000,
                  child: CustomPaint(painter: TopologyPainter(topology: topo, selectedDeviceId: selected, particles: _particles))),
            ),
          ),
        ),
      ]),
      bottomSheet: SafeArea(
        minimum: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        child: SizedBox(
          height: 130,
          child: DevicePalette(onDeviceSelected: _addAtCenter),
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 130 + MediaQuery.of(context).padding.bottom + 8),
        child: FloatingActionButton(
          backgroundColor: isRunning ? Colors.red[700] : Colors.blue[700],
          onPressed: () {
            if (isRunning) { ref.read(simulationEngineProvider.notifier).pause(); _animator.stop(); }
            else { ref.read(simulationEngineProvider.notifier).start(topo); _animator.start(); }
          },
          child: Icon(isRunning ? Icons.stop : Icons.play_arrow, color: Colors.white, size: 30),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
