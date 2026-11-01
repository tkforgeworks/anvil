/// The bar at the bottom of a dirty record editor (0.1.6 `SaveBar.tsx`,
/// ANV-100).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../../theme/anvil_metrics.dart';
import '../editor_state.dart';
import '../record_editor_controller.dart';

/// `You have unsaved changes` with Discard and Save, shown only while the
/// draft is dirty; the editor puts it below its scrolling body, where
/// 0.1.6 made it `position: sticky; bottom: 0`.
///
/// Discard calls the controller's `discard()` and Save its `save()`. Both
/// are disabled while a save is in flight, and Save also while the draft
/// breaks a save-blocking rule, whose first message is shown before the
/// buttons. 0.1.6's bar had no blockers to show: it disabled the buttons
/// only while saving.
class SaveBar<T> extends ConsumerWidget {
  const SaveBar({super.key, required this.provider, this.onSaveOutcome});

  /// The editor's provider for one record: `xEditorProvider(recordId)`.
  final AsyncNotifierProvider<RecordEditorController<T>, EditorState<T>>
  provider;

  /// Receives the outcome of a save from the bar's Save button while the
  /// bar is mounted.
  final ValueChanged<SaveOutcome>? onSaveOutcome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(provider).value;
    if (state == null || !state.isDirty) return const SizedBox.shrink();
    final controller = ref.read(provider.notifier);
    final colors = context.colors;
    final warning = context.forge.warning;
    final blocker = state.blockers.isEmpty
        ? null
        : state.blockers.first.message;

    Future<void> save() async {
      final outcome = await controller.save();
      if (context.mounted) onSaveOutcome?.call(outcome);
    }

    return Container(
      key: const ValueKey('save-bar'),
      padding: const EdgeInsets.symmetric(
        horizontal: AnvilSpacing.lg,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: warning, width: 2),
          left: BorderSide(color: colors.outlineVariant),
          right: BorderSide(color: colors.outlineVariant),
          bottom: BorderSide(color: colors.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: warning),
          const SizedBox(width: AnvilSpacing.md),
          Text('You have unsaved changes', style: context.text.bodyMedium),
          const SizedBox(width: AnvilSpacing.md),
          Expanded(
            child: blocker == null
                ? const SizedBox.shrink()
                : Text(
                    blocker,
                    key: const ValueKey('save-bar-blocker'),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    style: context.text.bodySmall?.copyWith(
                      color: colors.error,
                    ),
                  ),
          ),
          const SizedBox(width: AnvilSpacing.md),
          OutlinedButton(
            key: const ValueKey('save-bar-discard'),
            onPressed: state.saving ? null : controller.discard,
            child: const Text('Discard'),
          ),
          const SizedBox(width: AnvilSpacing.md),
          FilledButton(
            key: const ValueKey('save-bar-save'),
            onPressed: state.canSave ? save : null,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
