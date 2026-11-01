/// Keyboard layer for a record editor (design §8.7), ported unchanged from
/// the ANVL-158 spike. `RecordEditorScope` composes it with the editor's
/// own `FocusScope`; domain editors use that, not this widget directly.
///
/// ```
/// WidgetsApp
///   DefaultTextEditingShortcuts      Ctrl+Z -> text undo intent (framework)
///     ... route ...
///       RecordEditorShortcuts        Ctrl+S -> SaveRecordIntent
///         Shortcuts                  Ctrl+Z -> UndoDraftIntent
///         Actions                    Ctrl+Shift+Z / Ctrl+Y -> RedoDraftIntent
///           FocusScope (editor)      primary focus when no field has it
///             TextField ...          UndoHistory handles the text undo
/// ```
///
/// Key events bubble from the focused node up. The editor's Shortcuts sees
/// Ctrl+Z before the framework's DefaultTextEditingShortcuts does, so the
/// draft-undo action disables itself while a text field has focus. A
/// disabled action makes the Shortcuts widget return `ignored`, the event
/// keeps bubbling, and the framework turns it into the field's own
/// text undo intent. Ctrl+S has no framework binding, so it is handled here
/// whatever has focus inside the editor.
///
/// Rejected: overriding the framework's text undo intent itself in an
/// ancestor Actions. The field registers its undo with
/// `Action.overridable`, so an ancestor action for that intent silently
/// replaces every field's native undo unless it remembers to delegate to
/// `callingAction`. For the same reason the app-shell shortcut registry
/// (ANVL-186) never binds the framework's text undo or redo intent
/// (ANVL-158 gotcha 2). Their class names are not written anywhere in
/// `lib/`, so a grep for them finds only such a binding.
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Ctrl+S: save the editor's draft, wherever focus is inside the editor.
class SaveRecordIntent extends Intent {
  const SaveRecordIntent();
}

/// Ctrl+Z outside a text field: step the draft back.
class UndoDraftIntent extends Intent {
  const UndoDraftIntent();
}

/// Ctrl+Shift+Z or Ctrl+Y outside a text field: step the draft forward.
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

/// Binds Ctrl+S, Ctrl+Z, Ctrl+Shift+Z and Ctrl+Y for the editor below it.
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
