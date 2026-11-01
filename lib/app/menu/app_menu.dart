/// The hamburger menu (ANVL-113, design §13.4): the 0.1.6 `MENU_DATA`
/// sections File, View, Project, Data and Help as cascading submenus of one
/// `MenuAnchor`, whose built-in keyboard navigation replaces
/// `useMenuKeyboard` (arrows move and open, Esc closes a submenu and then
/// the panel). Rows show the binding in effect and run [dispatchCommand].
library;

import 'dart:async';

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../project/project_lifecycle.dart';
import '../providers.dart';
import '../shell/shell_providers.dart';
import '../theme/anvil_metrics.dart';
import '../widgets/formatting.dart';
import 'menu_commands.dart';
import 'shortcut_registry.dart';

/// Marks the app menu's widgets, so the global shortcut layer can tell when
/// focus is inside the menu ([appMenuHasFocus]).
class AppMenuRegion extends StatelessWidget {
  const AppMenuRegion({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// True when the primary focus is on a row of the app menu. 0.1.6 ignored
/// global shortcuts while its menu was open; the menu's own keys still work.
bool appMenuHasFocus() {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null || !focused.mounted) return false;
  return focused.findAncestorWidgetOfExactType<AppMenuRegion>() != null;
}

/// The hamburger button in the app bar and its menu.
class AppMenuButton extends ConsumerStatefulWidget {
  const AppMenuButton({super.key});

  /// The menu's section labels, in 0.1.6 order.
  static const sections = ['File', 'View', 'Project', 'Data', 'Help'];

  @override
  ConsumerState<AppMenuButton> createState() => _AppMenuButtonState();
}

class _AppMenuButtonState extends ConsumerState<AppMenuButton> {
  final _controller = MenuController();

  /// Each submenu's controller and button focus, by its label: the five
  /// sections, `Theme` and `Open Recent`.
  final _submenus = <String, (MenuController, FocusNode)>{
    for (final label in [...AppMenuButton.sections, 'Theme', 'Open Recent'])
      label: (MenuController(), FocusNode(debugLabel: 'app menu: $label')),
  };

  FocusNode get _firstSection => _submenus['File']!.$2;

  /// What had focus when the menu opened: Save acts on that editor, and
  /// focus returns there when the menu closes.
  FocusNode? _target;

  /// Whether Save reaches an editor from [_target].
  var _saveEnabled = false;

  /// The window size when the menu opened, held for the menu while it is
  /// open. A root `MenuAnchor` closes when `MediaQuery.size` changes, and
  /// the zoom rows change it (`UiScale`) while 0.1.6 kept the menu open.
  Size? _frozenSize;

  @override
  void dispose() {
    for (final (_, focus) in _submenus.values) {
      focus.dispose();
    }
    super.dispose();
  }

  /// [rows] of submenu [label], each made to close only that submenu on Esc
  /// and return focus to its button, as 0.1.6's menu did; the framework's
  /// own Esc closes the whole menu. In the top panel Esc still closes it all.
  List<Widget> _rowsOf(String label, List<Widget> rows) {
    final (controller, button) = _submenus[label]!;
    return [
      for (final row in rows)
        Actions(
          actions: {
            DismissIntent: CallbackAction<DismissIntent>(
              onInvoke: (_) {
                controller.close();
                button.requestFocus();
                return null;
              },
            ),
          },
          child: row,
        ),
    ];
  }

  void _toggle() {
    if (_controller.isOpen) {
      _controller.close();
      return;
    }
    final target = FocusManager.instance.primaryFocus;
    setState(() {
      _frozenSize = MediaQuery.sizeOf(context);
      _target = target;
      _saveEnabled = editorCommandEnabled(MenuCommand.save, focus: target);
    });
    _controller.open();
    // As 0.1.6 (ANVL-110), focus moves to the first row on open, so the
    // keyboard drives the menu at once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.isOpen) _firstSection.requestFocus();
    });
  }

  void _onClose() {
    if (mounted) setState(() => _frozenSize = null);
    final target = _target;
    if (target != null && target.context != null && target.canRequestFocus) {
      target.requestFocus();
    }
  }

  bool _enabled(MenuCommand command) =>
      command == MenuCommand.save ? _saveEnabled : commandEnabled(ref, command);

  void _run(MenuCommand command) =>
      unawaited(dispatchCommand(context, ref, command, focus: _target));

  Widget _item(
    List<ShortcutBinding> bindings,
    MenuCommand command,
    String label, {
    IconData? icon,
    bool checked = false,
    bool danger = false,
    Widget? trailing,
  }) {
    final enabled = _enabled(command);
    final colors = context.colors;
    Widget item = MenuItemButton(
      key: ValueKey('menu-${command.id}'),
      leadingIcon: checked
          ? const Icon(Icons.check, size: 18)
          : (icon == null ? null : Icon(icon, size: 18)),
      shortcut: bindingFor(bindings, command)?.activator,
      trailingIcon: trailing,
      closeOnActivate: !keepOpenCommands.contains(command),
      style: danger
          ? MenuItemButton.styleFrom(
              foregroundColor: colors.error,
              iconColor: colors.error,
            )
          : null,
      onPressed: enabled ? () => _run(command) : null,
      child: Text(label),
    );
    if (!enabled) {
      final tooltip = disabledTooltip(ref, command);
      if (tooltip != null) item = Tooltip(message: tooltip, child: item);
    }
    return item;
  }

  Widget _section(String label, List<Widget> rows) => AppMenuRegion(
    child: SubmenuButton(
      key: ValueKey('menu-section-$label'),
      controller: _submenus[label]!.$1,
      focusNode: _submenus[label]!.$2,
      menuChildren: _rowsOf(label, rows),
      child: Text(label),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final bindings = ref.watch(shortcutBindingsProvider);
    final settings = ref.watch(appSettingsProvider);
    final sidebarCollapsed = ref.watch(sidebarCollapsedProvider);
    final counts = ref.watch(recordCountsProvider).value;
    // Read by commandEnabled; watched so the rows follow them.
    ref
      ..watch(projectSessionProvider)
      ..watch(saveLocationPickerProvider);

    Widget item(
      MenuCommand command,
      String label, {
      IconData? icon,
      bool checked = false,
      bool danger = false,
      Widget? trailing,
    }) => _item(
      bindings,
      command,
      label,
      icon: icon,
      checked: checked,
      danger: danger,
      trailing: trailing,
    );

    Widget? countOf(MenuCommand command) {
      final domain = navDomains[command];
      if (domain == null || counts == null) return null;
      final count = domain.countIn(counts);
      if (count <= 0) return null;
      return Text(
        '$count',
        style: ForgeType.code(size: 11, color: context.forge.textTertiary),
      );
    }

    Widget nav(MenuCommand command, String label, IconData icon) =>
        item(command, label, icon: icon, trailing: countOf(command));

    const divider = Divider(height: AnvilSpacing.sm);

    final anchor = MenuAnchor(
      controller: _controller,
      onClose: _onClose,
      menuChildren: [
        _section('File', [
          item(MenuCommand.newProject, 'New Project…', icon: Icons.add),
          item(
            MenuCommand.openProject,
            'Open Project…',
            icon: Icons.folder_open_outlined,
          ),
          _RecentProjectsMenu(
            controller: _submenus['Open Recent']!.$1,
            focusNode: _submenus['Open Recent']!.$2,
            rowsOf: (rows) => _rowsOf('Open Recent', rows),
            onOpen: (path) => unawaited(openRecentProject(ref, path)),
            onClear: () => clearRecentProjects(ref),
          ),
          divider,
          item(MenuCommand.save, 'Save', icon: Icons.save_outlined),
          item(MenuCommand.saveAs, 'Save As…', icon: Icons.save_as_outlined),
          divider,
          item(MenuCommand.closeProject, 'Close Project', icon: Icons.close),
          divider,
          item(
            MenuCommand.appSettings,
            'Application Settings…',
            icon: Icons.settings_outlined,
          ),
          divider,
          item(MenuCommand.exit, 'Exit', icon: Icons.logout, danger: true),
        ]),
        _section('View', [
          item(
            MenuCommand.toggleSidebar,
            'Toggle Sidebar',
            icon: Icons.view_sidebar_outlined,
            checked: !sidebarCollapsed,
          ),
          item(
            MenuCommand.validationPanel,
            'Validation Panel',
            icon: Icons.fact_check_outlined,
          ),
          divider,
          item(MenuCommand.zoomIn, 'Zoom In', icon: Icons.zoom_in),
          item(MenuCommand.zoomOut, 'Zoom Out', icon: Icons.zoom_out),
          item(MenuCommand.zoomReset, 'Reset Zoom', icon: Icons.fit_screen),
          divider,
          SubmenuButton(
            key: const ValueKey('menu-theme-menu'),
            controller: _submenus['Theme']!.$1,
            focusNode: _submenus['Theme']!.$2,
            leadingIcon: const Icon(Icons.palette_outlined, size: 18),
            menuChildren: _rowsOf('Theme', [
              item(
                MenuCommand.themeDark,
                'Dark',
                checked: settings.theme == AppThemeMode.dark,
              ),
              item(
                MenuCommand.themeLight,
                'Light',
                checked: settings.theme == AppThemeMode.light,
              ),
              item(
                MenuCommand.themeCustom,
                'Custom',
                checked: settings.theme == AppThemeMode.custom,
              ),
            ]),
            child: const Text('Theme'),
          ),
        ]),
        _section('Project', [
          item(
            MenuCommand.projectSettings,
            'Project Settings',
            icon: Icons.settings_outlined,
          ),
          item(
            MenuCommand.runValidation,
            'Run Validation',
            icon: Icons.fact_check_outlined,
          ),
          item(
            MenuCommand.customFieldSchemas,
            'Custom Field Schemas',
            icon: Icons.list_alt,
          ),
          divider,
          item(MenuCommand.exportData, 'Export…', icon: Icons.upload),
          item(MenuCommand.importData, 'Import…', icon: Icons.download),
        ]),
        _section('Data', [
          nav(MenuCommand.navDashboard, 'Dashboard', Icons.dashboard_outlined),
          divider,
          for (final MapEntry(key: command, value: domain)
              in navDomains.entries)
            nav(command, domain.label, domain.icon),
        ]),
        _section('Help', [
          item(
            MenuCommand.documentation,
            'Documentation',
            icon: Icons.menu_book_outlined,
          ),
          item(
            MenuCommand.keyboardShortcuts,
            'Keyboard Shortcuts',
            icon: Icons.keyboard_outlined,
          ),
          divider,
          item(
            MenuCommand.reportBug,
            'Report a Bug',
            icon: Icons.bug_report_outlined,
          ),
          item(MenuCommand.about, 'About Anvil', icon: Icons.info_outline),
        ]),
      ],
      builder: (context, controller, _) => AppMenuRegion(
        child: IconButton(
          tooltip: 'Menu',
          isSelected: controller.isOpen,
          icon: const Icon(Icons.menu, size: 20),
          onPressed: _toggle,
        ),
      ),
    );
    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(size: _frozenSize ?? MediaQuery.sizeOf(context)),
      child: anchor,
    );
  }
}

/// File > Open Recent: the recent list, re-read from disk each time the
/// submenu is built (0.1.6 `RecentSubmenu`). Missing files are disabled.
/// The callbacks run on the menu button's `ref`, which outlives this
/// widget once the menu has closed.
class _RecentProjectsMenu extends ConsumerWidget {
  const _RecentProjectsMenu({
    required this.controller,
    required this.focusNode,
    required this.rowsOf,
    required this.onOpen,
    required this.onClear,
  });

  final MenuController controller;
  final FocusNode focusNode;
  final List<Widget> Function(List<Widget> rows) rowsOf;
  final ValueChanged<String> onOpen;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recents = ref.watch(recentProjectsProvider);
    final muted = context.forge.textTertiary;
    return SubmenuButton(
      key: const ValueKey('menu-open-recent'),
      controller: controller,
      focusNode: focusNode,
      leadingIcon: const Icon(Icons.history, size: 18),
      menuChildren: rowsOf([
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AnvilSpacing.md,
            AnvilSpacing.sm,
            AnvilSpacing.md,
            AnvilSpacing.xs,
          ),
          child: Text(
            'RECENT PROJECTS',
            style: context.text.labelSmall?.copyWith(color: muted),
          ),
        ),
        if (recents.isEmpty)
          const MenuItemButton(child: Text('No recent projects')),
        for (final recent in recents)
          MenuItemButton(
            key: ValueKey('menu-recent-${recent.filePath}'),
            leadingIcon: const Icon(Icons.folder_outlined, size: 18),
            trailingIcon: switch (DateTime.tryParse(
              recent.project.lastModifiedAt,
            )) {
              final time? => Text(
                formatRelativeTimestamp(time),
                style: context.text.labelSmall?.copyWith(color: muted),
              ),
              null => null,
            },
            onPressed: recent.exists ? () => onOpen(recent.filePath) : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    recent.project.projectName,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    recent.filePath,
                    overflow: TextOverflow.ellipsis,
                    style: ForgeType.code(size: 10, color: muted),
                  ),
                ],
              ),
            ),
          ),
        if (recents.isNotEmpty) ...[
          const Divider(height: AnvilSpacing.sm),
          MenuItemButton(
            key: const ValueKey('menu-clear-recents'),
            closeOnActivate: false,
            style: MenuItemButton.styleFrom(
              foregroundColor: context.colors.error,
            ),
            onPressed: onClear,
            child: const Text('Clear Recents'),
          ),
        ],
      ]),
      child: const Text('Open Recent'),
    );
  }
}
