/// The text field every record editor binds to one string of its draft
/// (design §8.4, §8.7), ported from the ANVL-158 spike.
///
/// Pickers are not text fields: editors use `DropdownButton` or a menu
/// anchor for them, never `DropdownMenu`, which hosts an `EditableText` and
/// would turn Ctrl+Z on the picker into a text undo instead of a draft undo
/// (design §8.7).
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:forge_ui/forge_ui.dart';

/// A [TextField] whose text follows [value].
///
/// Typing goes out through [onChanged], which also carries the field's own
/// Ctrl+Z, since the framework's undo history applies it as a user edit.
/// A change that comes from the draft instead (a draft undo or redo, a
/// discard, the read-back after a save) is written into the field only when
/// it differs from what the field shows, and keeps the caret and selection
/// where they were, clamped to the new text. The spike moved the caret to
/// the end on every such change.
///
/// [blockerMessage] (a save blocker on this field) wins over
/// [issueMessage] (a validation issue after the last save, for example from
/// `fieldIssueText`). Both show as the field's error text, except an issue
/// whose [issueSeverity] is not an error, which shows as helper text, as
/// 0.1.6's `fieldValidationProps` set `error` only for errors.
class DraftTextField extends StatefulWidget {
  const DraftTextField({
    super.key,
    this.label,
    required this.value,
    required this.onChanged,
    this.blockerMessage,
    this.issueMessage,
    this.issueSeverity = ValidationSeverity.error,
    this.hintText,
    this.maxLines = 1,
    this.style,
    this.decoration,
    this.enabled = true,
  });

  final String? label;

  /// The draft's current value of this field.
  final String value;

  /// Receives every change the user makes, typing and the field's own undo
  /// alike; the editor turns it into a coalesced draft edit.
  final ValueChanged<String> onChanged;

  final String? blockerMessage;
  final String? issueMessage;
  final ValidationSeverity issueSeverity;
  final String? hintText;
  final int? maxLines;
  final TextStyle? style;

  /// The base decoration, which the label, hint and messages are laid
  /// over; the theme's when null.
  final InputDecoration? decoration;

  final bool enabled;

  @override
  State<DraftTextField> createState() => _DraftTextFieldState();
}

class _DraftTextFieldState extends State<DraftTextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(DraftTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final text = widget.value;
    if (text == _controller.text) return;
    _controller.value = TextEditingValue(
      text: text,
      selection: _clamp(_controller.selection, text.length),
    );
  }

  /// [selection] with both ends limited to [length]; a collapsed caret at
  /// the end when the field never had one.
  static TextSelection _clamp(TextSelection selection, int length) {
    if (!selection.isValid) return TextSelection.collapsed(offset: length);
    int limit(int offset) => offset > length ? length : offset;
    return selection.copyWith(
      baseOffset: limit(selection.baseOffset),
      extentOffset: limit(selection.extentOffset),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blocker = widget.blockerMessage;
    final issue = widget.issueMessage;
    final issueIsError = widget.issueSeverity == ValidationSeverity.error;
    final errorText = blocker ?? (issueIsError ? issue : null);
    final helperText = blocker == null && !issueIsError ? issue : null;
    final base = widget.decoration ?? const InputDecoration();
    return TextField(
      controller: _controller,
      enabled: widget.enabled,
      maxLines: widget.maxLines,
      style: widget.style,
      decoration: base.copyWith(
        labelText: widget.label,
        hintText: widget.hintText,
        errorText: errorText,
        helperText: helperText,
        helperStyle: helperText == null
            ? null
            : context.text.bodySmall?.copyWith(color: context.forge.warning),
      ),
      onChanged: widget.onChanged,
    );
  }
}

/// The message of the first of [blockers] on [field], for a
/// [DraftTextField.blockerMessage]; null when the field breaks no rule.
String? blockerText(List<SaveBlocker> blockers, String field) {
  for (final blocker in blockers) {
    if (blocker.field == field) return blocker.message;
  }
  return null;
}
