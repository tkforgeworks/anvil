/// The custom template dialog of the export page (0.1.6's inline dialog in
/// `ExportPage.tsx`): name, description, format and the template source,
/// with the 0.2 writing guide behind a toggle and the renderer's own check
/// shown under the source as a warning.
///
/// The fields are plain `TextEditingController`s; the draft and undo layer
/// for this dialog is ANVL-165's.
library;

import 'dart:async';

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

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
    _name.addListener(_rebuild);
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _name.dispose();
    _description.dispose();
    _source.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  static TemplateCheck? _runCheck(String source) => checkTemplate(source);

  void _sourceChanged(String source) {
    _checkTimer?.cancel();
    _checkTimer = Timer(templateCheckDelay, () {
      if (!mounted) return;
      setState(() => _check = _runCheck(_source.text));
    });
  }

  bool get _canSave => _name.text.trim().isNotEmpty && !_saving;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final controller = ref.read(exportPageProvider.notifier);
    final name = _name.text.trim();
    final description = _description.text.trim();
    try {
      if (widget.existing case final existing?) {
        await controller.updateTemplate(
          existing.id,
          UpdateTemplateInput(
            name: name,
            description: description,
            templateSource: _source.text,
            format: _format,
          ),
        );
      } else {
        await controller.createTemplate(
          CreateTemplateInput(
            name: name,
            description: description,
            templateSource: _source.text,
            format: _format,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = listErrorMessage(error, 'Failed to save template.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final check = _check;
    final warning = context.forge.warning;
    return AlertDialog(
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
                onChanged: (v) => setState(() => _format = v),
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
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: templateSaveKey,
          onPressed: _canSave ? _save : null,
          child: Text(editing ? 'Save Changes' : 'Create Template'),
        ),
      ],
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
