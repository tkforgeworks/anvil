/// The custom template dialog of the export page (0.1.6's inline dialog in
/// `ExportPage.tsx`): name, description, format and the template source,
/// with the 0.2 writing guide behind a toggle and the renderer's own check
/// shown under the source as a warning.
///
/// The four fields form a value-equal [TemplateDraft] held against a
/// baseline (the stored template, or empty for a new one), with no undo
/// stack (ANVL-165). Save is enabled only while the draft differs from the
/// baseline and has a name; dismissing a dirty dialog asks Save / Discard /
/// Cancel first, and the dirty draft is listed by the app exit and project
/// close prompts as `<name> (template)`.
library;

import 'dart:async';

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../editor/dirty_editors.dart';
import '../editor/editor_state.dart' show SaveOutcome;
import '../editor/exit_prompt.dart';
import '../editor/widgets/draft_picker.dart';
import '../lists/record_list_controller.dart' show listErrorMessage;
import '../theme/anvil_metrics.dart';
import 'export_controller.dart';

const templateNameKey = ValueKey('template-name');
const templateDescriptionKey = ValueKey('template-description');
const templateFormatKey = ValueKey('template-format');
const templateSourceKey = ValueKey('template-source');
const templateGuideToggleKey = ValueKey('template-guide-toggle');
const templateSaveKey = ValueKey('template-save');
const templateCancelKey = ValueKey('template-cancel');

/// The source check's warning under the field, while there is one.
const templateCheckKey = ValueKey('template-check');

/// The save failure inside the dialog, while there is one.
const templateErrorKey = ValueKey('template-error');

/// 0.1.6's format options (stored value, label).
const List<PickerOption<String>> templateFormats = [
  (value: 'text', label: 'Text'),
  (value: 'json', label: 'JSON'),
  (value: 'csv', label: 'CSV'),
];

/// How long after the last keystroke the source is checked.
const templateCheckDelay = Duration(milliseconds: 300);

/// The 0.1.6 dialog width (`maxWidth="md"`).
const _dialogWidth = 900.0;

/// What the dialog edits: the name and description trimmed as Save stores
/// them, the format and the source as typed. Records compare by value.
typedef TemplateDraft = ({
  String name,
  String description,
  String format,
  String source,
});

/// The draft of [existing], or the empty draft of a new template.
TemplateDraft templateBaseline(CustomTemplate? existing) => (
  name: existing?.name.trim() ?? '',
  description: existing?.description.trim() ?? '',
  format: existing?.format ?? 'text',
  source: existing?.templateSource ?? '',
);

/// The template dialog's registry id in `dirtyEditorsProvider`, for
/// [existing] or for a new template.
String templateDirtyId(CustomTemplate? existing) =>
    'template:${existing?.id ?? 'new'}';

/// The message of the one rule that blocks a template save.
const templateNameRequiredMessage = 'Template name is required.';

/// Opens the dialog for a new template, or for [existing]; [caretAt]
/// (1-based line and column) puts the caret there in the source field.
/// Saving goes through `exportPageProvider`, which bumps the write epoch.
/// Completes with true when the template was saved.
Future<bool> showTemplateDialog(
  BuildContext context,
  WidgetRef ref, {
  CustomTemplate? existing,
  (int line, int column)? caretAt,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => TemplateDialog(existing: existing, caretAt: caretAt),
    ) ??
    false;

class TemplateDialog extends ConsumerStatefulWidget {
  const TemplateDialog({super.key, this.existing, this.caretAt});

  final CustomTemplate? existing;
  final (int line, int column)? caretAt;

  @override
  ConsumerState<TemplateDialog> createState() => _TemplateDialogState();
}

class _TemplateDialogState extends ConsumerState<TemplateDialog> {
  late TemplateDraft _baseline = templateBaseline(widget.existing);
  late final DirtyEditorsNotifier _registry;
  late final String _dirtyId = templateDirtyId(widget.existing);

  /// A save from this dialog landed, so closing it reports true.
  var _saved = false;
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _description = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late final _source = TextEditingController(
    text: widget.existing?.templateSource ?? '',
  );
  late String _format = widget.existing?.format ?? 'text';
  TemplateCheck? _check;
  Timer? _checkTimer;
  var _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    if (widget.caretAt case (final line, final column)) {
      _source.selection = TextSelection.collapsed(
        offset: caretOffset(_source.text, line, column),
      );
    }
    _check = _runCheck(_source.text);
    _registry = ref.read(dirtyEditorsProvider.notifier);
    _name.addListener(_changed);
    _description.addListener(_changed);
    _source.addListener(_changed);
  }

  @override
  void dispose() {
    final registry = _registry;
    final id = _dirtyId;
    // Provider writes are not allowed while the tree unmounts.
    scheduleMicrotask(() => registry.remove(null, id));
    _checkTimer?.cancel();
    _name.dispose();
    _description.dispose();
    _source.dispose();
    super.dispose();
  }

  TemplateDraft get _draft => (
    name: _name.text.trim(),
    description: _description.text.trim(),
    format: _format,
    source: _source.text,
  );

  bool get _dirty => _draft != _baseline;

  List<SaveBlocker> get _blockers => _draft.name.isEmpty
      ? const [SaveBlocker('name', templateNameRequiredMessage)]
      : const [];

  /// Rebuilds and keeps the registry entry current.
  void _changed() {
    if (!mounted) return;
    setState(() {});
    _sync();
  }

  void _sync() {
    if (!_dirty) {
      _registry.remove(null, _dirtyId);
      return;
    }
    final existing = widget.existing;
    final name = _draft.name;
    _registry.put(
      DirtyEditor.other(
        recordId: _dirtyId,
        displayName: existing == null
            ? 'New template'
            : name.isEmpty
            ? existing.name
            : name,
        kindLabel: 'template',
        save: _saveDraft,
        discard: _discard,
        blockers: _blockers,
        saving: _saving,
        saveError: _saveError,
      ),
    );
  }

  /// Back to the baseline; the leave prompts' Discard.
  void _discard() {
    final b = _baseline;
    _format = b.format;
    _name.text = b.name;
    _description.text = b.description;
    _source.text = b.source;
    _saveError = null;
    _changed();
  }

  static TemplateCheck? _runCheck(String source) => checkTemplate(source);

  void _sourceChanged(String source) {
    _checkTimer?.cancel();
    _checkTimer = Timer(templateCheckDelay, () {
      if (!mounted) return;
      setState(() => _check = _runCheck(_source.text));
    });
  }

  bool get _canSave => _dirty && _blockers.isEmpty && !_saving;

  /// The Save button: saves and closes on success.
  Future<void> _save() async {
    if (await _saveDraft() == SaveOutcome.saved && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  /// Writes the draft through the export controller (one history row) and
  /// makes it the baseline; the dialog stays open. A failure keeps the
  /// draft and shows its message.
  Future<SaveOutcome> _saveDraft() async {
    if (!mounted || _saving) return SaveOutcome.busy;
    if (!_dirty) return SaveOutcome.nothingToSave;
    if (_blockers.isNotEmpty) return SaveOutcome.blocked;
    final draft = _draft;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    _sync();
    final controller = ref.read(exportPageProvider.notifier);
    final name = draft.name;
    final description = draft.description;
    try {
      if (widget.existing case final existing?) {
        await controller.updateTemplate(
          existing.id,
          UpdateTemplateInput(
            name: name,
            description: description,
            templateSource: draft.source,
            format: draft.format,
          ),
        );
      } else {
        await controller.createTemplate(
          CreateTemplateInput(
            name: name,
            description: description,
            templateSource: draft.source,
            format: draft.format,
          ),
        );
      }
      _saved = true;
      if (mounted) {
        _saving = false;
        _baseline = draft;
        _changed();
      }
      return SaveOutcome.saved;
    } catch (error) {
      if (mounted) {
        _saving = false;
        _saveError = listErrorMessage(error, 'Failed to save template.');
        _changed();
      }
      return error is SaveBlocked ? SaveOutcome.blocked : SaveOutcome.failed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final check = _check;
    final warning = context.forge.warning;
    final dialog = AlertDialog(
      title: Text(editing ? 'Edit Template' : 'New Custom Template'),
      content: SizedBox(
        width: _dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AnvilSpacing.sm),
              TextField(
                key: templateNameKey,
                controller: _name,
                autofocus: widget.caretAt == null,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: AnvilSpacing.md),
              TextField(
                key: templateDescriptionKey,
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: AnvilSpacing.md),
              DraftPicker<String>(
                key: templateFormatKey,
                label: 'Format',
                value: _format,
                options: templateFormats,
                onChanged: (v) {
                  _format = v;
                  _changed();
                },
              ),
              const SizedBox(height: AnvilSpacing.md),
              Text(
                'Template Source (Nunjucks)',
                style: context.text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: templateGuideToggleKey,
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(
                    bottom: AnvilSpacing.sm,
                  ),
                  dense: true,
                  title: Text(
                    'Template writing guide',
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.primary,
                    ),
                  ),
                  children: const [_WritingGuide()],
                ),
              ),
              TextField(
                key: templateSourceKey,
                controller: _source,
                autofocus: widget.caretAt != null,
                minLines: 12,
                maxLines: 24,
                keyboardType: TextInputType.multiline,
                style: ForgeType.code(),
                onChanged: _sourceChanged,
                decoration: const InputDecoration(
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              if (check != null) ...[
                const SizedBox(height: AnvilSpacing.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber, size: 16, color: warning),
                    const SizedBox(width: AnvilSpacing.xs),
                    Expanded(
                      child: Text(
                        '${check.message} (line ${check.line}, column '
                        '${check.column})',
                        key: templateCheckKey,
                        style: context.text.bodySmall?.copyWith(color: warning),
                      ),
                    ),
                  ],
                ),
              ],
              if (_saveError case final message?) ...[
                const SizedBox(height: AnvilSpacing.sm),
                Text(
                  message,
                  key: templateErrorKey,
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: templateCancelKey,
          onPressed: _saving
              ? null
              : () => Navigator.of(context).maybePop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: templateSaveKey,
          onPressed: _canSave ? _save : null,
          child: Text(editing ? 'Save Changes' : 'Create Template'),
        ),
      ],
    );
    // Cancel, Escape and a click outside close a clean dialog at once and
    // ask Save / Discard / Cancel first while it is dirty.
    return PopScope<Object?>(
      canPop: !_saving && !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _saving) return;
        final navigator = Navigator.of(context);
        final entry = findDirtyEditor(
          ref.read(dirtyEditorsProvider),
          null,
          _dirtyId,
        );
        if (await confirmLeaveEditor(context, entry)) navigator.pop(_saved);
      },
      child: dialog,
    );
  }
}

/// [templateWritingGuide], verbatim, in a bounded scroll box.
class _WritingGuide extends StatelessWidget {
  const _WritingGuide();

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxHeight: 320),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AnvilRadii.control),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AnvilSpacing.sm),
        child: SizedBox(
          width: double.infinity,
          child: SelectableText(
            templateWritingGuide,
            style: ForgeType.code(
              size: 12,
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    ),
  );
}

/// The offset of 1-based [line] and [column] in [text], clamped to the
/// line's end and the text's length.
int caretOffset(String text, int line, int column) {
  var offset = 0;
  for (var l = 1; l < line; l++) {
    final next = text.indexOf('\n', offset);
    if (next < 0) return text.length;
    offset = next + 1;
  }
  var end = text.indexOf('\n', offset);
  if (end < 0) end = text.length;
  final target = offset + (column < 1 ? 0 : column - 1);
  return target > end ? end : target;
}
