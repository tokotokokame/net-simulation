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

  void _onLongPress(Offset local, Offset global) {
    final hit = _hitTest(local);
    if (hit != null) { showDeviceFailureMenu(context, ref, hit, global); return; }
    final topo = ref.read(topologyProvider);
    final posMap = {for (final d in topo.devices) d.id: Offset(d.x, d.y)};
    final link = hitTestLink(topo.links, posMap, _toCanvas(local, _txCtrl.value));
    if (link != null) showLinkFailureMenu(context, ref, link, global);
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
    final safeBottom = MediaQuery.of(context).padding.bottom;

    ref.listen(demoRemainingProvider, (_, next) {
      if (next.valueOrNull == 0) {
        ref.read(simulationEngineProvider.notifier).pause();
        PaywallDialog.show(context);
      }
    });

    return Scaffold(
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
              onPressed: () => showModalBottomSheet(context: context,
                  builder: (_) => const SettingsSheet())),
        ],
      ),
      body: Stack(children: [
        GestureDetector(
          onTapUp: (e) => _onTap(e.localPosition),
          onLongPressStart: (e) => _onLongPress(e.localPosition, e.globalPosition),
          onDoubleTapDown: (e) {
            final hit = _hitTest(e.localPosition);
            if (hit != null) { context.push('/config/${hit.id}'); return; }
            _onDoubleTapLink(e.localPosition);
          },
          child: InteractiveViewer(
            transformationController: _txCtrl,
            minScale: 0.3, maxScale: 4.0, constrained: false,
            child: SizedBox(width: 3000, height: 3000,
                child: CustomPaint(painter: TopologyPainter(topology: topo, selectedDeviceId: selected, particles: _particles))),
          ),
        ),
      ]),
      bottomSheet: DevicePalette(onDeviceSelected: _addAtCenter),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 110 + safeBottom),
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
