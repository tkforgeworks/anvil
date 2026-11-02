/// The numeric text fields every domain editor shares: [NumberDraftField]
/// for decimals and [IntDraftField] for integers.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A [TextField] whose text follows the number [value], the numeric
/// counterpart of `DraftTextField`.
///
/// Typing goes out through [onChanged] only when the text reads as a
/// number (or is empty, which reads as [emptyValue]); text that does not
/// leaves the draft unchanged and shows the field in error with
/// [invalidMessage]. A change that comes from the draft (undo, redo,
/// discard, the read-back after a save) rewrites the text only when it no
/// longer means [value], so `1.` or `1.50` typed by the user are kept.
///
/// With [zeroIsEmpty] a zero reads as null, for values where zero means
/// "none" (an ability's stat modifiers).
class NumberDraftField extends StatefulWidget {
  const NumberDraftField({
    super.key,
    this.label,
    required this.value,
    required this.onChanged,
    this.emptyValue,
    this.zeroIsEmpty = false,
    this.helperText,
    this.hintText,
    this.prefixText,
    this.issueMessage,
    this.dense = false,
  });

  /// Shown when the text is not a number.
  static const invalidMessage = 'Enter a number.';

  final String? label;

  /// The draft's current value; null shows an empty field.
  final double? value;

  final ValueChanged<double?> onChanged;

  /// What an empty field means: null (no value) by default.
  final double? emptyValue;

  final bool zeroIsEmpty;
  final String? helperText;
  final String? hintText;
  final String? prefixText;

  /// A validation issue on this field after the last save.
  final String? issueMessage;

  final bool dense;

  @override
  State<NumberDraftField> createState() => _NumberDraftFieldState();
}

/// What a field's text means: a number (or null) when [valid].
typedef _Reading = ({bool valid, double? value});

class _NumberDraftFieldState extends State<NumberDraftField> {
  late final TextEditingController _controller = TextEditingController(
    text: formatDraftNumber(widget.value),
  );
  String? _error;

  _Reading _read(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return (valid: true, value: widget.emptyValue);
    final parsed = double.tryParse(trimmed);
    if (parsed == null || !parsed.isFinite) return (valid: false, value: null);
    if (widget.zeroIsEmpty && parsed == 0) return (valid: true, value: null);
    return (valid: true, value: parsed);
  }

  @override
  void didUpdateWidget(NumberDraftField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == oldWidget.value) return;
    final reading = _read(_controller.text);
    if (reading.valid && reading.value == widget.value) return;
    final text = formatDraftNumber(widget.value);
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _error = null;
  }

  void _changed(String text) {
    final reading = _read(text);
    setState(
      () => _error = reading.valid ? null : NumberDraftField.invalidMessage,
    );
    if (reading.valid && reading.value != widget.value) {
      widget.onChanged(reading.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    keyboardType: const TextInputType.numberWithOptions(
      signed: true,
      decimal: true,
    ),
    decoration: InputDecoration(
      labelText: widget.label,
      helperText: widget.helperText,
      hintText: widget.hintText,
      prefixText: widget.prefixText,
      errorText: _error ?? widget.issueMessage,
      isDense: widget.dense,
    ),
    onChanged: _changed,
  );
}

/// [value] as 0.1.6's `String(n)` showed it: `5`, `2.5`; empty for null.
String formatDraftNumber(double? value) {
  if (value == null) return '';
  if (value == value.truncateToDouble() && value.abs() < 1e15) {
    return value.toInt().toString();
  }
  return value.toString();
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
