import 'package:flutter/material.dart';
import 'package:forge_ui/forge_ui.dart';

import '../theme/anvil_metrics.dart';

/// 0.1.6's "Upgrade Project Schema" message box (`migrateIfNeeded` in
/// `project-service.ts`), word for word. Returns true for Upgrade Copy;
/// Cancel, Escape and the barrier return false or null.
Future<bool?> showUpgradeProjectDialog(BuildContext context) =>
    showDialog<bool>(
      context: context,
      builder: (context) => const UpgradeProjectDialog(),
    );

class UpgradeProjectDialog extends StatelessWidget {
  const UpgradeProjectDialog({super.key});

  static const title = 'Upgrade Project Schema';
  static const message = 'This project was created with an older Anvil schema.';
  static const detail =
      'Anvil will create an upgraded backup copy and leave the original '
      'project file unchanged.';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(title),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: context.text.bodyLarge),
            const SizedBox(height: AnvilSpacing.sm),
            Text(
              detail,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Upgrade Copy'),
        ),
      ],
    );
  }
}
