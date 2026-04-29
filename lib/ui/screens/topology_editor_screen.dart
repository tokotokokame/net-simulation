// lib/ui/screens/topology_editor_screen.dart
import 'dart:collection' show Queue;
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../auth/demo_timer_service.dart';
import '../../auth/auth_state.dart';
import '../../auth/user_auth_service.dart';
import '../../models/device.dart';
import '../../models/link.dart';
import '../../models/network_interface.dart';
import '../../models/topology.dart';
import '../../visualization/topology_painter.dart';
import '../widgets/connection_dialog.dart';
import '../widgets/device_palette.dart';
import '../widgets/failure_menu.dart';
import '../widgets/paywall_dialog.dart';
import '../widgets/settings_sheet.dart';
import 'device_config_screen.dart';
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
  ConsumerState<TopologyEditorScreen> createState() =>
      _TopologyEditorScreenState();
}

class _TopologyEditorScreenState extends ConsumerState<TopologyEditorScreen>
    with TickerProviderStateMixin {

  // ── Transform ─────────────────────────────────────────────────────────────
  final _txCtrl = TransformationController();
  String? _draggingDeviceId;

  // ── Packet animation ──────────────────────────────────────────────────────
  final List<Pkt> _packets = [];
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  bool     _simRunning  = false;

  double _spawnTimer = 0.0;
  static const double _kSpawnInterval = 1.2; // seconds between new packets
  static const int    _kMaxPackets    = 12;   // simultaneous packet cap

  final List<(String, String)> _pairQueue = [];
  int _pairIndex = 0;

  // ── Button layout ─────────────────────────────────────────────────────────
  // Palette = drag handle(~20) + tabs(34) + device row(70) + safe-area ≈ 160px
  static const double _kPaletteH  = 160.0;
  static const double _kBtnMargin =  12.0;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _txCtrl.dispose();
    super.dispose();
  }

  // ── Ticker callback ───────────────────────────────────────────────────────
  void _onTick(Duration elapsed) {
    if (!_simRunning) {
      _lastElapsed = Duration.zero;
      return;
    }

    // dt spike prevention: first frame uses a safe default.
    final double dt;
    if (_lastElapsed == Duration.zero) {
      dt = 0.016;
    } else {
      final raw = (elapsed - _lastElapsed).inMilliseconds / 1000.0;
      dt = raw.clamp(0.0, 0.05); // cap at 50ms (background resume protection)
    }
    _lastElapsed = elapsed;

    setState(() {
      _updatePackets(dt);
      _spawnTimer += dt;
      if (_spawnTimer >= _kSpawnInterval && _pairQueue.isNotEmpty) {
        _spawnTimer = 0.0;
        _spawnNextPacket();
      }
    });
  }

  // ── Packet state machine ──────────────────────────────────────────────────
  void _updatePackets(double dt) {
    for (final pkt in _packets) {
      if (pkt.isFinished) {
        pkt.doneTimer += dt;
        continue;
      }

      switch (pkt.status) {

        // ── Dwelling at intermediate node ──────────────────────────────────
        case PktStatus.dwelling:
          pkt.dwellTimer -= dt;
          if (pkt.dwellTimer <= 0) {
            if (pkt.segIndex >= pkt.path.length - 2) {
              pkt.status = PktStatus.success;
            } else {
              pkt.segIndex++;
              pkt.progress = 0.0;
              pkt.status   = PktStatus.moving;
            }
          }

        // ── Moving along a link ────────────────────────────────────────────
        case PktStatus.moving:
          const double speed = 1.8; // segments per second
          pkt.progress += dt * speed;
          pkt.position = Offset.lerp(
              pkt.currentNode, pkt.nextNode, pkt.progress.clamp(0.0, 1.0))!;

          if (pkt.progress >= 1.0) {
            pkt.position   = pkt.nextNode;
            pkt.status     = PktStatus.dwelling;
            pkt.dwellTimer = 0.18; // 0.18 s processing time at node
          }

        case PktStatus.success:
        case PktStatus.blocked:
          break; // handled by doneTimer above
      }
    }

    // Remove packets that have been shown for kDoneDuration seconds.
    _packets.removeWhere(
        (p) => p.isFinished && p.doneTimer >= Pkt.kDoneDuration);
  }

  // ── Simulation control ────────────────────────────────────────────────────
  void _startSimulation() {
    final topology = ref.read(topologyProvider);
    if (topology.links.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('リンクがありません。デバイスを接続してから開始してください。'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    _packets.clear();
    _pairQueue.clear();
    _pairIndex  = 0;
    _spawnTimer = _kSpawnInterval; // fire first packet immediately
    _lastElapsed = Duration.zero;

    // Build (src, dst) pairs from active links (both directions).
    for (final link in topology.links) {
      if (!link.isActive) continue; // F3: skip blocked links
      final a = topology.devices.where((d) => d.id == link.deviceAId).firstOrNull;
      final b = topology.devices.where((d) => d.id == link.deviceBId).firstOrNull;
      if (a == null || b == null) continue;
      _pairQueue.add((a.id, b.id));
      _pairQueue.add((b.id, a.id));
    }
    _pairQueue.shuffle();

    setState(() => _simRunning = true);
    developer.log('[Sim] start: ${_pairQueue.length} pairs', name: 'Editor');
  }

  void _stopSimulation() {
    setState(() {
      _simRunning  = false;
      _packets.clear();
      _lastElapsed = Duration.zero;
    });
    developer.log('[Sim] stop', name: 'Editor');
  }

  // ── Packet spawner ────────────────────────────────────────────────────────
  void _spawnNextPacket() {
    if (_packets.length >= _kMaxPackets) return;
    if (_pairQueue.isEmpty) return;

    final topology = ref.read(topologyProvider);
    final pair  = _pairQueue[_pairIndex % _pairQueue.length];
    _pairIndex++;

    final path = _computePath(pair.$1, pair.$2, topology);
    if (path.length < 2) {
      developer.log('[Sim] No path: ${pair.$1} → ${pair.$2}', name: 'Editor');
      return;
    }

    final positions = path
        .map((id) {
          final d = topology.devices.where((d) => d.id == id).firstOrNull;
          return d == null ? null : Offset(d.x, d.y);
        })
        .whereType<Offset>()
        .toList();
    if (positions.length < 2) return;

    _packets.add(Pkt(path: positions));
    developer.log('[Sim] spawn: ${path.length} hops', name: 'Editor');
  }

  // BFS — returns device-ID path, skipping inactive (blocked) links (F3).
  List<String> _computePath(String src, String dst, Topology topology) {
    final adj = <String, List<String>>{};
    for (final link in topology.links) {
      if (!link.isActive) continue; // F3: blocked links excluded
      adj.putIfAbsent(link.deviceAId, () => []).add(link.deviceBId);
      adj.putIfAbsent(link.deviceBId, () => []).add(link.deviceAId);
    }

    final visited = <String>{src};
    final queue   = Queue<List<String>>();
    queue.add([src]);

    while (queue.isNotEmpty) {
      final path = queue.removeFirst();
      final node = path.last;
      if (node == dst) return path;
      for (final next in adj[node] ?? []) {
        if (visited.add(next)) {
          queue.add([...path, next]);
        }
      }
    }
    return [];
  }

  // ── Hit test ──────────────────────────────────────────────────────────────
  Device? _hitTest(Offset local) {
    final c = _toCanvas(local, _txCtrl.value);
    const r = 30.0;
    return ref.read(topologyProvider).devices.where((d) {
      final dx = d.x - c.dx, dy = d.y - c.dy;
      return dx * dx + dy * dy <= r * r;
    }).firstOrNull;
  }

  // ── Add device ────────────────────────────────────────────────────────────
  void _addAtCenter(DeviceType type) {
    final sz = MediaQuery.of(context).size;
    final c = _snap(_toCanvas(
        Offset(sz.width / 2, sz.height / 2), _txCtrl.value));
    ref.read(topologyProvider.notifier).addDevice(Device(
        id: _uuid.v4(), type: type, name: type.name,
        x: c.dx, y: c.dy,
        interfaces: const [NetworkInterface(
            name: 'eth0', ip: '0.0.0.0', subnet: 24,
            mac: '00:00:00:00:00:00')]));
    developer.log('Added $type at $c', name: 'Editor');
  }

  void _addAtPosition(DeviceType type, Offset canvasPos) {
    final c = _snap(canvasPos);
    ref.read(topologyProvider.notifier).addDevice(Device(
        id: _uuid.v4(), type: type, name: type.name,
        x: c.dx, y: c.dy,
        interfaces: const [NetworkInterface(
            name: 'eth0', ip: '0.0.0.0', subnet: 24,
            mac: '00:00:00:00:00:00')]));
    developer.log('Dropped $type at $c', name: 'Editor');
  }

  // ── Long-press context menus ──────────────────────────────────────────────
  void _onLongPressStart(LongPressStartDetails e) {
    final hit = _hitTest(e.localPosition);
    if (hit != null) { _showDeviceContextMenu(hit.id); return; }
    final topo   = ref.read(topologyProvider);
    final posMap = {for (final d in topo.devices) d.id: Offset(d.x, d.y)};
    final link   = hitTestLink(
        topo.links, posMap, _toCanvas(e.localPosition, _txCtrl.value));
    if (link != null) showLinkFailureMenu(context, ref, link, e.globalPosition);
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
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold))),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('詳細設定'),
            onTap: () { Navigator.pop(ctx); context.push('/config/${device.id}'); },
          ),
          ListTile(
            leading: const Icon(Icons.open_with),
            title: const Text('移動'),
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _draggingDeviceId = deviceId);
            },
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
            onTap: () {
              Navigator.pop(ctx);
              _confirmDelete(deviceId, device.name);
            },
          ),
        ]),
      ),
    );
  }

  void _confirmDelete(String deviceId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('デバイスを削除'),
        content: Text('「$name」を削除しますか？\n接続されているリンクも削除されます。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(topologyProvider.notifier).removeDevice(deviceId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  // ── Pan / drag ────────────────────────────────────────────────────────────
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

  // ── Tap / double-tap ──────────────────────────────────────────────────────
  void _onTap(Offset local) {
    final hit      = _hitTest(local);
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
          (ifA, ifB, type, bw, lat, loss) =>
              _addLink(a, hit, ifA, ifB, type, bw, lat, loss));
    }
    ref.read(selectedDeviceIdProvider.notifier).state = null;
  }

  void _addLink(Device a, Device b, String ifA, String ifB,
      LinkType type, int bandwidth, double latency, double packetLoss) {
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

  void _onDoubleTapLink(Offset local) {
    final topo   = ref.read(topologyProvider);
    final posMap = {for (final d in topo.devices) d.id: Offset(d.x, d.y)};
    final link   = hitTestLink(
        topo.links, posMap, _toCanvas(local, _txCtrl.value));
    if (link != null) _editLink(link);
  }

  // ── Save ──────────────────────────────────────────────────────────────────
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
      await ref.read(topologyStorageProvider)
          .saveTopology(ref.read(topologyProvider));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"$name" を保存しました')));
      }
    } finally {
      ctrl.dispose();
    }
  }

  // ── Zoom controls ─────────────────────────────────────────────────────────
  void _zoom(double factor) {
    final m = _txCtrl.value.clone();
    final currentScale = m.getMaxScaleOnAxis();
    final newScale = (currentScale * factor).clamp(0.2, 5.0);
    final sf = newScale / currentScale;
    final size = MediaQuery.of(context).size;
    final cx = size.width / 2, cy = size.height / 2;
    final tx = m.entry(0, 3), ty = m.entry(1, 3);
    final target = Matrix4.identity();
    target.storage[0]  = newScale;
    target.storage[5]  = newScale;
    target.storage[10] = newScale;
    target.storage[12] = cx * (1 - sf) + sf * tx;
    target.storage[13] = cy * (1 - sf) + sf * ty;
    _animateTransform(target);
  }

  void _resetZoom() => _animateTransform(Matrix4.identity());

  void _animateTransform(Matrix4 target) {
    final begin = _txCtrl.value.clone();
    final ctrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    final anim  = Matrix4Tween(begin: begin, end: target)
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
        height: _kPaletteH,
        child: DevicePalette(onDeviceSelected: _addAtCenter),
      ),
    );
  }

  Widget _buildSimFab() {
    return FloatingActionButton(
      backgroundColor: _simRunning ? Colors.red[700] : Colors.blue[700],
      onPressed: _simRunning ? _stopSimulation : _startSimulation,
      child: Icon(_simRunning ? Icons.stop : Icons.play_arrow,
          color: Colors.white, size: 30),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final topo     = ref.watch(topologyProvider);
    final selected = ref.watch(selectedDeviceIdProvider);
    final authState  = ref.watch(userAuthProvider);
    final timerSecs  = ref.watch(demoRemainingProvider).valueOrNull;

    ref.listen(demoRemainingProvider, (_, next) {
      if (next.valueOrNull == 0) {
        _stopSimulation();
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
              child: Center(child: Text(
                  '${timerSecs ~/ 60}m ${timerSecs % 60}s',
                  style: TextStyle(fontSize: 12,
                      color: timerSecs < 300 ? Colors.red : Colors.white70))),
            ),
          const Spacer(),
          IconButton(icon: const Icon(Icons.save_outlined),        tooltip: '保存',          onPressed: _saveTopology),
          IconButton(icon: const Icon(Icons.folder_open_outlined),  tooltip: '読み込み',      onPressed: () => context.push('/topologies')),
          IconButton(icon: const Icon(Icons.bar_chart),             tooltip: '統計',          onPressed: () => context.push('/stats')),
          IconButton(icon: const Icon(Icons.security),              tooltip: 'セキュリティテスト', onPressed: () => context.push('/pentest')),
          IconButton(icon: const Icon(Icons.settings),              tooltip: '設定',          onPressed: () => SettingsSheet.show(context)),
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
              onTapUp:       (e) => _onTap(e.localPosition),
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
              // F4: RepaintBoundary isolates canvas repaints from UI layer.
              child: RepaintBoundary(
                child: InteractiveViewer(
                  transformationController: _txCtrl,
                  panEnabled: false,
                  minScale: 0.2, maxScale: 5.0, constrained: false,
                  child: SizedBox(
                    width: 4000, height: 4000,
                    child: CustomPaint(
                      painter: TopologyPainter(
                        topology:         topo,
                        selectedDeviceId: selected,
                        packets:          _packets,
                      ),
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

          // ── 3. ズームボタン（左下・パレットより上） ──────────
          Positioned(
            left:   _kBtnMargin,
            bottom: _kPaletteH + _kBtnMargin,
            child:  _buildZoomControls(),
          ),

          // ── 4. 再生/停止FAB（右下・パレットより上） ──────────
          Positioned(
            right:  _kBtnMargin,
            bottom: _kPaletteH + _kBtnMargin,
            child:  _buildSimFab(),
          ),
        ],
      ),
    );
  }
}

// ── Zoom button widget ────────────────────────────────────────────────────────

class _ZoomButton extends StatelessWidget {
  final IconData   icon;
  final String     tooltip;
  final VoidCallback onTap;
  const _ZoomButton(
      {required this.icon, required this.tooltip, required this.onTap});

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
