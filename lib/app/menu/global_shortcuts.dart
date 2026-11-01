/// The app-level shortcut layer (design §8.7 layer 2, §13.4): the
/// registry's bindings as [MenuCommandIntent]s with one action that runs
/// [dispatchCommand]. Mounted in `MaterialApp.router(builder:)` around the
/// router, so it is an ancestor of every route and therefore of every
/// editor's `RecordEditorShortcuts`, which sees a key first.
///
/// It never binds the framework's text undo or redo intent: a key it does
/// not handle (its action is disabled) bubbles on to the framework's
/// `DefaultTextEditingShortcuts` above it, so a text field's own Ctrl+Z
/// keeps working.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editor/editor_shortcuts.dart';
import 'app_menu.dart';
import 'menu_commands.dart';
import 'shortcut_registry.dart';

class GlobalShortcuts extends ConsumerWidget {
  const GlobalShortcuts({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bindings = ref.watch(shortcutBindingsProvider);
    return Shortcuts(
      debugLabel: 'Anvil global shortcuts',
      shortcuts: shortcutMap(bindings),
      child: Actions(
        actions: {MenuCommandIntent: _MenuCommandAction(context, ref)},
        child: child,
      ),
    );
  }
}

/// Runs a registry command from the keyboard.
///
/// Save, Undo and Redo are enabled only when they would reach an editor
/// ([editorCommandEnabled]); otherwise the key falls through. Every other
/// command is also disabled, as 0.1.6's `useGlobalShortcuts` ignored keys,
/// while the app menu has focus, while a dialog has focus, and while a text
/// field has focus.
class _MenuCommandAction extends Action<MenuCommandIntent> {
  _MenuCommandAction(this.context, this.ref);

  final BuildContext context;
  final WidgetRef ref;

  @override
  bool isEnabled(MenuCommandIntent intent) {
    if (!context.mounted || appMenuHasFocus()) return false;
    final command = intent.command;
    if (editorIntentFor(command) != null) {
      return editorCommandEnabled(command);
    }
    if (textFieldHasFocus() || _dialogHasFocus()) return false;
    return commandEnabled(ref, command);
  }

  @override
  Object? invoke(MenuCommandIntent intent) {
    unawaited(dispatchCommand(context, ref, intent.command));
    return null;
  }
}

/// True when the primary focus is inside a dialog or other popup route.
bool _dialogHasFocus() {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null || !focused.mounted) return false;
  return ModalRoute.of(focused) is PopupRoute;
}
