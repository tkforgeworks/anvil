/// Keyboard layer for a record editor.
///
/// ```
/// WidgetsApp
///   DefaultTextEditingShortcuts      Ctrl+Z -> UndoTextIntent (framework)
///     ... route ...
///       RecordEditorShortcuts        Ctrl+S -> SaveRecordIntent
///         Shortcuts                  Ctrl+Z -> UndoDraftIntent
///         Actions                    Ctrl+Shift+Z / Ctrl+Y -> RedoDraftIntent
///           FocusScope (editor)      primary focus when no field has it
///             TextField ...          UndoHistory handles UndoTextIntent
/// ```
///
/// Key events bubble from the focused node up. The editor's Shortcuts sees
/// Ctrl+Z before the framework's DefaultTextEditingShortcuts does, so the
/// draft-undo action disables itself while a text field has focus. A
/// disabled action makes the Shortcuts widget return `ignored`, the event
/// keeps bubbling, and the framework turns it into the field's own
/// UndoTextIntent. Ctrl+S has no framework binding, so it is handled here
/// whatever has focus inside the editor.
///
/// Rejected: overriding UndoTextIntent itself in an ancestor Actions. The
/// field registers its undo with `Action.overridable`, so an ancestor
/// UndoTextIntent action silently replaces every field's native undo unless
/// it remembers to delegate to `callingAction`.
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class SaveRecordIntent extends Intent {
  const SaveRecordIntent();
}

class UndoDraftIntent extends Intent {
  const UndoDraftIntent();
}

class RedoDraftIntent extends Intent {
  const RedoDraftIntent();
}

/// True when the primary focus is inside an [EditableText].
bool textFieldHasFocus() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  return context.widget is EditableText ||
      context.findAncestorStateOfType<EditableTextState>() != null;
}

/// Enabled only when no text field has focus, so the key falls through to
/// the field's own undo/redo otherwise.
class _DraftHistoryAction<T extends Intent> extends Action<T> {
  _DraftHistoryAction(this.onInvoke);

  final VoidCallback onInvoke;

  @override
  bool isEnabled(T intent) => !textFieldHasFocus();

  @override
  Object? invoke(T intent) {
    onInvoke();
    return null;
  }
}

class RecordEditorShortcuts extends StatelessWidget {
  const RecordEditorShortcuts({
    super.key,
    required this.onSave,
    required this.onUndo,
    required this.onRedo,
    required this.child,
  });

  final VoidCallback onSave;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final Widget child;

  static const Map<ShortcutActivator, Intent> shortcuts = {
    SingleActivator(LogicalKeyboardKey.keyS, control: true): SaveRecordIntent(),
    SingleActivator(LogicalKeyboardKey.keyZ, control: true): UndoDraftIntent(),
    SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
        RedoDraftIntent(),
    SingleActivator(LogicalKeyboardKey.keyY, control: true): RedoDraftIntent(),
  };

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: {
          SaveRecordIntent: CallbackAction<SaveRecordIntent>(
            onInvoke: (_) {
              onSave();
              return null;
            },
          ),
          UndoDraftIntent: _DraftHistoryAction<UndoDraftIntent>(onUndo),
          RedoDraftIntent: _DraftHistoryAction<RedoDraftIntent>(onRedo),
        },
        child: child,
      ),
    );
  }
}
