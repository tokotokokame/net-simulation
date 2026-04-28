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
import '../../visualization/topology_painter.dart';
import '../widgets/connection_dialog.dart'; import '../widgets/device_palette.dart';
import '../widgets/failure_menu.dart'; import '../widgets/paywall_dialog.dart';
import '../widgets/settings_sheet.dart'; import 'device_config_screen.dart';
import 'topology_state.dart';
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
    with TickerProviderStateMixin {
  final _txCtrl = TransformationController();
  String? _draggingDeviceId;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() { _txCtrl.dispose(); super.dispose(); }

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

  // ── Simulation start with validation ─────────────────────────────────────

  Future<void> _startSimulation() async {
    final topo = ref.read(topologyProvider);
    final engine = ref.read(simulationEngineProvider.notifier);
    final result = engine.validateAndPrepare(topo);

    if (result.hasErrors) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('開始エラー'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: result.errors.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('• $e', style: const TextStyle(color: Colors.red)),
            )).toList(),
          ),
          actions: [TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'))],
        ),
      );
      return;
    }

    // Apply auto-assigned IPs to topology state.
    if (result.warnings.isNotEmpty) {
      ref.read(topologyProvider.notifier).load(result.prepared);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('自動補完: ${result.warnings.join(' / ')}'),
          backgroundColor: Colors.amber[800],
          duration: const Duration(seconds: 4),
        ));
      }
    }

    engine.start(result.prepared);
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

  // ── Pan ───────────────────────────────────────────────────────────────────

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
    if (hit == null) {
      ref.read(selectedDeviceIdProvider.notifier).state = null;
      return;
    }
    if (selected == hit.id) {
      ref.read(selectedDeviceIdProvider.notifier).state = null;
      return;
    }
    if (selected == null) {
      ref.read(selectedDeviceIdProvider.notifier).state = hit.id;
      developer.log('Selected ${hit.name}', name: 'Editor');
      return;
    }
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
      deviceAId: a.id, deviceBId: b.id,
      interfaceAName: ifA, interfaceBName: ifB,
      type: type, bandwidth: bandwidth, latency: latency, packetLoss: packetLoss,
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
            FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('保存')),
          ],
        ),
      );
      if (name == null || name.isEmpty || !mounted) return;
      ref.read(topologyProvider.notifier).rename(name);
      await ref.read(topologyStorageProvider).saveTopology(ref.read(topologyProvider));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"$name" を保存しました')));
      }
    } finally {
      ctrl.dispose();
    }
  }

  void _onDoubleTapLink(Offset local) {
    final topo = ref.read(topologyProvider);
    final posMap = {for (final d in topo.devices) d.id: Offset(d.x, d.y)};
    final link = hitTestLink(topo.links, posMap, _toCanvas(local, _txCtrl.value));
    if (link != null) _editLink(link);
  }

  // ── Zoom controls ─────────────────────────────────────────────────────────

  static const double _paletteHeight = 140.0;

  void _zoom(double factor) {
    final m = _txCtrl.value.clone();
    final currentScale = m.getMaxScaleOnAxis();
    final newScale = (currentScale * factor).clamp(0.2, 5.0);
    final sf = newScale / currentScale;

    final size = MediaQuery.of(context).size;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final tx = m.entry(0, 3);
    final ty = m.entry(1, 3);
    final newTx = cx * (1 - sf) + sf * tx;
    final newTy = cy * (1 - sf) + sf * ty;

    final target = Matrix4.identity();
    target.storage[0]  = newScale;
    target.storage[5]  = newScale;
    target.storage[10] = newScale;
    target.storage[12] = newTx;
    target.storage[13] = newTy;
    _animateTransform(target);
  }

  void _resetZoom() => _animateTransform(Matrix4.identity());

  void _animateTransform(Matrix4 target) {
    final begin = _txCtrl.value.clone();
    final ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    final anim = Matrix4Tween(begin: begin, end: target)
        .animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOut));
    anim.addListener(() => _txCtrl.value = anim.value);
    ctrl.forward().then((_) => ctrl.dispose());
  }

  Widget _buildZoomControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ZoomButton(icon: Icons.add,        tooltip: 'ズームイン',   onTap: () => _zoom(1.25)),
        const SizedBox(height: 4),
        _ZoomButton(icon: Icons.remove,     tooltip: 'ズームアウト', onTap: () => _zoom(0.8)),
        const SizedBox(height: 4),
        _ZoomButton(icon: Icons.fit_screen, tooltip: 'リセット',     onTap: _resetZoom),
      ],
    );
  }

  Widget _buildPalette() {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return SafeArea(
      minimum: EdgeInsets.only(bottom: bottomPad),
      child: SizedBox(
        height: _paletteHeight,
        child: DevicePalette(onDeviceSelected: _addAtCenter),
      ),
    );
  }

  Widget _buildSimFab(bool isRunning) {
    return FloatingActionButton(
      backgroundColor: isRunning ? Colors.red[700] : Colors.blue[700],
      onPressed: () {
        if (isRunning) {
          ref.read(simulationEngineProvider.notifier).pause();
        } else {
          _startSimulation();
        }
      },
      child: Icon(isRunning ? Icons.stop : Icons.play_arrow, color: Colors.white, size: 30),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topo = ref.watch(topologyProvider);
    final selected = ref.watch(selectedDeviceIdProvider);
    final engine = ref.watch(simulationEngineProvider);
    final isRunning = engine.simState == SimulationState.running;
    final particles = engine.particles;
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
        title: null,
        titleSpacing: 0,
        leading: const SizedBox.shrink(),
        actions: [
          if (authState is UnauthenticatedState && timerSecs != null)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Center(child: Text('${timerSecs ~/ 60}m ${timerSecs % 60}s',
                  style: TextStyle(fontSize: 12,
                      color: timerSecs < 300 ? Colors.red : Colors.white70))),
            ),
          const Spacer(),
          IconButton(icon: const Icon(Icons.save_outlined),       tooltip: '保存',          onPressed: _saveTopology),
          IconButton(icon: const Icon(Icons.folder_open_outlined), tooltip: '読み込み',      onPressed: () => context.push('/topologies')),
          IconButton(icon: const Icon(Icons.bar_chart),            tooltip: '統計',          onPressed: () => context.push('/stats')),
          IconButton(icon: const Icon(Icons.security),             tooltip: 'セキュリティテスト', onPressed: () => context.push('/pentest')),
          IconButton(icon: const Icon(Icons.settings),             tooltip: '設定',          onPressed: () => SettingsSheet.show(context)),
        ],
      ),
      body: Stack(
        children: [
          // ── 1. キャンバス（最背面） ────────────────────────
          DragTarget<DeviceType>(
            onAcceptWithDetails: (details) {
              final box = context.findRenderObject()! as RenderBox;
              final local = box.globalToLocal(details.offset);
              final inv = Matrix4.inverted(_txCtrl.value);
              final s = inv.storage;
              final canvas = Offset(
                s[0] * local.dx + s[4] * local.dy + s[12],
                s[1] * local.dx + s[5] * local.dy + s[13],
              );
              _addAtPosition(details.data, canvas);
            },
            builder: (_, __, ___) => GestureDetector(
              onTapUp: (e) => _onTap(e.localPosition),
              onDoubleTapDown: (e) {
                final hit = _hitTest(e.localPosition);
                if (hit != null) {
                  if (isCloudDevice(hit.type)) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('このデバイスは設定できません（クラウド/キャリアノード）'),
                      duration: Duration(seconds: 2),
                    ));
                    return;
                  }
                  context.push('/config/${hit.id}');
                  return;
                }
                _onDoubleTapLink(e.localPosition);
              },
              onLongPressStart: _onLongPressStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd:    _onPanEnd,
              child: InteractiveViewer(
                transformationController: _txCtrl,
                panEnabled: false,
                minScale: 0.2, maxScale: 5.0, constrained: false,
                child: SizedBox(
                  width: 3000, height: 3000,
                  child: CustomPaint(
                    painter: TopologyPainter(
                      topology: topo,
                      selectedDeviceId: selected,
                      particles: particles,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── 2. デバイスパレット（下部） ────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildPalette(),
          ),

          // ── 3. ズームボタン（左下・パレットの上） ──────────
          Positioned(
            left: 16,
            bottom: _paletteHeight + 16,
            child: _buildZoomControls(),
          ),

          // ── 4. 再生/停止FAB（右下・パレットの上） ──────────
          Positioned(
            right: 16,
            bottom: _paletteHeight + 16,
            child: _buildSimFab(isRunning),
          ),
        ],
      ),
    );
  }
}

// ── Zoom button widget ────────────────────────────────────────────────────────

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _ZoomButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFF1E2A3A),
        borderRadius: BorderRadius.circular(8),
        elevation: 3,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 40, height: 40,
            child: Icon(icon, color: Colors.white70, size: 22),
          ),
        ),
      ),
    );
  }
}
