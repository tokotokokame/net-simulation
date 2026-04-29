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
import '../../models/simulation_statistics.dart';
import '../../network/syslog_service.dart';
import '../../visualization/topology_painter.dart';
import '../widgets/connection_dialog.dart';
import '../widgets/device_palette.dart';
import '../widgets/failure_menu.dart';
import '../widgets/paywall_dialog.dart';
import '../widgets/settings_sheet.dart';
import 'device_config_screen.dart';
import 'topology_state.dart';
import '../../simulation/simulation_engine.dart';
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
  final List<Pkt>       _packets    = [];
  final List<SimLink>   _simLinks   = [];
  final List<SimDevice> _simDevices = [];

  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  bool     _simRunning  = false;

  double _spawnTimer = 0.0;
  static const double _kSpawnInterval = 1.2;
  static const int    _kMaxPackets    = 12;

  final List<(String, String)> _pairQueue = [];
  int _pairIndex = 0;

  // ── Button layout ─────────────────────────────────────────────────────────
  static const double _kBtnMargin = 12.0;
  // handle(20) + tabs(34) + items(70) = 124; device_palette handles safeArea internally
  double get _kPaletteH =>
      124.0 + MediaQuery.of(context).padding.bottom;

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

    final double dt;
    if (_lastElapsed == Duration.zero) {
      dt = 0.016;
    } else {
      final raw = (elapsed - _lastElapsed).inMilliseconds / 1000.0;
      dt = raw.clamp(0.0, 0.05);
    }
    _lastElapsed = elapsed;

    setState(() {
      _updateDevices(dt);
      _updatePackets(dt);
      _spawnTimer += dt;
      if (_spawnTimer >= _kSpawnInterval && _pairQueue.isNotEmpty) {
        _spawnTimer = 0.0;
        _spawnNextPacket();
      }
    });
  }

  // ── Device state machine ──────────────────────────────────────────────────
  void _updateDevices(double dt) {
    for (final sd in _simDevices) {
      if (sd.state == DeviceState.rebooting) {
        sd.rebootTimer -= dt;
        if (sd.rebootTimer <= 0) {
          sd.state = DeviceState.active;
          developer.log('[Sim] device recovered: ${sd.name}', name: 'Editor');
          ref.read(syslogProvider.notifier).addEntry(
              SyslogSeverity.notice, sd.name,
              '[DEVICE UP] ${sd.name} が回復しました');
          _rebuildPairQueue();
        }
      }
    }
  }

  // ── Packet state machine ──────────────────────────────────────────────────
  void _updatePackets(double dt) {
    for (final pkt in _packets) {
      if (pkt.isFinished) {
        pkt.doneTimer += dt;
        continue;
      }

      switch (pkt.status) {
        case PktStatus.dwelling:
          pkt.dwellTimer -= dt;
          if (pkt.dwellTimer <= 0) {
            if (pkt.segIndex >= pkt.path.length - 2) {
              pkt.status = PktStatus.success;
              ref.read(statisticsNotifierProvider.notifier)
                  .recordPacket(success: true, latencyMs: pkt.elapsedMs);
            } else {
              pkt.segIndex++;
              pkt.progress = 0.0;
              pkt.status   = PktStatus.moving;
            }
          }

        case PktStatus.moving:
          const double speed = 1.8;
          pkt.progress += dt * speed;
          pkt.position = Offset.lerp(
              pkt.currentNode, pkt.nextNode, pkt.progress.clamp(0.0, 1.0))!;
          if (pkt.progress >= 1.0) {
            pkt.position   = pkt.nextNode;
            pkt.status     = PktStatus.dwelling;
            pkt.dwellTimer = 0.18;
          }

        case PktStatus.success:
        case PktStatus.blocked:
          break;
      }
    }

    _packets.removeWhere(
        (p) => p.isFinished && p.doneTimer >= Pkt.kDoneDuration);
  }

  // ── Pair queue helper ─────────────────────────────────────────────────────
  void _rebuildPairQueue() {
    _pairQueue.clear();
    for (final sl in _simLinks) {
      if (!sl.isPassable) continue;
      final aAlive = _simDevices
          .where((d) => d.deviceId == sl.deviceAId)
          .firstOrNull?.isActive ?? true;
      final bAlive = _simDevices
          .where((d) => d.deviceId == sl.deviceBId)
          .firstOrNull?.isActive ?? true;
      if (!aAlive || !bAlive) continue;
      _pairQueue.add((sl.deviceAId, sl.deviceBId));
      _pairQueue.add((sl.deviceBId, sl.deviceAId));
    }
    _pairQueue.shuffle();
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

    // IP auto-assign via engine (cloud nodes included)
    ref.read(statisticsNotifierProvider.notifier).reset();
    final engine = ref.read(simulationEngineProvider.notifier);
    final result = engine.validateAndPrepare(topology);
    if (!result.hasErrors) {
      if (result.warnings.isNotEmpty) {
        ref.read(topologyProvider.notifier).load(result.prepared);
      }
      engine.start(result.prepared);
    }

    // Read topology after IP assignment
    final topo = ref.read(topologyProvider);

    // Build _simLinks (all links, active at start)
    _simLinks.clear();
    for (final link in topo.links) {
      final a = topo.devices.where((d) => d.id == link.deviceAId).firstOrNull;
      final b = topo.devices.where((d) => d.id == link.deviceBId).firstOrNull;
      if (a == null || b == null) continue;
      _simLinks.add(SimLink(
        linkId:    link.id,
        deviceAId: link.deviceAId,
        deviceBId: link.deviceBId,
        posA:      Offset(a.x, a.y),
        posB:      Offset(b.x, b.y),
        latencyMs: link.latency,
      ));
    }

    // Build _simDevices (all devices, active at start)
    _simDevices.clear();
    for (final device in topo.devices) {
      _simDevices.add(SimDevice(
        deviceId: device.id,
        name:     device.name,
        position: Offset(device.x, device.y),
      ));
    }

    // Build pair queue
    _packets.clear();
    _pairQueue.clear();
    _pairIndex   = 0;
    _spawnTimer  = _kSpawnInterval;
    _lastElapsed = Duration.zero;

    for (final sl in _simLinks) {
      _pairQueue.add((sl.deviceAId, sl.deviceBId));
      _pairQueue.add((sl.deviceBId, sl.deviceAId));
    }
    _pairQueue.shuffle();

    setState(() => _simRunning = true);
    developer.log(
        '[Sim] start: ${_simLinks.length} links, ${_pairQueue.length} pairs',
        name: 'Editor');
  }

  void _stopSimulation() {
    ref.read(simulationEngineProvider.notifier).stop();
    setState(() {
      _simRunning = false;
      _packets.clear();
      _simLinks.clear();
      _simDevices.clear();
      _lastElapsed = Duration.zero;
    });
    developer.log('[Sim] stop', name: 'Editor');
  }

  // ── Packet spawner ────────────────────────────────────────────────────────
  void _spawnNextPacket() {
    if (_packets.length >= _kMaxPackets) return;
    if (_pairQueue.isEmpty) return;

    final pair  = _pairQueue[_pairIndex % _pairQueue.length];
    _pairIndex++;

    final srcId = pair.$1;
    final dstId = pair.$2;

    // Skip crashed devices
    final srcAlive = _simDevices
        .where((d) => d.deviceId == srcId).firstOrNull?.isActive ?? true;
    final dstAlive = _simDevices
        .where((d) => d.deviceId == dstId).firstOrNull?.isActive ?? true;
    if (!srcAlive || !dstAlive) {
      developer.log('[Sim] skip crashed: $srcId or $dstId', name: 'Editor');
      return;
    }

    final idPath = _computePath(srcId, dstId);
    if (idPath.length < 2) {
      developer.log('[Sim] no path: $srcId → $dstId', name: 'Editor');
      ref.read(statisticsNotifierProvider.notifier).recordPacket(success: false);
      return;
    }

    final positions = idPath.map((id) {
      return _simDevices.where((d) => d.deviceId == id).firstOrNull?.position;
    }).whereType<Offset>().toList();
    if (positions.length < 2) return;

    _packets.add(Pkt(path: positions, deviceIds: idPath));
    developer.log('[Sim] spawn: ${idPath.length} hops', name: 'Editor');
  }

  // BFS using _simLinks — isPassable + device crash check
  List<String> _computePath(String src, String dst) {
    final adj = <String, List<String>>{};
    for (final sl in _simLinks) {
      if (!sl.isPassable) continue;
      final aAlive = _simDevices
          .where((d) => d.deviceId == sl.deviceAId)
          .firstOrNull?.isActive ?? true;
      final bAlive = _simDevices
          .where((d) => d.deviceId == sl.deviceBId)
          .firstOrNull?.isActive ?? true;
      if (!aAlive || !bAlive) continue;
      adj.putIfAbsent(sl.deviceAId, () => []).add(sl.deviceBId);
      adj.putIfAbsent(sl.deviceBId, () => []).add(sl.deviceAId);
    }

    if (src == dst) return [src];
    final visited = <String>{src};
    final queue   = Queue<List<String>>();
    queue.add([src]);
    while (queue.isNotEmpty) {
      final path = queue.removeFirst();
      final node = path.last;
      if (node == dst) return path;
      for (final next in adj[node] ?? []) {
        if (visited.add(next)) queue.add([...path, next]);
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

  // ── Long-press: sim mode vs. edit mode ────────────────────────────────────
  void _onLongPressStart(LongPressStartDetails e) {
    if (_simRunning) {
      // Simulation mode: show failure/crash menus
      final canvasPos = _toCanvas(e.localPosition, _txCtrl.value);
      _trySimMenu(canvasPos);
      return;
    }
    // Edit mode: existing behavior
    final hit = _hitTest(e.localPosition);
    if (hit != null) {
      _showDeviceContextMenu(hit.id);
      return;
    }
    final topo   = ref.read(topologyProvider);
    final posMap = {for (final d in topo.devices) d.id: Offset(d.x, d.y)};
    final link   = hitTestLink(
        topo.links, posMap, _toCanvas(e.localPosition, _txCtrl.value));
    if (link != null) showLinkFailureMenu(context, ref, link, e.globalPosition);
  }

  // ── Simulation failure menus ──────────────────────────────────────────────
  void _trySimMenu(Offset canvasPos) {
    // Device check first (40px)
    SimDevice? nearDev;
    double minDevDist = 40.0;
    for (final sd in _simDevices) {
      final d = (sd.position - canvasPos).distance;
      if (d < minDevDist) { minDevDist = d; nearDev = sd; }
    }
    if (nearDev != null) {
      _showDeviceCrashMenu(nearDev);
      return;
    }
    // Link check (30px to segment)
    SimLink? nearLink;
    double minLinkDist = 30.0;
    for (final sl in _simLinks) {
      final d = _distToSegment(canvasPos, sl.posA, sl.posB);
      if (d < minLinkDist) { minLinkDist = d; nearLink = sl; }
    }
    if (nearLink != null) _showLinkStateMenu(nearLink);
  }

  void _showLinkStateMenu(SimLink sl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A2332),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      useSafeArea: true,
      builder: (_) => _LinkStateMenu(
        simLink: sl,
        onStateChanged: (newState) {
          setState(() {
            sl.state = newState;
            _packets.removeWhere((p) => _pathUsesLink(p, sl));
            if (newState == LinkState.failed) _rebuildPairQueue();
          });
          final aName = _deviceName(sl.deviceAId);
          final bName = _deviceName(sl.deviceBId);
          final (sev, msg) = switch (newState) {
            LinkState.failed    => (SyslogSeverity.critical,
                '[LINK DOWN] $aName ↔ $bName'),
            LinkState.congested => (SyslogSeverity.warning,
                '[LINK CONGESTED] $aName ↔ $bName'),
            LinkState.active    => (SyslogSeverity.notice,
                '[LINK UP] $aName ↔ $bName'),
          };
          ref.read(syslogProvider.notifier).addEntry(sev, 'NetSim', msg);
          developer.log('[Sim] link ${sl.linkId} → ${newState.name}',
              name: 'Editor');
        },
      ),
    );
  }

  void _showDeviceCrashMenu(SimDevice sd) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A2332),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      useSafeArea: true,
      builder: (_) => _DeviceCrashMenu(
        simDevice: sd,
        onAction: (action, rebootSec) {
          setState(() {
            switch (action) {
              case 'crash':
                sd.state = DeviceState.crashed;
                _packets.removeWhere(
                    (p) => p.deviceIds.contains(sd.deviceId));
                _rebuildPairQueue();
                ref.read(syslogProvider.notifier).addEntry(
                    SyslogSeverity.emergency, sd.name,
                    '[DEVICE DOWN] ${sd.name} がクラッシュしました');
                developer.log('[Sim] CRASH: ${sd.name}', name: 'Editor');

              case 'reboot':
                sd.state       = DeviceState.rebooting;
                sd.rebootTimer = rebootSec;
                _packets.removeWhere(
                    (p) => p.deviceIds.contains(sd.deviceId));
                _rebuildPairQueue();
                ref.read(syslogProvider.notifier).addEntry(
                    SyslogSeverity.warning, sd.name,
                    '[DEVICE REBOOT] ${sd.name} 再起動中（${rebootSec.toInt()}秒後に復旧）');
                developer.log('[Sim] REBOOT: ${sd.name} ${rebootSec}s',
                    name: 'Editor');

              case 'recover':
                sd.state = DeviceState.active;
                _rebuildPairQueue();
                ref.read(syslogProvider.notifier).addEntry(
                    SyslogSeverity.notice, sd.name,
                    '[DEVICE UP] ${sd.name} が回復しました');
                developer.log('[Sim] RECOVER: ${sd.name}', name: 'Editor');
            }
          });
        },
      ),
    );
  }

  // ── Geometry helpers ──────────────────────────────────────────────────────
  double _distToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final ap = p - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return (p - a).distance;
    final t = (ap.dx * ab.dx + ap.dy * ab.dy) / len2;
    final closest = a + ab * t.clamp(0.0, 1.0);
    return (p - closest).distance;
  }

  bool _pathUsesLink(Pkt p, SimLink sl) {
    final ids = p.deviceIds;
    for (int i = 0; i < ids.length - 1; i++) {
      if ((ids[i] == sl.deviceAId && ids[i + 1] == sl.deviceBId) ||
          (ids[i] == sl.deviceBId && ids[i + 1] == sl.deviceAId)) {
        return true;
      }
    }
    return false;
  }

  String _deviceName(String deviceId) =>
      _simDevices.where((d) => d.deviceId == deviceId).firstOrNull?.name ??
      deviceId;

  // ── Context menus (edit mode) ─────────────────────────────────────────────
  void _showDeviceContextMenu(String deviceId) {
    final device = ref.read(topologyProvider).devices
        .where((d) => d.id == deviceId).firstOrNull;
    if (device == null) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
              padding: const EdgeInsets.all(16),
              child: Text(device.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold))),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('詳細設定'),
            onTap: () {
              Navigator.pop(ctx);
              context.push('/config/${device.id}');
            },
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('"$name" を保存しました')));
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
    return DevicePalette(onDeviceSelected: _addAtCenter);
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
    final topo      = ref.watch(topologyProvider);
    final selected  = ref.watch(selectedDeviceIdProvider);
    final authState = ref.watch(userAuthProvider);
    final timerSecs = ref.watch(demoRemainingProvider).valueOrNull;

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
                  style: TextStyle(
                      fontSize: 12,
                      color: timerSecs < 300 ? Colors.red : Colors.white70))),
            ),
          const Spacer(),
          IconButton(icon: const Icon(Icons.save_outlined),       tooltip: '保存',           onPressed: _saveTopology),
          IconButton(icon: const Icon(Icons.folder_open_outlined), tooltip: '読み込み',       onPressed: () => context.push('/topologies')),
          IconButton(icon: const Icon(Icons.bar_chart),            tooltip: '統計',           onPressed: () => context.push('/stats')),
          IconButton(icon: const Icon(Icons.security),             tooltip: 'セキュリティテスト', onPressed: () => context.push('/pentest')),
          IconButton(icon: const Icon(Icons.settings),             tooltip: '設定',           onPressed: () => SettingsSheet.show(context)),
          IconButton(icon: const Icon(Icons.school_outlined),     tooltip: 'シナリオ学習',    onPressed: () => context.push('/scenarios')),
          IconButton(icon: const Icon(Icons.hub_outlined),        tooltip: 'プロトコル可視化', onPressed: () => context.push('/protocol-viz')),
        ],
      ),
      body: Stack(
        children: [
          // ── 1. Canvas ────────────────────────────────────────
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
              onTapUp:         (e) => _onTap(e.localPosition),
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
                        simLinks:         _simLinks,
                        simDevices:       _simDevices,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── 2. デバイスパレット ───────────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildPalette(),
          ),

          // ── 3. ズームボタン ───────────────────────────────────
          Positioned(
            left:   _kBtnMargin,
            bottom: _kPaletteH + _kBtnMargin,
            child:  _buildZoomControls(),
          ),

          // ── 4. 再生/停止 FAB ─────────────────────────────────
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
  final IconData     icon;
  final String       tooltip;
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

// ── Link state menu ───────────────────────────────────────────────────────────

class _LinkStateMenu extends StatelessWidget {
  final SimLink simLink;
  final ValueChanged<LinkState> onStateChanged;
  const _LinkStateMenu({required this.simLink, required this.onStateChanged});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPad + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('リンク操作',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text('現在の状態: ${simLink.state.name.toUpperCase()}',
                style: TextStyle(color: _stateColor(simLink.state), fontSize: 12)),
            const SizedBox(height: 16),
            _SimMenuBtn(
              icon: Icons.link,
              label: 'リンク正常化（Link Up）',
              color: Colors.green,
              onTap: () { Navigator.pop(context); onStateChanged(LinkState.active); },
            ),
            _SimMenuBtn(
              icon: Icons.link_off,
              label: 'リンク断（Link Down）',
              color: Colors.red,
              onTap: () { Navigator.pop(context); onStateChanged(LinkState.failed); },
            ),
            _SimMenuBtn(
              icon: Icons.warning_amber,
              label: '輻輳シミュレート（Congested）',
              color: Colors.orange,
              onTap: () { Navigator.pop(context); onStateChanged(LinkState.congested); },
            ),
          ],
        ),
      ),
    );
  }

  Color _stateColor(LinkState s) => switch (s) {
    LinkState.active    => Colors.green,
    LinkState.failed    => Colors.red,
    LinkState.congested => Colors.orange,
  };
}

// ── Device crash menu ─────────────────────────────────────────────────────────

class _DeviceCrashMenu extends StatelessWidget {
  final SimDevice simDevice;
  final void Function(String action, double rebootSec) onAction;
  const _DeviceCrashMenu(
      {required this.simDevice, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPad + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('デバイス操作: ${simDevice.name}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text('状態: ${simDevice.state.name.toUpperCase()}',
                style: TextStyle(color: _stateColor(simDevice.state), fontSize: 12)),
            const SizedBox(height: 16),
            _SimMenuBtn(
              icon: Icons.check_circle_outline,
              label: '正常化（Recover）',
              color: Colors.green,
              onTap: () { Navigator.pop(context); onAction('recover', 0); },
            ),
            _SimMenuBtn(
              icon: Icons.dangerous_outlined,
              label: 'クラッシュ（Crash）',
              color: Colors.red,
              onTap: () { Navigator.pop(context); onAction('crash', 0); },
            ),
            _SimMenuBtn(
              icon: Icons.restart_alt,
              label: '再起動（Reboot 10秒）',
              color: Colors.orange,
              onTap: () { Navigator.pop(context); onAction('reboot', 10.0); },
            ),
            _SimMenuBtn(
              icon: Icons.restart_alt,
              label: '再起動（Reboot 30秒）',
              color: Colors.orange,
              onTap: () { Navigator.pop(context); onAction('reboot', 30.0); },
            ),
          ],
        ),
      ),
    );
  }

  Color _stateColor(DeviceState s) => switch (s) {
    DeviceState.active    => Colors.green,
    DeviceState.crashed   => Colors.red,
    DeviceState.rebooting => Colors.orange,
  };
}

class _SimMenuBtn extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;
  const _SimMenuBtn(
      {required this.icon, required this.label, required this.color,
       required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: color),
        title: Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 14)),
        onTap: onTap,
        dense: true,
      );
}
