/// The app bar's save status (design §8.5, §13.3), fed by
/// `saveStatusProvider`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../editor/save_status.dart';
import '../theme/anvil_metrics.dart';

/// A tone dot and a label for the aggregate [SaveStatus] of the open
/// editors.
///
/// The labels follow 0.1.6's `TitleBar.tsx` (`Saving...`, `Save Error`,
/// `Unsaved Changes`), with `All changes saved` in place of its `Saved`
/// because 0.2.0 saves per record. The tones are `StatusTag.tsx`'s: success
/// when saved, info while saving, warning while unsaved, error on failure.
/// The unsaved count and the failure message are in a tooltip.
class SaveStatusIndicator extends ConsumerWidget {
  const SaveStatusIndicator({super.key});

  static const dotSize = 8.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(saveStatusProvider);
    final forge = context.forge;
    final (label, tone, tooltip) = switch (status) {
      AllSaved() => ('All changes saved', forge.success, null),
      Unsaved(:final count) => (
        'Unsaved Changes',
        forge.warning,
        unsavedTooltip(count),
      ),
      Saving() => ('Saving...', forge.info, null),
      SaveError(:final message) => (
        'Save Error',
        context.colors.error,
        message,
      ),
    };
    Widget indicator = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AnvilSpacing.sm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
          ),
          const SizedBox(width: AnvilSpacing.sm),
          Text(
            label,
            style: context.text.bodySmall?.copyWith(
              color: status is AllSaved
                  ? context.colors.onSurfaceVariant
                  : tone,
            ),
          ),
        ],
      ),
    );
    if (tooltip != null) {
      indicator = Tooltip(message: tooltip, child: indicator);
    }
    return Center(child: indicator);
  }

  /// `1 record with unsaved changes`, `3 records with unsaved changes`.
  static String unsavedTooltip(int count) =>
      '$count ${count == 1 ? 'record' : 'records'} with unsaved changes';
}
