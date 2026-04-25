// lib/ui/screens/topology_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../models/topology.dart';
import '../../storage/topology_storage.dart';
import 'topology_state.dart';

const _uuid = Uuid();

class TopologyListScreen extends ConsumerStatefulWidget {
  const TopologyListScreen({super.key});
  @override
  ConsumerState<TopologyListScreen> createState() => _TopologyListScreenState();
}

class _TopologyListScreenState extends ConsumerState<TopologyListScreen> {
  late Future<List<TopologyMeta>> _futureList;

  @override
  void initState() {
    super.initState();
    _futureList = ref.read(topologyStorageProvider).listTopologies();
  }

  void _reload() => setState(() {
        _futureList = ref.read(topologyStorageProvider).listTopologies();
      });

  // ── Save current topology ─────────────────────────────────────────────────

  Future<void> _saveCurrent() async {
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
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"$name" を保存しました')));
      }
    } finally {
      ctrl.dispose();
    }
  }

  // ── Load topology ─────────────────────────────────────────────────────────

  Future<void> _load(String id) async {
    final topo = await ref.read(topologyStorageProvider).loadTopology(id);
    if (topo == null || !mounted) return;
    ref.read(topologyProvider.notifier).load(topo);
    if (mounted) context.go('/');
  }

  // ── Delete confirmation ───────────────────────────────────────────────────

  void _confirmDelete(TopologyMeta meta) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('"${meta.name}" を削除しますか？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(topologyStorageProvider)
                  .deleteTopology(meta.id);
              if (mounted) _reload();
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('トポロジ一覧'),
        actions: [
          IconButton(
              icon: const Icon(Icons.save),
              tooltip: '現在のトポロジを保存',
              onPressed: _saveCurrent),
        ],
      ),
      body: FutureBuilder<List<TopologyMeta>>(
        future: _futureList,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return const Center(
                child: Text('保存済みのトポロジはありません',
                    style: TextStyle(color: Colors.grey)));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final meta = list[i];
              final isDemo = meta.id.startsWith('demo-');
              return ListTile(
                leading: Icon(
                  isDemo ? Icons.school_outlined : Icons.account_tree_outlined,
                  color: isDemo ? Colors.blue[300] : null,
                ),
                title: Row(children: [
                  Expanded(child: Text(meta.name)),
                  if (isDemo)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue[800],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Demo',
                          style: TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                ]),
                subtitle: Text(
                    '${meta.deviceCount} デバイス  •  ${_fmt(meta.createdAt)}'),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => _load(meta.id),
                onLongPress: () => _confirmDelete(meta),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: '新規作成',
        onPressed: () {
          ref.read(topologyProvider.notifier).load(
              Topology.empty(id: _uuid.v4(), name: 'New Topology'));
          context.go('/');
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.year}/${dt.month.toString().padLeft(2, '0')}/'
      '${dt.day.toString().padLeft(2, '0')}';
}
