/// The keyboard and focus wrapper every record editor puts around its
/// content (design §8.7).
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'editor_shortcuts.dart';
import 'editor_state.dart';
import 'record_editor_controller.dart';

/// Gives the editor below it Ctrl+S (save, wherever the cursor is inside
/// the editor), Ctrl+Z (the field's own undo inside a text field, a draft
/// step back outside one) and Ctrl+Shift+Z / Ctrl+Y (the matching redo).
///
/// ```dart
/// RecordEditorScope(
///   provider: recipeEditorProvider(recordId),
///   onSaveOutcome: showOutcome,
///   child: ...,
/// )
/// ```
///
/// It composes [RecordEditorShortcuts] around an autofocus [FocusScope]
/// labelled `editor`, which takes primary focus when the editor opens and
/// again when a click outside a field unfocuses it, so the editor's
/// shortcuts stay reachable (ANVL-158 gotcha 4). Without it primary focus
/// would sit on the route's scope, above the editor's `Shortcuts`.
///
/// The scope reads [provider]'s notifier only when a key is pressed and
/// watches nothing, so it never rebuilds with the draft; [child] watches
/// the provider for what it shows, which also keeps the `autoDispose`
/// editor alive.
class RecordEditorScope<T> extends ConsumerStatefulWidget {
  const RecordEditorScope({
    super.key,
    required this.provider,
    this.onSaveOutcome,
    required this.child,
  });

  /// The editor's provider for one record: `xEditorProvider(recordId)`.
  final AsyncNotifierProvider<RecordEditorController<T>, EditorState<T>>
  provider;

  /// Receives the outcome of a Ctrl+S save while the scope is still
  /// mounted, so the editor scaffold can show it. Ctrl+S on a clean draft
  /// reports [SaveOutcome.nothingToSave].
  final ValueChanged<SaveOutcome>? onSaveOutcome;

  final Widget child;

  @override
  ConsumerState<RecordEditorScope<T>> createState() =>
      _RecordEditorScopeState<T>();
}

class _RecordEditorScopeState<T> extends ConsumerState<RecordEditorScope<T>> {
  final FocusScopeNode _editorScope = FocusScopeNode(debugLabel: 'editor');

  RecordEditorController<T> get _controller =>
      ref.read(widget.provider.notifier);

  @override
  void dispose() {
    _editorScope.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final outcome = await _controller.save();
    if (mounted) widget.onSaveOutcome?.call(outcome);
  }

  @override
  Widget build(BuildContext context) {
    return RecordEditorShortcuts(
      onSave: _save,
      onUndo: () => _controller.undo(),
      onRedo: () => _controller.redo(),
      child: FocusScope(
        node: _editorScope,
        autofocus: true,
        child: widget.child,
      ),
    );
  }
}
