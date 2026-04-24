// lib/ui/screens/syslog_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../network/syslog_service.dart';
import '../screens/topology_state.dart';

// ── Severity color helper ─────────────────────────────────────────────────────

Color _severityColor(SyslogSeverity s) => switch (s) {
      SyslogSeverity.emergency ||
      SyslogSeverity.alert     ||
      SyslogSeverity.critical  => Colors.red,
      SyslogSeverity.error     => Colors.orange,
      SyslogSeverity.warning   => Colors.amber[700]!,
      SyslogSeverity.notice    => Colors.green,
      SyslogSeverity.info      => Colors.green[700]!,
      SyslogSeverity.debug     => Colors.grey,
    };

IconData _severityIcon(SyslogSeverity s) => switch (s) {
      SyslogSeverity.emergency => Icons.emergency,
      SyslogSeverity.alert     => Icons.warning_amber,
      SyslogSeverity.critical  => Icons.error,
      SyslogSeverity.error     => Icons.error_outline,
      SyslogSeverity.warning   => Icons.warning_outlined,
      SyslogSeverity.notice    => Icons.info,
      SyslogSeverity.info      => Icons.info_outline,
      SyslogSeverity.debug     => Icons.bug_report_outlined,
    };

// ── Screen ────────────────────────────────────────────────────────────────────

class SyslogScreen extends ConsumerStatefulWidget {
  const SyslogScreen({super.key});
  @override
  ConsumerState<SyslogScreen> createState() => _SyslogScreenState();
}

class _SyslogScreenState extends ConsumerState<SyslogScreen> {
  SyslogSeverity? _filterSeverity;
  String? _filterFacility;

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final svc      = ref.watch(syslogProvider.notifier);
    final entries  = svc.getEntries(
        minSeverity: _filterSeverity, facility: _filterFacility);
    final devices  = ref.watch(topologyProvider).devices;
    final facilities = ['', ...{for (final d in devices) d.name}];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Syslogビューア'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'クリア',
            onPressed: () { svc.clear(); setState(() {}); },
          ),
        ],
      ),
      body: Column(children: [
        // ── Severity filter chips ────────────────────────────────────────
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            children: [
              _chip('ALL',   _filterSeverity == null,
                  () => setState(() => _filterSeverity = null)),
              ...SyslogSeverity.values.map((s) => _chip(
                  s.name.toUpperCase(),
                  _filterSeverity == s,
                  () => setState(() =>
                      _filterSeverity = _filterSeverity == s ? null : s),
                  color: _severityColor(s))),
            ],
          ),
        ),

        // ── Facility filter ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonFormField<String>(
            decoration: const InputDecoration(
                labelText: 'デバイスフィルタ', isDense: true,
                border: OutlineInputBorder()),
            initialValue: _filterFacility ?? '',
            items: facilities.map((f) => DropdownMenuItem(
                value: f,
                child: Text(f.isEmpty ? '（すべて）' : f))).toList(),
            onChanged: (v) => setState(
                () => _filterFacility = (v == null || v.isEmpty) ? null : v),
          ),
        ),
        const SizedBox(height: 8),

        // ── Entry count ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Text('${entries.length} 件', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
        ),
        const Divider(height: 1),

        // ── Entry list ───────────────────────────────────────────────────
        Expanded(
          child: entries.isEmpty
              ? const Center(child: Text('ログはありません', style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final e = entries[i];
                    final color = _severityColor(e.severity);
                    return ListTile(
                      dense: true,
                      leading: Icon(_severityIcon(e.severity), color: color, size: 20),
                      title: Text(e.message,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                          '${_fmt(e.timestamp)}  ${e.facility}',
                          style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: color.withValues(alpha: 0.5)),
                        ),
                        child: Text(e.severity.name.toUpperCase(),
                            style: TextStyle(fontSize: 9, color: color,
                                fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
        ),
      ]),

      // ── FAB: add sample entry for testing ────────────────────────────
      floatingActionButton: FloatingActionButton.small(
        tooltip: 'テストログ追加',
        onPressed: () {
          svc.connectionEstablished('TestDevice', '192.168.1.1 → 10.0.0.1');
          setState(() {});
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap, {Color? color}) =>
      Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(label, style: const TextStyle(fontSize: 10)),
          selected: selected,
          selectedColor: (color ?? Colors.blue).withValues(alpha: 0.25),
          onSelected: (_) => onTap(),
        ),
      );
}
