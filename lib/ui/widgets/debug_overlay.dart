// lib/ui/widgets/debug_overlay.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../simulation/simulation_engine.dart';

/// FAB that toggles a semi-transparent debug panel via [OverlayEntry].
class DebugOverlayFab extends ConsumerStatefulWidget {
  const DebugOverlayFab({super.key});

  @override
  ConsumerState<DebugOverlayFab> createState() => _DebugOverlayFabState();
}

class _DebugOverlayFabState extends ConsumerState<DebugOverlayFab> {
  OverlayEntry? _entry;
  bool _visible = false;

  void _toggle() {
    if (_visible) {
      _entry?.remove();
      _entry = null;
    } else {
      _entry = OverlayEntry(
        builder: (_) => const _DebugPanel(),
      );
      Overlay.of(context).insert(_entry!);
    }
    setState(() => _visible = !_visible);
  }

  @override
  void dispose() {
    _entry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'debug_fab',
      backgroundColor: Colors.black54,
      foregroundColor: Colors.white,
      onPressed: _toggle,
      tooltip: 'Debug Overlay',
      child: Icon(
        _visible ? Icons.close : Icons.bug_report_outlined,
        size: 20,
      ),
    );
  }
}

// ── Debug panel (lives inside OverlayEntry) ───────────────────────────────────

class _DebugPanel extends ConsumerWidget {
  const _DebugPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eng = ref.watch(simulationEngineProvider);

    return Positioned(
      top: 96,
      right: 12,
      width: 260,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(204), // 80% opaque
            borderRadius: BorderRadius.circular(10),
          ),
          child: DefaultTextStyle(
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _row('State', eng.simState.name.toUpperCase()),
                _row('Active pkts', '${eng.activePackets.length}'),
                _row('Total', '${eng.stats.totalPackets}'),
                _row('Delivered', '${eng.stats.deliveredPackets}'),
                _row('Dropped', '${eng.stats.droppedPackets}'),
                const Divider(color: Colors.white24, height: 10),
                const Text('── Recent packets ──',
                    style: TextStyle(color: Colors.white38, fontSize: 10)),
                const SizedBox(height: 4),
                ...eng.activePackets.reversed.take(5).map(
                      (p) => Text(
                        '${p.status.name[0].toUpperCase()} '
                        '${p.sourceIp}→${p.destinationIp} '
                        '[${p.protocol.name}]',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white54)),
            Text(value),
          ],
        ),
      );
}
