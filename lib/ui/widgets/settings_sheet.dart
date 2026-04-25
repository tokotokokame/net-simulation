// lib/ui/widgets/settings_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/app.dart';
import '../screens/topology_state.dart';

class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        minChildSize: 0.35,
        maxChildSize: 0.7,
        builder: (ctx, scrollCtrl) => SettingsSheet()._build(ctx, scrollCtrl),
      ),
    );
  }

  Widget _build(BuildContext context, ScrollController scrollCtrl) {
    return Consumer(builder: (context, ref, _) {
      final locale = ref.watch(localeProvider);
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
          ),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              children: [
                Text('設定', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                // ── 言語切り替え ──────────────────────────────────────────
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('言語'),
                  trailing: DropdownButton<String>(
                    value: locale.languageCode,
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'ja', child: Text('日本語')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(localeProvider.notifier).state = Locale(val);
                      }
                      Navigator.pop(context);
                    },
                  ),
                ),
                // ── トポロジクリア ────────────────────────────────────────
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('トポロジをクリア'),
                  onTap: () {
                    ref.read(topologyProvider.notifier).clear();
                    Navigator.pop(context);
                  },
                ),
                const Divider(),
                // ── バージョン情報 ────────────────────────────────────────
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('バージョン情報'),
                  subtitle: const Text(
                    'Net.Simulation v4.0.0\n© 2026 Net.Simulation',
                    style: TextStyle(height: 1.5),
                  ),
                  isThreeLine: true,
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
              ],
            ),
          ),
        ]),
      );
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      _build(context, ScrollController());
}
