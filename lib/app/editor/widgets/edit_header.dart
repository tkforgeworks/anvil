/// The card at the top of every record editor (0.1.6 `EditHeader.tsx`,
/// ANV-100; design §8.4).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../../theme/anvil_colors.dart';
import '../../theme/anvil_metrics.dart';
import '../editor_state.dart';
import '../record_editor_controller.dart';
import 'draft_text_field.dart';

/// The editor's header: a back link, the display name, undo and redo, Save,
/// the read-only export key and the last save's error.
///
/// It watches [provider] itself and builds nothing until the draft has
/// loaded. Undo and redo are enabled from `canUndo` / `canRedo`, Save from
/// `canSave` (dirty, not blocked, not saving; 0.1.6 enabled it whenever the
/// record was dirty and not saving). The card's outline turns the warning
/// colour while the draft is dirty, as 0.1.6's did.
///
/// With [onDisplayNameChanged] the name is a large [DraftTextField] with
/// the `Name` placeholder and the `displayName` blocker as its error, as
/// 0.1.6's header edited the name in place; without it the name is plain
/// text. The header is sticky by placement: the editor puts it above its
/// scrolling body.
class EditHeader<T> extends ConsumerWidget {
  const EditHeader({
    super.key,
    required this.provider,
    required this.backLabel,
    required this.onBack,
    required this.displayNameOf,
    required this.exportKeyOf,
    this.onDisplayNameChanged,
    this.onSaveOutcome,
  });

  /// The editor's provider for one record: `xEditorProvider(recordId)`.
  final AsyncNotifierProvider<RecordEditorController<T>, EditorState<T>>
  provider;

  /// What the back link returns to (`Items`); its tooltip is `Back to …`.
  final String backLabel;

  /// Leaves the editor: the list route, or closing the editor dialog.
  final VoidCallback onBack;

  final String Function(T draft) displayNameOf;
  final String Function(T draft) exportKeyOf;

  /// Makes the name editable; the editor's `setDisplayName`.
  final ValueChanged<String>? onDisplayNameChanged;

  /// Receives the outcome of a save from the header's Save button while
  /// the header is mounted, as `RecordEditorScope.onSaveOutcome` does for
  /// Ctrl+S.
  final ValueChanged<SaveOutcome>? onSaveOutcome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(provider).value;
    if (state == null) return const SizedBox.shrink();
    final controller = ref.read(provider.notifier);
    final colors = context.colors;
    final name = displayNameOf(state.draft);
    final onNameChanged = onDisplayNameChanged;

    Future<void> save() async {
      final outcome = await controller.save();
      if (context.mounted) onSaveOutcome?.call(outcome);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AnvilSpacing.md),
      padding: const EdgeInsets.all(AnvilSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(
          color: state.isDirty ? context.forge.warning : colors.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(ForgeRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                key: const ValueKey('editor-back'),
                tooltip: 'Back to $backLabel',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.arrow_back, size: 18),
                onPressed: onBack,
              ),
              const SizedBox(width: AnvilSpacing.sm),
              Text(
                backLabel,
                style: context.text.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AnvilSpacing.sm),
          Row(
            children: [
              Expanded(
                child: onNameChanged == null
                    ? Text(
                        name,
                        key: const ValueKey('editor-display-name'),
                        style: context.text.headlineSmall,
                        overflow: TextOverflow.ellipsis,
                      )
                    : DraftTextField(
                        key: const ValueKey('editor-display-name'),
                        value: name,
                        onChanged: onNameChanged,
                        hintText: 'Name',
                        blockerMessage: blockerText(
                          state.blockers,
                          'displayName',
                        ),
                        style: context.text.headlineSmall,
                        decoration: const InputDecoration(
                          border: UnderlineInputBorder(),
                          filled: false,
                        ),
                      ),
              ),
              const SizedBox(width: AnvilSpacing.md),
              IconButton(
                key: const ValueKey('editor-undo'),
                tooltip: 'Undo (Ctrl+Z)',
                icon: const Icon(Icons.undo, size: 20),
                onPressed: state.canUndo ? controller.undo : null,
              ),
              IconButton(
                key: const ValueKey('editor-redo'),
                tooltip: 'Redo (Ctrl+Y)',
                icon: const Icon(Icons.redo, size: 20),
                onPressed: state.canRedo ? controller.redo : null,
              ),
              const SizedBox(width: AnvilSpacing.sm),
              FilledButton.icon(
                key: const ValueKey('editor-save'),
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Save'),
                onPressed: state.canSave ? save : null,
              ),
            ],
          ),
          const SizedBox(height: AnvilSpacing.sm),
          Row(
            children: [
              Text(
                'KEY',
                style: context.text.labelSmall?.copyWith(
                  color: context.anvil.textDisabled,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(width: AnvilSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  border: Border.all(color: colors.outlineVariant),
                  borderRadius: BorderRadius.circular(AnvilRadii.control),
                ),
                child: SelectableText(
                  exportKeyOf(state.draft),
                  key: const ValueKey('editor-export-key'),
                  style: ForgeType.code(size: 12, color: colors.onSurface),
                ),
              ),
              const SizedBox(width: AnvilSpacing.sm),
              Text(
                '· used in exported files',
                style: context.text.bodySmall?.copyWith(
                  color: context.anvil.textDisabled,
                ),
              ),
            ],
          ),
          if (state.saveError case final error?) ...[
            const SizedBox(height: AnvilSpacing.sm),
            Text(
              error,
              key: const ValueKey('editor-save-error'),
              style: context.text.bodyMedium?.copyWith(color: colors.error),
            ),
          ],
        ],
      ),
    );
  }
}
