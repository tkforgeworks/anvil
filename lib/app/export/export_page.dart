/// The Export page at `/export` (0.1.6 `ExportPage.tsx`; design §11.5,
/// §11.9): the preset and template selector with the unsupported-template
/// warnings, the scope, the record checklist, Preview and Export to File,
/// and the custom template dialog.
library;

import 'dart:async';

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../editor/dirty_editors.dart';
import '../editor/widgets/draft_picker.dart';
import '../shell/app_router.dart';
import '../theme/anvil_colors.dart';
import '../theme/anvil_metrics.dart';
import 'export_controller.dart';
import 'record_selection_list.dart';
import 'template_dialog.dart';

class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});

  static const selectorKey = ValueKey('export-selector');
  static const scopeKey = ValueKey('export-scope');
  static const domainKey = ValueKey('export-domain');
  static const previewKey = ValueKey('export-preview');
  static const executeKey = ValueKey('export-execute');
  static const newTemplateKey = ValueKey('export-new-template');
  static const editTemplateKey = ValueKey('export-edit-template');
  static const deleteTemplateKey = ValueKey('export-delete-template');
  static const openValidationKey = ValueKey('export-open-validation');

  /// The rendered preview text.
  static const previewOutputKey = ValueKey('export-preview-output');
  static const errorKey = ValueKey('export-error');
  static const errorCloseKey = ValueKey('export-error-close');
  static const successKey = ValueKey('export-success');
  static const dirtyNoteKey = ValueKey('export-dirty-note');
  static const noRecordsKey = ValueKey('export-no-records');

  /// The warning for the unsupported template [id], and its Edit action.
  static Key unsupportedKey(String id) => ValueKey('export-unsupported-$id');
  static Key unsupportedEditKey(String id) =>
      ValueKey('export-unsupported-edit-$id');

  /// The confirm and cancel buttons of the delete dialog.
  static const deleteConfirmKey = ValueKey('template-delete-confirm');
  static const deleteCancelKey = ValueKey('template-delete-cancel');

  /// 0.1.6's `maxWidth: 600` for the form, and `maxHeight: 600` for the
  /// preview.
  static const formMaxWidth = 600.0;
  static const previewMaxHeight = 600.0;

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  ExportPageController get _controller => ref.read(exportPageProvider.notifier);

  @override
  Widget build(BuildContext context) {
    ref.listen(exportPageProvider, (previous, next) {
      final notice = next.value?.notice;
      if (notice != null && notice != previous?.value?.notice) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            key: const ValueKey('export-unsupported-notice'),
            content: Text(notice),
          ),
        );
      }
    });
    final state = ref.watch(exportPageProvider).value;
    final dirty = ref.watch(dirtyEditorsProvider).length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Export',
                  style: context.text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              OutlinedButton.icon(
                key: ExportPage.newTemplateKey,
                onPressed: state == null || state.busy
                    ? null
                    : () => unawaited(showTemplateDialog(context, ref)),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Template'),
              ),
            ],
          ),
          const SizedBox(height: AnvilSpacing.md),
          if (state?.error case final error?) ...[
            _MessageLine(
              key: ExportPage.errorKey,
              message: error,
              background: context.forge.errorTint,
              icon: Icons.error_outline,
              iconColor: context.colors.error,
              onClose: _controller.clearError,
              closeKey: ExportPage.errorCloseKey,
              action: state!.blockedByValidation
                  ? TextButton(
                      key: ExportPage.openValidationKey,
                      onPressed: () =>
                          ref.read(routerProvider).go('/validation'),
                      child: const Text('Open Validation Panel'),
                    )
                  : null,
            ),
            const SizedBox(height: AnvilSpacing.md),
          ],
          if (state?.success case final success?) ...[
            _MessageLine(
              key: ExportPage.successKey,
              message: success,
              background: context.colors.surfaceContainerHigh,
              icon: Icons.check_circle_outline,
              iconColor: context.forge.success,
              onClose: _controller.clearSuccess,
            ),
            const SizedBox(height: AnvilSpacing.md),
          ],
          _Panel(
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: ExportPage.formMaxWidth,
                ),
                child: _form(context, state, dirty),
              ),
            ),
          ),
          if (state?.preview case final preview?) ...[
            const SizedBox(height: AnvilSpacing.lg),
            Text(
              'Preview',
              style: context.text.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AnvilSpacing.sm),
            _Preview(text: preview),
          ],
        ],
      ),
    );
  }

  Widget _form(BuildContext context, ExportPageState? state, int dirty) {
    final selectors = state?.selectors ?? const <ExportSelector>[];
    final selected = state?.selected;
    final busy = state?.busy ?? true;
    final mode = state?.mode ?? ExportScopeMode.full;
    final canRun = state?.canRun ?? false;
    final muted = context.colors.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.all(AnvilSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SelectorPicker(
            selectors: selectors,
            selectedId: state?.selectedId,
            onChanged: busy ? null : _controller.select,
          ),
          if (selected != null) ...[
            const SizedBox(height: AnvilSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    selected.description,
                    style: context.text.bodyMedium?.copyWith(color: muted),
                  ),
                ),
                if (!selected.builtIn) ...[
                  IconButton(
                    key: ExportPage.editTemplateKey,
                    tooltip: 'Edit template',
                    iconSize: 18,
                    onPressed: busy ? null : () => _edit(selected.id),
                    icon: const Icon(Icons.edit),
                  ),
                  IconButton(
                    key: ExportPage.deleteTemplateKey,
                    tooltip: 'Delete template',
                    iconSize: 18,
                    onPressed: busy ? null : () => _delete(selected),
                    icon: const Icon(Icons.delete),
                  ),
                ],
              ],
            ),
          ],
          for (final entry in state?.unsupported ?? const <ExportSelector>[])
            Padding(
              padding: const EdgeInsets.only(top: AnvilSpacing.sm),
              child: _UnsupportedWarning(
                entry: entry,
                onEdit: busy
                    ? null
                    : () => _edit(
                        entry.id,
                        caretAt: (
                          entry.unsupported!.line,
                          entry.unsupported!.column,
                        ),
                      ),
              ),
            ),
          const SizedBox(height: AnvilSpacing.lg),
          DraftPicker<ExportScopeMode>(
            key: ExportPage.scopeKey,
            label: 'Scope',
            value: mode,
            options: [
              for (final m in ExportScopeMode.values)
                (value: m, label: m.label),
            ],
            onChanged: busy ? null : (m) => unawaited(_controller.setMode(m)),
          ),
          if (mode != ExportScopeMode.full) ...[
            const SizedBox(height: AnvilSpacing.lg),
            DraftPicker<ExportDomain?>(
              key: ExportPage.domainKey,
              label: 'Domain',
              value: state?.domain,
              options: [
                for (final d in ExportDomain.values)
                  (value: d, label: exportDomainLabel(d)),
              ],
              onChanged: busy
                  ? null
                  : (d) => unawaited(_controller.setDomain(d)),
            ),
          ],
          if (state != null &&
              mode == ExportScopeMode.selection &&
              state.domain != null &&
              state.recordsLoaded) ...[
            const SizedBox(height: AnvilSpacing.lg),
            if (state.records.isEmpty)
              Text(
                'No records found in this domain.',
                key: ExportPage.noRecordsKey,
                style: context.text.bodyMedium?.copyWith(color: muted),
              )
            else
              RecordSelectionList(
                records: state.records,
                checked: state.checked,
                onToggle: _controller.toggleRecord,
                onToggleAll: _controller.toggleAll,
              ),
          ],
          if (dirty > 0) ...[
            const SizedBox(height: AnvilSpacing.lg),
            Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: context.forge.info),
                const SizedBox(width: AnvilSpacing.sm),
                Expanded(
                  child: Text(
                    'Export reflects saved records only. $dirty record(s) '
                    'have unsaved changes.',
                    key: ExportPage.dirtyNoteKey,
                    style: context.text.bodyMedium?.copyWith(color: muted),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AnvilSpacing.lg),
          Wrap(
            spacing: AnvilSpacing.md,
            runSpacing: AnvilSpacing.sm,
            children: [
              OutlinedButton.icon(
                key: ExportPage.previewKey,
                onPressed: canRun
                    ? () => unawaited(_controller.preview())
                    : null,
                icon: const Icon(Icons.preview, size: 18),
                label: Text(state?.busy ?? false ? 'Loading...' : 'Preview'),
              ),
              FilledButton.icon(
                key: ExportPage.executeKey,
                onPressed: canRun
                    ? () => unawaited(_controller.execute())
                    : null,
                icon: const Icon(Icons.file_download, size: 18),
                label: const Text('Export to File'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _edit(String id, {(int, int)? caretAt}) async {
    final CustomTemplate template;
    try {
      template = await _controller.loadTemplate(id);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    await showTemplateDialog(
      context,
      ref,
      existing: template,
      caretAt: caretAt,
    );
  }

  Future<void> _delete(ExportSelector entry) async {
    final controller = _controller;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete template?'),
            content: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: entry.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(
                    text:
                        ' will be permanently deleted. '
                        'This action cannot be undone.',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                key: ExportPage.deleteCancelKey,
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: ExportPage.deleteConfirmKey,
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.error,
                  foregroundColor: context.colors.onError,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) await controller.deleteTemplate(entry.id);
  }
}

/// The `Template / Preset` picker: a [DropdownButton] (never a
/// `DropdownMenu`, design §8.7) whose presets carry the `Built-in` chip
/// and whose unsupported templates are disabled.
class _SelectorPicker extends StatelessWidget {
  const _SelectorPicker({
    required this.selectors,
    required this.selectedId,
    required this.onChanged,
  });

  final List<ExportSelector> selectors;
  final String? selectedId;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    final value = selectors.any((s) => s.id == selectedId) ? selectedId : null;
    Widget entry(ExportSelector s) => Row(
      children: [
        Expanded(
          child: Text(
            s.name,
            overflow: TextOverflow.ellipsis,
            style: s.unsupported == null
                ? null
                : TextStyle(color: context.anvil.textDisabled),
          ),
        ),
        if (s.builtIn) ...[
          const SizedBox(width: AnvilSpacing.sm),
          const Chip(
            label: Text('Built-in'),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ],
    );
    return InputDecorator(
      key: ExportPage.selectorKey,
      decoration: InputDecoration(
        labelText: 'Template / Preset',
        enabled: onChanged != null,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          isExpanded: true,
          items: [
            for (final s in selectors)
              DropdownMenuItem<String>(
                value: s.id,
                enabled: s.unsupported == null,
                child: entry(s),
              ),
          ],
          onChanged: onChanged == null
              ? null
              : (id) {
                  if (id != null) onChanged(id);
                },
        ),
      ),
    );
  }
}

/// The §11.5 warning for one template the renderer cannot run.
class _UnsupportedWarning extends StatelessWidget {
  const _UnsupportedWarning({required this.entry, required this.onEdit});

  final ExportSelector entry;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final forge = context.forge;
    return Container(
      key: ExportPage.unsupportedKey(entry.id),
      padding: const EdgeInsets.fromLTRB(
        AnvilSpacing.md,
        AnvilSpacing.sm,
        AnvilSpacing.sm,
        AnvilSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: forge.warningContainer,
        borderRadius: BorderRadius.circular(AnvilRadii.panel),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, size: 18, color: forge.onWarningContainer),
          const SizedBox(width: AnvilSpacing.sm),
          Expanded(
            child: Text(
              unsupportedTemplateWarning(entry.name, entry.unsupported!),
              style: context.text.bodyMedium?.copyWith(
                color: forge.onWarningContainer,
              ),
            ),
          ),
          TextButton(
            key: ExportPage.unsupportedEditKey(entry.id),
            style: TextButton.styleFrom(
              foregroundColor: forge.onWarningContainer,
            ),
            onPressed: onEdit,
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }
}

/// The error or success line with its close action, as 0.1.6's `Alert`
/// with `onClose`.
class _MessageLine extends StatelessWidget {
  const _MessageLine({
    super.key,
    required this.message,
    required this.background,
    required this.icon,
    required this.iconColor,
    required this.onClose,
    this.closeKey,
    this.action,
  });

  final String message;
  final Color background;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onClose;
  final Key? closeKey;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.fromLTRB(
        AnvilSpacing.md,
        AnvilSpacing.xs,
        AnvilSpacing.xs,
        AnvilSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AnvilRadii.panel),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: AnvilSpacing.sm),
          Expanded(child: Text(message, style: context.text.bodyMedium)),
          ?action,
          IconButton(
            key: closeKey,
            tooltip: 'Close',
            iconSize: 18,
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    ),
  );
}

/// The read-only output in the code face, scrollable both ways up to
/// [ExportPage.previewMaxHeight].
class _Preview extends StatelessWidget {
  const _Preview({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => _Panel(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: ExportPage.previewMaxHeight),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AnvilSpacing.md),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SelectionArea(
            child: Text(
              text,
              key: ExportPage.previewOutputKey,
              softWrap: false,
              style: ForgeType.code(size: 12.8),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The outlined, rounded panel 0.1.6 drew around the form and the preview
/// (`Paper variant="outlined"`).
class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: context.colors.outlineVariant),
      borderRadius: BorderRadius.circular(AnvilRadii.panel),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(AnvilRadii.panel),
      child: child,
    ),
  );
}
