/// The two input widgets the recipe pages need beyond `DraftTextField`: a
/// `DropdownButton` picker that shows an error or helper text, and an
/// integer field whose text follows the draft.
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forge_ui/forge_ui.dart';

/// One choice of a [RecipePicker].
typedef PickerOption = ({String value, String label});

/// A labelled [DropdownButton] over [options] (never `DropdownMenu`, design
/// §8.7). `MetaPicker` in the project settings has the same shape but no
/// error text, which the recipe pickers need for blockers and validation.
///
/// [value] must be one of the option values; a picker with no matching
/// option shows empty. [errorText] wins over [helperText].
class RecipePicker extends StatelessWidget {
  const RecipePicker({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.errorText,
    this.helperText,
    this.helperIsWarning = false,
    this.dense = false,
  });

  final String label;
  final String value;
  final List<PickerOption> options;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final String? helperText;

  /// Shows [helperText] in the warning colour (a validation warning).
  final bool helperIsWarning;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final known = options.any((o) => o.value == value);
    final change = onChanged;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        helperText: errorText == null ? helperText : null,
        helperStyle: helperIsWarning
            ? context.text.bodySmall?.copyWith(color: context.forge.warning)
            : null,
        isDense: dense,
        enabled: change != null,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: known ? value : null,
          isDense: true,
          isExpanded: true,
          items: [
            for (final o in options)
              DropdownMenuItem(
                value: o.value,
                child: Text(o.label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: change == null
              ? null
              : (v) {
                  if (v != null && v != value) change(v);
                },
        ),
      ),
    );
  }
}

/// The error and helper text a field shows for [blocker] (a save blocker)
/// and [issue] (a validation issue from the last save), as
/// `DraftTextField` resolves them: a blocker or an error issue is the
/// error text, any other issue the helper text.
({String? error, String? helper, bool warning}) fieldMessages(
  String? blocker,
  ValidationIssue? issue,
) {
  if (blocker != null) return (error: blocker, helper: null, warning: false);
  if (issue == null) return (error: null, helper: null, warning: false);
  if (issue.severity == ValidationSeverity.error) {
    return (error: issue.message, helper: null, warning: false);
  }
  return (error: null, helper: issue.message, warning: true);
}

/// A digits-only field bound to an integer of the draft.
///
/// Typing goes out through [onChanged] (an empty field as 0, which the
/// save blockers refuse). A change from the draft (undo, redo, discard,
/// the read-back) is written into the field only when the field's own
/// number differs from it, so typing over an empty field is not disturbed.
class IntDraftField extends StatefulWidget {
  const IntDraftField({
    super.key,
    this.label,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.dense = false,
  });

  final String? label;
  final int value;
  final ValueChanged<int> onChanged;
  final String? errorText;
  final bool dense;

  /// The number [text] stands for: empty is 0.
  static int parse(String text) => int.tryParse(text) ?? 0;

  @override
  State<IntDraftField> createState() => _IntDraftFieldState();
}

class _IntDraftFieldState extends State<IntDraftField> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.value}',
  );

  @override
  void didUpdateWidget(IntDraftField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (IntDraftField.parse(_controller.text) == widget.value) return;
    final text = '${widget.value}';
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(
      labelText: widget.label,
      errorText: widget.errorText,
      errorMaxLines: 3,
      isDense: widget.dense,
    ),
    onChanged: (text) => widget.onChanged(IntDraftField.parse(text)),
  );
}
