/// The menu and shortcut commands (design §13.4), one per 0.1.6 command id
/// in `src/renderer/src/menu/menu-data.ts` and `shortcuts.ts`, and
/// [dispatchCommand], which does what `useCommandDispatch.ts` did, mapped to
/// 0.2.0.
library;

import 'dart:async';
import 'dart:ui' show AppExitType;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editor/editor_shortcuts.dart';
import '../project/project_lifecycle.dart';
import '../providers.dart';
import '../shell/app_router.dart';
import '../shell/shell_domain.dart';
import '../shell/shell_providers.dart';
import '../welcome/create_project_dialog.dart';
import 'external_links.dart';
import 'shortcuts_dialog.dart';
import 'ui_scale.dart';

/// Every 0.1.6 menu and shortcut command, by its 0.1.6 id.
enum MenuCommand {
  // File
  newProject('new-project'),
  openProject('open-project'),
  save('save'),
  saveAs('save-as'),
  closeProject('close-project'),
  appSettings('app-settings'),
  exit('exit'),
  // View
  toggleSidebar('toggle-sidebar'),
  validationPanel('validation-panel'),
  zoomIn('zoom-in'),
  zoomOut('zoom-out'),
  zoomReset('zoom-reset'),
  themeDark('theme-dark'),
  themeLight('theme-light'),
  themeCustom('theme-custom'),
  // Project
  projectSettings('project-settings'),
  runValidation('run-validation'),
  customFieldSchemas('custom-field-schemas'),
  exportData('export'),
  importData('import'),
  // Data / navigation
  navDashboard('nav-dashboard'),
  navClasses('nav-classes'),
  navAbilities('nav-abilities'),
  navItems('nav-items'),
  navRecipes('nav-recipes'),
  navNpcs('nav-npcs'),
  navLootTables('nav-loot-tables'),
  // Editing (registry only; 0.1.6's menu had no Undo or Redo row)
  undo('undo'),
  redo('redo'),
  // Help
  documentation('documentation'),
  keyboardShortcuts('keyboard-shortcuts'),
  reportBug('report-bug'),
  about('about');

  const MenuCommand(this.id);

  /// The 0.1.6 command id, also the `customShortcuts` key.
  final String id;
}

/// The intent the global shortcut layer binds each registry key to.
class MenuCommandIntent extends Intent {
  const MenuCommandIntent(this.command);

  final MenuCommand command;
}

/// Rows that leave the menu open when chosen (0.1.6 `KEEP_OPEN`).
const keepOpenCommands = {
  MenuCommand.zoomIn,
  MenuCommand.zoomOut,
  MenuCommand.zoomReset,
  MenuCommand.toggleSidebar,
  MenuCommand.themeDark,
  MenuCommand.themeLight,
  MenuCommand.themeCustom,
};

/// Commands that do nothing without an open project (the `if (!project)
/// return` guards in `useCommandDispatch.ts`).
const _projectRequired = {
  MenuCommand.saveAs,
  MenuCommand.closeProject,
  MenuCommand.toggleSidebar,
  MenuCommand.validationPanel,
  MenuCommand.projectSettings,
  MenuCommand.customFieldSchemas,
  MenuCommand.runValidation,
  MenuCommand.exportData,
  MenuCommand.navDashboard,
  MenuCommand.navClasses,
  MenuCommand.navAbilities,
  MenuCommand.navItems,
  MenuCommand.navRecipes,
  MenuCommand.navNpcs,
  MenuCommand.navLootTables,
};

/// Where each navigation command goes.
const _routes = {
  MenuCommand.navDashboard: '/',
  MenuCommand.navClasses: '/classes',
  MenuCommand.navAbilities: '/abilities',
  MenuCommand.navItems: '/items',
  MenuCommand.navRecipes: '/recipes',
  MenuCommand.navNpcs: '/npcs',
  MenuCommand.navLootTables: '/loot-tables',
  MenuCommand.validationPanel: '/validation',
  MenuCommand.exportData: '/export',
};

/// The shell domain each Data row lists, for its record count.
const navDomains = {
  MenuCommand.navClasses: ShellDomain.classes,
  MenuCommand.navAbilities: ShellDomain.abilities,
  MenuCommand.navItems: ShellDomain.items,
  MenuCommand.navRecipes: ShellDomain.recipes,
  MenuCommand.navNpcs: ShellDomain.npcs,
  MenuCommand.navLootTables: ShellDomain.lootTables,
};

/// Commands whose dialog belongs to a later ticket: they open a placeholder
/// naming it, so the rows exist.
const _placeholderTickets = {
  MenuCommand.appSettings: ('Application Settings', 'ANVL-189'),
  MenuCommand.projectSettings: ('Project Settings', 'ANVL-190'),
  MenuCommand.customFieldSchemas: ('Custom Field Schemas', 'ANVL-190'),
};

/// Asks where to save a copy of the project, starting at [suggestedPath];
/// null when cancelled.
typedef SaveLocationPicker = Future<String?> Function({
  required String suggestedPath,
});

/// The Save As dialog. `FileDialogs` has no save dialog yet, so this is
/// null and Save As is disabled until one is wired here (tests override
/// it).
final saveLocationPickerProvider = Provider<SaveLocationPicker?>((ref) => null);

/// Asks the platform to quit through the exit request the runners forward
/// to `AppLifecycleListener.onExitRequested` (design §8.8), as 0.1.6's
/// Exit closed the window; tests override it.
final exitApplicationProvider = Provider<Future<void> Function()>(
  (ref) =>
      () => ServicesBinding.instance.exitApplication(AppExitType.cancelable),
);

/// The editor intent a Save, Undo or Redo command stands for.
Intent? editorIntentFor(MenuCommand command) => switch (command) {
  MenuCommand.save => const SaveRecordIntent(),
  MenuCommand.undo => const UndoDraftIntent(),
  MenuCommand.redo => const RedoDraftIntent(),
  _ => null,
};

/// The context Save, Undo and Redo act from: [focus] (the focus the menu
/// remembered when it opened) or the primary focus.
BuildContext? _editorContext(FocusNode? focus) {
  final context = (focus ?? FocusManager.instance.primaryFocus)?.context;
  return context != null && context.mounted ? context : null;
}

/// Whether [command] (Save, Undo or Redo) would reach an editor: an
/// editor's `RecordEditorShortcuts` is in the focus chain of [focus] (or
/// the primary focus) and its action is enabled. A draft undo is disabled
/// while a text field has focus, so the key goes on to the field's own undo.
bool editorCommandEnabled(MenuCommand command, {FocusNode? focus}) {
  final intent = editorIntentFor(command);
  final context = _editorContext(focus);
  if (intent == null || context == null) return false;
  final action = Actions.maybeFind<Intent>(context, intent: intent);
  return action != null && action.isEnabled(intent);
}

/// Why [command] is disabled with no other way to tell, shown as the row's
/// tooltip, or null.
String? disabledTooltip(WidgetRef ref, MenuCommand command) =>
    switch (command) {
      MenuCommand.importData => 'Coming soon',
      MenuCommand.about => 'Not yet in 0.2.0',
      MenuCommand.saveAs when ref.read(saveLocationPickerProvider) == null =>
        'Needs a save dialog',
      _ => null,
    };

/// Whether [command] can run now. Save, Undo and Redo need an editor in the
/// focus chain of [focus] (see [editorCommandEnabled]).
bool commandEnabled(WidgetRef ref, MenuCommand command, {FocusNode? focus}) {
  if (editorIntentFor(command) != null) {
    return editorCommandEnabled(command, focus: focus);
  }
  if (_projectRequired.contains(command) &&
      ref.read(projectSessionProvider) == null) {
    return false;
  }
  return switch (command) {
    MenuCommand.importData || MenuCommand.about => false,
    MenuCommand.saveAs => ref.read(saveLocationPickerProvider) != null,
    MenuCommand.themeCustom =>
      ref.read(appSettingsProvider).customThemePath != null,
    _ => true,
  };
}

/// Runs [command] if it is enabled (`useCommandDispatch.ts`). [context] is
/// any context below the `ProviderScope`; dialogs open on the router's root
/// navigator, so the global shortcut layer above it can dispatch too.
/// [focus] is the focus Save, Undo and Redo act from (the menu passes what
/// had focus when it opened).
Future<void> dispatchCommand(
  BuildContext context,
  WidgetRef ref,
  MenuCommand command, {
  FocusNode? focus,
}) async {
  if (!commandEnabled(ref, command, focus: focus)) return;
  final router = ref.read(routerProvider);
  final dialogContext = router.routerDelegate.navigatorKey.currentContext;
  final lifecycle = ref.read(projectLifecycleProvider.notifier);

  if (_routes[command] case final location?) {
    router.go(location);
    return;
  }
  if (_placeholderTickets[command] case (final title, final ticket)) {
    if (dialogContext != null) {
      await showPlaceholderDialog(dialogContext, title, ticket);
    }
    return;
  }
  switch (command) {
    case MenuCommand.save || MenuCommand.undo || MenuCommand.redo:
      final target = _editorContext(focus);
      if (target != null) {
        Actions.maybeInvoke(target, editorIntentFor(command)!);
      }
    case MenuCommand.newProject:
      if (dialogContext != null) await showCreateProjectDialog(dialogContext);
    case MenuCommand.openProject:
      await lifecycle.openWithDialog();
    case MenuCommand.saveAs:
      await _saveAs(ref, dialogContext);
    case MenuCommand.closeProject:
      await lifecycle.closeProject();
    case MenuCommand.exit:
      await ref.read(exitApplicationProvider)();
    case MenuCommand.toggleSidebar:
      ref.read(sidebarCollapsedProvider.notifier).toggle();
    case MenuCommand.zoomIn:
      ref.read(uiScaleProvider.notifier).zoomIn();
    case MenuCommand.zoomOut:
      ref.read(uiScaleProvider.notifier).zoomOut();
    case MenuCommand.zoomReset:
      ref.read(uiScaleProvider.notifier).reset();
    case MenuCommand.themeDark:
      ref.read(appSettingsProvider.notifier).setTheme(AppThemeMode.dark);
    case MenuCommand.themeLight:
      ref.read(appSettingsProvider.notifier).setTheme(AppThemeMode.light);
    case MenuCommand.themeCustom:
      ref.read(appSettingsProvider.notifier).setTheme(AppThemeMode.custom);
    case MenuCommand.runValidation:
      unawaited(
        ref
            .read(validationIssuesProvider.notifier)
            .refresh()
            .then((_) {}, onError: (Object _) {}),
      );
    case MenuCommand.keyboardShortcuts:
      if (dialogContext != null) await showShortcutsDialog(dialogContext);
    case MenuCommand.documentation:
      await openExternal(
        documentationUrl,
        launch: ref.read(urlLauncherProvider),
      );
    case MenuCommand.reportBug:
      await openExternal(reportBugUrl, launch: ref.read(urlLauncherProvider));
    case _:
      break;
  }
}

/// Opens the recent project at [path] (0.1.6 `RecentSubmenu`).
Future<void> openRecentProject(WidgetRef ref, String path) =>
    ref.read(projectLifecycleProvider.notifier).openPath(path);

/// Empties the recent list.
void clearRecentProjects(WidgetRef ref) =>
    ref.read(projectLifecycleProvider.notifier).clearRecents();

Future<void> _saveAs(WidgetRef ref, BuildContext? dialogContext) async {
  final picker = ref.read(saveLocationPickerProvider);
  final session = ref.read(projectSessionProvider);
  if (picker == null || session == null) return;
  final path = await picker(suggestedPath: session.filePath);
  if (path == null) return;
  final failure = await ref
      .read(projectLifecycleProvider.notifier)
      .saveAs(path);
  if (failure != null && dialogContext != null && dialogContext.mounted) {
    ScaffoldMessenger.maybeOf(dialogContext)
        ?.showSnackBar(SnackBar(content: Text(failure)));
  }
}

/// A dialog standing in for one a later ticket builds.
Future<void> showPlaceholderDialog(
  BuildContext context,
  String title,
  String ticket,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(title),
    content: Text('Coming in $ticket'),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Close'),
      ),
    ],
  ),
);
