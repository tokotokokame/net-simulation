// lib/ui/widgets/settings_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/app.dart';
import '../screens/topology_state.dart';

class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('設定', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
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
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('トポロジをクリア'),
            onTap: () {
              ref.read(topologyProvider.notifier).clear();
              Navigator.pop(context);
            },
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('バージョン情報'),
            subtitle: Text('Net.Simulation v4.0.0'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
