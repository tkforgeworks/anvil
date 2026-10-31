import 'package:flutter/material.dart';

/// A TextField bound to one string in the draft.
///
/// User typing goes out through [onChanged] (which also carries the field's
/// own Ctrl+Z, since UndoHistory applies it as a user edit). Changes coming
/// from the draft (draft undo/redo, discard, save read-back) are written into
/// the controller when they differ from what the field shows.
class DraftTextField extends StatefulWidget {
  const DraftTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.maxLines = 1,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final int maxLines;

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
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(labelText: widget.label),
      maxLines: widget.maxLines,
      onChanged: widget.onChanged,
    );
  }
}
