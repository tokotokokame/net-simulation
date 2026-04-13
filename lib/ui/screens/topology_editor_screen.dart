// lib/ui/screens/topology_editor_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../models/device.dart';
import '../../models/network_interface.dart';
import '../../simulation/simulation_engine.dart';
import '../../visualization/packet_particle.dart' show PacketParticle;
import '../../visualization/simulation_animator.dart';
import '../../visualization/topology_painter.dart';
import '../widgets/connection_dialog.dart';
import '../widgets/debug_overlay.dart';
import '../widgets/device_palette.dart';
import '../widgets/failure_menu.dart';
import 'topology_state.dart';

const _uuid = Uuid();
Offset _toCanvas(Offset local, Matrix4 m) { final s = m.storage; return Offset((local.dx - s[12]) / s[0], (local.dy - s[13]) / s[5]); }

Offset _snap(Offset o, {double grid = 20}) =>
    Offset((o.dx / grid).round() * grid, (o.dy / grid).round() * grid);

class TopologyEditorScreen extends ConsumerStatefulWidget {
  const TopologyEditorScreen({super.key});
  @override
  ConsumerState<TopologyEditorScreen> createState() => _TopologyEditorScreenState();
}

class _TopologyEditorScreenState extends ConsumerState<TopologyEditorScreen> with SingleTickerProviderStateMixin {
  final _txCtrl = TransformationController();
  String? _draggingId;
  bool _connectMode = false;
  String? _connectFirst;
  late final SimulationAnimator _animator;
  List<PacketParticle> _particles = [];

  @override
  void initState() { super.initState(); _animator = SimulationAnimator(this)..addListener(_onAnimatorUpdate); }
  void _onAnimatorUpdate() => setState(() => _particles = List.of(_animator.activeParticles));

  @override
  void dispose() { _animator.dispose(); _txCtrl.dispose(); super.dispose(); }

  void _addDevice(DeviceType type, Offset p) => ref.read(topologyProvider.notifier).addDevice(Device(
        id: _uuid.v4(), type: type, name: type.name, x: p.dx, y: p.dy,
        interfaces: const [NetworkInterface(name: 'eth0', ip: '0.0.0.0', subnet: 24, mac: '00:00:00:00:00:00')],
      ));

  void _onTapCanvas(Offset local) {
    final hit = _hitTest(local);
    if (_connectMode) {
      if (hit == null) return;
      if (_connectFirst == null) { setState(() => _connectFirst = hit.id); return; }
      if (_connectFirst != hit.id) _showConnectionDialog(_connectFirst!, hit.id);
      setState(() { _connectFirst = null; _connectMode = false; });
      return;
    }
    ref.read(selectedDeviceIdProvider.notifier).state = hit?.id;
  }

  Device? _hitTest(Offset local) {
    final c = _toCanvas(local, _txCtrl.value);
    return ref.read(topologyProvider).devices.where((d) {
      final dx = d.x - c.dx, dy = d.y - c.dy;
      return dx * dx + dy * dy <= TopologyPainter.kR * TopologyPainter.kR;
    }).firstOrNull;
  }

  void _onLongPress(Offset local, Offset global) {
    final hit = _hitTest(local);
    if (hit != null) { showDeviceFailureMenu(context, ref, hit, global); return; }
    final topo = ref.read(topologyProvider);
    final posMap = {for (final d in topo.devices) d.id: Offset(d.x, d.y)};
    final link = hitTestLink(topo.links, posMap, _toCanvas(local, _txCtrl.value));
    if (link != null) showLinkFailureMenu(context, ref, link, global);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_draggingId == null) return;
    final topo = ref.read(topologyProvider);
    final d = topo.devices.where((e) => e.id == _draggingId).firstOrNull;
    if (d == null) return;
    final scale = _txCtrl.value.storage[0];
    final np = _snap(Offset(d.x + details.delta.dx / scale, d.y + details.delta.dy / scale));
    ref.read(topologyProvider.notifier).updateDevice(d.copyWith(x: np.dx, y: np.dy));
  }

  void _showConnectionDialog(String idA, String idB) {
    final devs = ref.read(topologyProvider).devices;
    final a = devs.where((d) => d.id == idA).firstOrNull, b = devs.where((d) => d.id == idB).firstOrNull;
    if (a != null && b != null) ConnectionDialog.show(context, a, b, (_, __, ___) {});
  }

  @override
  Widget build(BuildContext context) {
    final topo = ref.watch(topologyProvider);
    final selected = ref.watch(selectedDeviceIdProvider);
    final engine = ref.watch(simulationEngineProvider);
    final isRunning = engine.simState == SimulationState.running;

    return Scaffold(
      appBar: AppBar(
        title: Text(topo.name, style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(icon: Icon(_connectMode ? Icons.cable : Icons.add_link, color: _connectMode ? Colors.blue : null),
              tooltip: '接続モード', onPressed: () => setState(() { _connectMode = !_connectMode; _connectFirst = null; })),
          const DebugOverlayFab(),
          IconButton(icon: const Icon(Icons.save_outlined), onPressed: () {}),
        ],
      ),
      body: DragTarget<DeviceType>(
        onAcceptWithDetails: (details) {
          final box = context.findRenderObject() as RenderBox;
          final local = box.globalToLocal(details.offset);
          _addDevice(details.data, _snap(_toCanvas(local, _txCtrl.value)));
        },
        builder: (context, _, __) => GestureDetector(
          onTapUp: (e) => _onTapCanvas(e.localPosition),
          onLongPressStart: (e) => _onLongPress(e.localPosition, e.globalPosition),
          onPanUpdate: _onPanUpdate,
          onPanEnd: (_) => setState(() => _draggingId = null),
          onDoubleTapDown: (e) {
            final hit = _hitTest(e.localPosition);
            if (hit != null) context.push('/config/${hit.id}');
          },
          child: InteractiveViewer(
            transformationController: _txCtrl,
            minScale: 0.3, maxScale: 4.0,
            constrained: false,
            child: SizedBox(
              width: 3000, height: 3000,
              child: CustomPaint(
                painter: TopologyPainter(topology: topo, selectedDeviceId: selected, particles: _particles),
              ),
            ),
          ),
        ),
      ),
      bottomSheet: const DevicePalette(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final eng = ref.read(simulationEngineProvider.notifier);
          if (isRunning) { eng.pause(); _animator.stop(); }
          else { eng.start(topo); _animator.start(); }
        },
        child: Icon(isRunning ? Icons.pause : Icons.play_arrow),
      ),
    );
  }
}
