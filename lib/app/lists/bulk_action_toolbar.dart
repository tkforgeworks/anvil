import 'package:flutter/material.dart';
import 'package:forge_ui/forge_ui.dart';

import '../theme/anvil_metrics.dart';
import 'list_columns.dart';

/// The bar above a list while records are selected (0.1.6
/// `BulkActionToolbar`): `N selected`, then Delete Selected in the active
/// view, or Restore Selected and Permanently Delete in the archived view.
/// Nothing shows while [count] is zero.
class BulkActionToolbar extends StatelessWidget {
  const BulkActionToolbar({
    super.key,
    required this.count,
    required this.mode,
    this.onDelete,
    this.onRestore,
    this.onHardDelete,
  });

  final int count;
  final ListViewMode mode;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;
  final VoidCallback? onHardDelete;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    final c = context.colors;
    final destructive = OutlinedButton.styleFrom(
      foregroundColor: c.error,
      side: BorderSide(color: c.error),
    );
    return Material(
      elevation: 3,
      color: c.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AnvilRadii.panel),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AnvilSpacing.md,
          vertical: AnvilSpacing.sm,
        ),
        child: Row(
          children: [
            Text(
              '$count selected',
              style: context.text.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (mode == ListViewMode.active)
              OutlinedButton.icon(
                style: destructive,
                onPressed: onDelete,
                icon: const Icon(Icons.delete, size: 18),
                label: const Text('Delete Selected'),
              )
            else ...[
              OutlinedButton.icon(
                onPressed: onRestore,
                icon: const Icon(Icons.restore_from_trash, size: 18),
                label: const Text('Restore Selected'),
              ),
              const SizedBox(width: AnvilSpacing.md),
              OutlinedButton.icon(
                style: destructive,
                onPressed: onHardDelete,
                icon: const Icon(Icons.delete_forever, size: 18),
                label: const Text('Permanently Delete'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
