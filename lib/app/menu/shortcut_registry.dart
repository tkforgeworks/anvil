/// The keyboard shortcut registry (design §13.4), ported from 0.1.6's
/// `src/renderer/src/menu/shortcuts.ts` and `useGlobalShortcuts.ts`: the
/// same ids, labels, groups and default bindings, the same binding string
/// format, and the user's `customShortcuts` overrides from app settings.
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'menu_commands.dart';

/// The cheatsheet groups, in 0.1.6's `GROUP_ORDER`.
enum ShortcutGroup {
  file('File'),
  navigation('Navigation'),
  editing('Editing'),
  view('View'),
  project('Project'),
  help('Help');

  const ShortcutGroup(this.label);

  final String label;
}

/// One registry entry. The id is also the `customShortcuts` key.
final class ShortcutEntry {
  const ShortcutEntry(
    this.command,
    this.label,
    this.group,
    this.defaultBinding,
  );

  /// What the shortcut runs; its id is the entry's id.
  final MenuCommand command;
  final String label;
  final ShortcutGroup group;

  /// The 0.1.6 binding string, such as `Ctrl+Shift+Z`.
  final String defaultBinding;

  String get id => command.id;
}

/// The 0.1.6 registry, in its order (which is also the cheatsheet's order
/// within a group, and the order that decides a collision).
const shortcutRegistry = <ShortcutEntry>[
  // File
  ShortcutEntry(
    MenuCommand.newProject,
    'New Project…',
    ShortcutGroup.file,
    'Ctrl+N',
  ),
  ShortcutEntry(
    MenuCommand.openProject,
    'Open Project…',
    ShortcutGroup.file,
    'Ctrl+O',
  ),
  ShortcutEntry(MenuCommand.save, 'Save', ShortcutGroup.file, 'Ctrl+S'),
  ShortcutEntry(
    MenuCommand.saveAs,
    'Save As…',
    ShortcutGroup.file,
    'Ctrl+Shift+S',
  ),
  ShortcutEntry(
    MenuCommand.closeProject,
    'Close Project',
    ShortcutGroup.file,
    'Ctrl+W',
  ),
  // Navigation
  ShortcutEntry(
    MenuCommand.navDashboard,
    'Dashboard',
    ShortcutGroup.navigation,
    'Ctrl+1',
  ),
  ShortcutEntry(
    MenuCommand.navClasses,
    'Classes',
    ShortcutGroup.navigation,
    'Ctrl+2',
  ),
  ShortcutEntry(
    MenuCommand.navAbilities,
    'Abilities',
    ShortcutGroup.navigation,
    'Ctrl+3',
  ),
  ShortcutEntry(
    MenuCommand.navItems,
    'Items',
    ShortcutGroup.navigation,
    'Ctrl+4',
  ),
  ShortcutEntry(
    MenuCommand.navRecipes,
    'Recipes',
    ShortcutGroup.navigation,
    'Ctrl+5',
  ),
  ShortcutEntry(
    MenuCommand.navNpcs,
    'NPCs',
    ShortcutGroup.navigation,
    'Ctrl+6',
  ),
  ShortcutEntry(
    MenuCommand.navLootTables,
    'Loot Tables',
    ShortcutGroup.navigation,
    'Ctrl+7',
  ),
  // Editing
  ShortcutEntry(MenuCommand.undo, 'Undo', ShortcutGroup.editing, 'Ctrl+Z'),
  ShortcutEntry(
    MenuCommand.redo,
    'Redo',
    ShortcutGroup.editing,
    'Ctrl+Shift+Z',
  ),
  // View
  ShortcutEntry(
    MenuCommand.toggleSidebar,
    'Toggle Sidebar',
    ShortcutGroup.view,
    'Ctrl+B',
  ),
  ShortcutEntry(
    MenuCommand.validationPanel,
    'Validation Panel',
    ShortcutGroup.view,
    'Ctrl+Shift+V',
  ),
  ShortcutEntry(MenuCommand.zoomIn, 'Zoom In', ShortcutGroup.view, 'Ctrl+='),
  ShortcutEntry(MenuCommand.zoomOut, 'Zoom Out', ShortcutGroup.view, 'Ctrl+-'),
  ShortcutEntry(
    MenuCommand.zoomReset,
    'Reset Zoom',
    ShortcutGroup.view,
    'Ctrl+0',
  ),
  // Project
  ShortcutEntry(
    MenuCommand.projectSettings,
    'Project Settings',
    ShortcutGroup.project,
    'Ctrl+,',
  ),
  ShortcutEntry(
    MenuCommand.exportData,
    'Export…',
    ShortcutGroup.project,
    'Ctrl+E',
  ),
  // Help
  ShortcutEntry(
    MenuCommand.documentation,
    'Documentation',
    ShortcutGroup.help,
    'F1',
  ),
  ShortcutEntry(
    MenuCommand.keyboardShortcuts,
    'Keyboard Shortcuts',
    ShortcutGroup.help,
    'Ctrl+/',
  ),
];

/// Named keys a binding may end in, by their lower-cased 0.1.6
/// `KeyboardEvent.key` name.
final Map<String, LogicalKeyboardKey> _namedKeys = {
  'enter': LogicalKeyboardKey.enter,
  'escape': LogicalKeyboardKey.escape,
  'tab': LogicalKeyboardKey.tab,
  'backspace': LogicalKeyboardKey.backspace,
  'delete': LogicalKeyboardKey.delete,
  'insert': LogicalKeyboardKey.insert,
  'home': LogicalKeyboardKey.home,
  'end': LogicalKeyboardKey.end,
  'pageup': LogicalKeyboardKey.pageUp,
  'pagedown': LogicalKeyboardKey.pageDown,
  'arrowup': LogicalKeyboardKey.arrowUp,
  'arrowdown': LogicalKeyboardKey.arrowDown,
  'arrowleft': LogicalKeyboardKey.arrowLeft,
  'arrowright': LogicalKeyboardKey.arrowRight,
  for (final (i, key) in const [
    LogicalKeyboardKey.f1,
    LogicalKeyboardKey.f2,
    LogicalKeyboardKey.f3,
    LogicalKeyboardKey.f4,
    LogicalKeyboardKey.f5,
    LogicalKeyboardKey.f6,
    LogicalKeyboardKey.f7,
    LogicalKeyboardKey.f8,
    LogicalKeyboardKey.f9,
    LogicalKeyboardKey.f10,
    LogicalKeyboardKey.f11,
    LogicalKeyboardKey.f12,
  ].indexed)
    'f${i + 1}': key,
};

/// The printable keys a binding may end in: letters, digits and the US
/// layout's unshifted punctuation. Their logical key id is the character.
final _printable = RegExp(r"^[a-z0-9=\-/,.;'\[\]\\`]$");

/// Parses a 0.1.6 binding string into the activator it means, or returns
/// null when it is not one.
///
/// The format is `useGlobalShortcuts.ts`'s: parts joined by `+`, the last
/// part the key, compared case-insensitively (`Ctrl+Z` and `Ctrl+z` are the
/// same), and any of the modifiers `Ctrl`, `Shift` and `Alt` before it,
/// case-sensitive and in any order. A key is one letter, digit or unshifted
/// punctuation character, `F1`-`F12`, or one of the named keys above.
///
/// Stricter than 0.1.6, which ignored an unknown modifier (`Cmd+S` bound a
/// plain `s`) and accepted any key name: those are rejected here. `Ctrl`
/// means the Control key only; 0.1.6 also accepted Meta, which Windows and
/// Linux keyboards do not use for shortcuts.
SingleActivator? parseBinding(String binding) {
  final parts = binding.split('+');
  if (parts.isEmpty) return null;
  final keyName = parts.last.toLowerCase();
  final modifiers = parts.sublist(0, parts.length - 1);
  if (modifiers.toSet().length != modifiers.length) return null;
  if (!modifiers.every(const {'Ctrl', 'Shift', 'Alt'}.contains)) return null;
  final LogicalKeyboardKey? key;
  if (_printable.hasMatch(keyName)) {
    key = LogicalKeyboardKey.findKeyByKeyId(keyName.codeUnitAt(0));
  } else {
    key = _namedKeys[keyName];
  }
  if (key == null) return null;
  return SingleActivator(
    key,
    control: modifiers.contains('Ctrl'),
    shift: modifiers.contains('Shift'),
    alt: modifiers.contains('Alt'),
  );
}

/// One registry entry with the binding in effect.
final class ShortcutBinding {
  const ShortcutBinding(this.entry, this.binding, this.activator);

  final ShortcutEntry entry;

  /// The binding string in effect: the user's override or the default.
  final String binding;
  final SingleActivator activator;

  /// Two bindings with the same key collide; see [shortcutMap].
  String get keyIdentity =>
      '${activator.trigger.keyId}:${activator.control}:'
      '${activator.shift}:${activator.alt}';
}

/// The registry with [customShortcuts] applied (`getEffectiveShortcuts`),
/// in registry order. An override replaces the default binding; an empty
/// override is ignored as in 0.1.6, and so is one [parseBinding] rejects,
/// which is reported to [onInvalid] and leaves the default in place.
/// Overrides for ids not in the registry are ignored.
List<ShortcutBinding> effectiveBindings(
  List<ShortcutEntry> registry,
  Map<String, String>? customShortcuts, {
  void Function(String id, String binding)? onInvalid,
}) => [
  for (final entry in registry) _bindingFor(entry, customShortcuts, onInvalid),
];

ShortcutBinding _bindingFor(
  ShortcutEntry entry,
  Map<String, String>? customShortcuts,
  void Function(String id, String binding)? onInvalid,
) {
  final override = customShortcuts?[entry.id];
  if (override != null && override.isNotEmpty) {
    final activator = parseBinding(override);
    if (activator != null) return ShortcutBinding(entry, override, activator);
    onInvalid?.call(entry.id, override);
  }
  return ShortcutBinding(
    entry,
    entry.defaultBinding,
    parseBinding(entry.defaultBinding)!,
  );
}

/// The `Shortcuts` map for [bindings]. When two bindings share a key, the
/// first in registry order keeps it, as 0.1.6's first-match loop did.
Map<ShortcutActivator, Intent> shortcutMap(List<ShortcutBinding> bindings) {
  final seen = <String>{};
  return {
    for (final b in bindings)
      if (seen.add(b.keyIdentity))
        b.activator: MenuCommandIntent(b.entry.command),
  };
}

/// The bindings in effect, recomputed whenever the app settings change, so
/// an override applies at once. Invalid overrides are logged as warnings.
final shortcutBindingsProvider = Provider<List<ShortcutBinding>>((ref) {
  final custom = ref.watch(
    appSettingsProvider.select((s) => s.customShortcuts),
  );
  return effectiveBindings(
    shortcutRegistry,
    custom,
    onInvalid: (id, binding) => ref
        .read(appLoggerProvider)
        .warn('Ignoring custom shortcut for $id: "$binding" is not a binding'),
  );
});

/// The binding in effect for [command], or null when it has none.
ShortcutBinding? bindingFor(
  List<ShortcutBinding> bindings,
  MenuCommand command,
) {
  for (final b in bindings) {
    if (b.entry.command == command) return b;
  }
  return null;
}
