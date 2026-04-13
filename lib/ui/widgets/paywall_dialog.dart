// lib/ui/widgets/paywall_dialog.dart
import 'dart:developer';
import 'package:flutter/material.dart';

/// Shown when the demo timer expires.
/// "Upgrade" is mocked; "Register" navigates to /auth.
class PaywallDialog extends StatelessWidget {
  final VoidCallback? onUpgrade;
  final VoidCallback? onRegister;

  const PaywallDialog({
    super.key,
    this.onUpgrade,
    this.onRegister,
  });

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onUpgrade,
    VoidCallback? onRegister,
  }) {
    log('PaywallDialog shown', name: 'Paywall');
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PaywallDialog(
        onUpgrade: onUpgrade,
        onRegister: onRegister,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cs.surface,
      icon: Icon(Icons.hourglass_empty_rounded, size: 48, color: cs.primary),
      title: Text(
        'シミュレーション時間終了',
        style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '無料プランのシミュレーション時間（60分）が終了しました。\n'
            '続けるにはプロプランへのアップグレードまたは無料登録が必要です。',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const _FeatureRow(icon: Icons.all_inclusive, label: '無制限シミュレーション時間'),
          const _FeatureRow(icon: Icons.account_tree, label: '高度なトポロジー機能'),
          const _FeatureRow(icon: Icons.analytics_outlined, label: '詳細ネットワーク統計'),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.workspace_premium),
              label: const Text('プロにアップグレード'),
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                log('Upgrade tapped (mock)', name: 'Paywall');
                Navigator.of(context).pop();
                onUpgrade?.call();
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('無料登録して続行'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                log('Register tapped', name: 'Paywall');
                Navigator.of(context).pop();
                onRegister?.call();
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
