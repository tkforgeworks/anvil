import 'dart:io';

import 'package:anvil/app/menu/menu_commands.dart';
import 'package:anvil/app/menu/ui_scale.dart';
import 'package:anvil/app/providers.dart';
import 'package:anvil/app/settings/app_settings_dialog.dart';
import 'package:anvil/app/settings/project/project_settings_dialog.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil/app/welcome/create_project_dialog.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../dialogs/fakes.dart';
import 'menu_harness.dart';

/// The 0.1.6 `MENU_DATA` rows per section, dividers left out.
const sectionRows = {
  'File': [
    'New Project…',
    'Open Project…',
    'Open Recent',
    'Save',
    'Save As…',
    'Close Project',
    'Application Settings…',
    'Exit',
  ],
  'View': [
    'Toggle Sidebar',
    'Validation Panel',
    'Zoom In',
    'Zoom Out',
    'Reset Zoom',
    'Theme',
  ],
  'Project': [
    'Project Settings',
    'Run Validation',
    'Custom Field Schemas',
    'Export…',
    'Import…',
  ],
  'Data': [
    'Dashboard',
    'Classes',
    'Abilities',
    'Items',
    'Recipes',
    'NPCs',
    'Loot Tables',
  ],
  'Help': [
    'Documentation',
    'Keyboard Shortcuts',
    'Report a Bug',
    'About Anvil',
  ],
};

void main() {
  testWidgets('the menu shows the five 0.1.6 sections and every row', (
    tester,
  ) async {
    await MenuHarness.pump(tester);
    await openMenu(tester);
    for (final section in sectionRows.keys) {
      expect(find.text(section), findsOneWidget);
    }

    for (final MapEntry(key: section, value: rows) in sectionRows.entries) {
      await showSection(tester, section);
      for (final label in rows) {
        expect(
          find
              .descendant(
                of: find.byWidgetPredicate(
                  (w) => w is MenuItemButton || w is SubmenuButton,
                ),
                matching: find.text(label),
              )
              .hitTestable(),
          findsOneWidget,
          reason: '$section > $label',
        );
      }
    }

    // The two nested submenus.
    await showSection(tester, 'View');
    await tester.tap(find.byKey(const ValueKey('menu-theme-menu')));
    await tester.pumpAndSettle();
    for (final label in ['Dark', 'Light', 'Custom']) {
      expect(find.text(label).hitTestable(), findsOneWidget);
    }
    await showSection(tester, 'File');
    await tester.tap(find.byKey(const ValueKey('menu-open-recent')));
    await tester.pumpAndSettle();
    expect(find.text('RECENT PROJECTS'), findsOneWidget);
  }, variant: linux);

  testWidgets('rows show the binding in effect; rows with no 0.2.0 target '
      'are disabled with a tooltip', (tester) async {
    await MenuHarness.pump(
      tester,
      settingsJson: '{"customShortcuts": {"export": "Ctrl+Shift+E"}}',
    );
    await openSection(tester, 'File');
    expect(
      rowWidget(tester, MenuCommand.newProject).shortcut,
      isA<SingleActivator>()
          .having((a) => a.trigger, 'trigger', LogicalKeyboardKey.keyN)
          .having((a) => a.control, 'control', isTrue),
    );
    // No save dialog is wired yet.
    expect(rowWidget(tester, MenuCommand.saveAs).onPressed, isNull);
    expect(
      find.ancestor(
        of: row(MenuCommand.saveAs),
        matching: find.byType(Tooltip),
      ),
      findsOneWidget,
    );

    await showSection(tester, 'Project');
    expect(
      rowWidget(tester, MenuCommand.exportData).shortcut,
      isA<SingleActivator>()
          .having((a) => a.trigger, 'trigger', LogicalKeyboardKey.keyE)
          .having((a) => a.shift, 'shift', isTrue),
    );
    expect(rowWidget(tester, MenuCommand.importData).onPressed, isNull);
    final tooltip = tester.widget<Tooltip>(
      find.ancestor(
        of: row(MenuCommand.importData),
        matching: find.byType(Tooltip),
      ),
    );
    expect(tooltip.message, 'Coming soon');
  }, variant: linux);

  testWidgets('Esc closes the open submenu first, then the panel', (
    tester,
  ) async {
    await MenuHarness.pump(tester);
    await openMenu(tester);
    // Focus is on File; ArrowRight opens it and enters it.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('New Project…'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('New Project…'), findsNothing);
    expect(find.text('Help'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Help'), findsNothing);
    // Focus is back where it was before the menu opened.
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'editor');
  }, variant: linux);

  testWidgets('Esc in a nested submenu closes only that level', (tester) async {
    await MenuHarness.pump(tester);
    await openSection(tester, 'View');
    await tester.tap(find.byKey(const ValueKey('menu-theme-menu')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('Dark'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Dark'), findsNothing);
    expect(row(MenuCommand.zoomIn), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(row(MenuCommand.zoomIn), findsNothing);
    expect(find.text('Help'), findsOneWidget);
  }, variant: linux);

  testWidgets('a KEEP_OPEN row leaves the menu open; other rows close it', (
    tester,
  ) async {
    final harness = await MenuHarness.pump(tester);
    await openSection(tester, 'View');

    await tester.tap(row(MenuCommand.zoomIn));
    await tester.pumpAndSettle();
    expect(harness.container!.read(uiScaleProvider), greaterThan(1));
    expect(row(MenuCommand.zoomOut).hitTestable(), findsOneWidget);

    await tester.tap(row(MenuCommand.zoomReset));
    await tester.pumpAndSettle();
    expect(harness.container!.read(uiScaleProvider), 1);

    await tester.tap(row(MenuCommand.toggleSidebar));
    await tester.pumpAndSettle();
    expect(harness.container!.read(sidebarCollapsedProvider), isTrue);
    expect(row(MenuCommand.toggleSidebar), findsOneWidget);

    await tester.tap(row(MenuCommand.validationPanel));
    await tester.pumpAndSettle();
    expect(row(MenuCommand.zoomIn), findsNothing);
    expect(find.text('Help'), findsNothing);
    expect(harness.location, '/validation');
  }, variant: linux);

  testWidgets('Data rows navigate and show record counts', (tester) async {
    final harness = await MenuHarness.pump(tester, initialLocation: '/plain');
    await openSection(tester, 'Data');
    final counts = harness.container!.read(recordCountsProvider).value!;
    expect(
      find.descendant(
        of: row(MenuCommand.navItems),
        matching: find.text('${counts.items}'),
      ),
      findsOneWidget,
    );
    await tester.tap(row(MenuCommand.navItems));
    await tester.pumpAndSettle();
    expect(harness.location, '/items');
    expect(find.text('At /items'), findsOneWidget);
  }, variant: linux);

  testWidgets('the theme submenu switches and checks the theme', (
    tester,
  ) async {
    final harness = await MenuHarness.pump(tester);
    await openSection(tester, 'View');
    await tester.tap(find.byKey(const ValueKey('menu-theme-menu')));
    await tester.pumpAndSettle();
    // Custom needs a theme file.
    expect(rowWidget(tester, MenuCommand.themeCustom).onPressed, isNull);
    await tester.tap(row(MenuCommand.themeLight));
    await tester.pumpAndSettle();
    expect(
      harness.container!.read(appSettingsProvider).theme,
      AppThemeMode.light,
    );
    expect(
      find.descendant(
        of: row(MenuCommand.themeLight),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
  }, variant: linux);

  testWidgets('File: recents open and clear; New Project opens the create '
      'dialog; Close Project closes; Exit asks the platform to quit', (
    tester,
  ) async {
    final harness = await MenuHarness.pump(tester);
    harness.service.recents = [
      recentEntry(name: 'Older', path: '/nowhere/older.anvil'),
      recentEntry(name: 'Gone', path: '/nowhere/gone.anvil', exists: false),
    ];
    await openSection(tester, 'File');
    await tester.tap(find.byKey(const ValueKey('menu-open-recent')));
    await tester.pumpAndSettle();
    expect(find.text('Older'), findsOneWidget);
    final gone = tester.widget<MenuItemButton>(
      find.byKey(const ValueKey('menu-recent-/nowhere/gone.anvil')),
    );
    expect(gone.onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('menu-clear-recents')));
    await tester.pumpAndSettle();
    expect(harness.service.calls, contains('clearRecents'));
    expect(find.text('No recent projects'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await openSection(tester, 'File');
    await tester.tap(row(MenuCommand.newProject));
    await tester.pumpAndSettle();
    expect(find.byType(CreateProjectDialog), findsOneWidget);
    Navigator.of(tester.element(find.byType(CreateProjectDialog))).pop();
    await tester.pumpAndSettle();

    await openSection(tester, 'File');
    await tester.tap(row(MenuCommand.exit));
    await tester.pumpAndSettle();
    expect(harness.exitRequests, 1);

    await openSection(tester, 'File');
    await tester.tap(row(MenuCommand.closeProject));
    await pumpUntil(
      tester,
      () => harness.container!.read(projectSessionProvider) == null,
    );
  }, variant: linux);

  testWidgets('Save As writes a copy through the save dialog and opens it', (
    tester,
  ) async {
    final target = Directory.systemTemp.createTempSync('anvil-save-as');
    addTearDown(() => target.deleteSync(recursive: true));
    String? suggested;
    final harness = await MenuHarness.pump(
      tester,
      overrides: [
        saveLocationPickerProvider.overrideWithValue(({
          required suggestedPath,
        }) async {
          suggested = suggestedPath;
          return '${target.path}/copy';
        }),
      ],
    );
    final original = harness.container!.read(projectSessionProvider)!.filePath;
    await openSection(tester, 'File');
    await tester.tap(row(MenuCommand.saveAs));
    await pumpUntil(
      tester,
      () =>
          harness.container!.read(projectSessionProvider)?.filePath != original,
    );
    expect(suggested, original);
    final copy = harness.container!.read(projectSessionProvider)!;
    expect(copy.filePath, '${target.path}/copy.anvil');
    expect(File(copy.filePath).existsSync(), isTrue);
  }, variant: linux);

  testWidgets('the settings rows open the real dialogs; Help links', (
    tester,
  ) async {
    final harness = await MenuHarness.pump(tester);
    int tabIndex() =>
        DefaultTabController.of(tester.element(find.byType(TabBar))).index;
    Future<void> close() async {
      await tester.tap(find.byTooltip('Close').last);
      await tester.pumpAndSettle();
    }

    await openSection(tester, 'File');
    await tester.tap(row(MenuCommand.appSettings));
    await tester.pumpAndSettle();
    expect(find.byType(AppSettingsDialog), findsOneWidget);
    await close();
    expect(find.byType(AppSettingsDialog), findsNothing);

    await openSection(tester, 'Project');
    await tester.tap(row(MenuCommand.projectSettings));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectSettingsDialog), findsOneWidget);
    expect(tabIndex(), ProjectSettingsTab.general.index);
    await close();

    await openSection(tester, 'Project');
    await tester.tap(row(MenuCommand.customFieldSchemas));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectSettingsDialog), findsOneWidget);
    expect(tabIndex(), ProjectSettingsTab.customFields.index);
    await close();
    expect(find.byType(ProjectSettingsDialog), findsNothing);

    await openSection(tester, 'Help');
    await tester.tap(row(MenuCommand.documentation));
    await tester.pumpAndSettle();
    await openSection(tester, 'Help');
    await tester.tap(row(MenuCommand.reportBug));
    await tester.pumpAndSettle();
    expect(harness.launched, [
      Uri.parse('https://anvil.tkforgeworks.com/docs'),
      Uri.parse('https://anvil.tkforgeworks.com/bugs'),
    ]);
  }, variant: linux);

  testWidgets('a shortcut captured in Application Settings applies to the '
      'menu and the keyboard without a restart', (tester) async {
    final harness = await MenuHarness.pump(tester);
    await openSection(tester, 'File');
    await tester.tap(row(MenuCommand.appSettings));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Shortcuts'));
    await tester.pumpAndSettle();
    final binding = find.byKey(
      const ValueKey('shortcut-binding-toggle-sidebar'),
    );
    await tester.ensureVisible(binding);
    await tester.pumpAndSettle();
    await tester.tap(binding);
    await tester.pumpAndSettle();
    await ctrl(tester, LogicalKeyboardKey.keyB, shift: true);
    expect(harness.app.settingsFile['customShortcuts'], {
      'toggle-sidebar': 'Ctrl+Shift+B',
    });
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    await openSection(tester, 'View');
    expect(
      rowWidget(tester, MenuCommand.toggleSidebar).shortcut,
      isA<SingleActivator>()
          .having((a) => a.trigger, 'trigger', LogicalKeyboardKey.keyB)
          .having((a) => a.shift, 'shift', isTrue),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    final collapsed = harness.container!.read(sidebarCollapsedProvider);
    await ctrl(tester, LogicalKeyboardKey.keyB, shift: true);
    expect(harness.container!.read(sidebarCollapsedProvider), !collapsed);
  }, variant: linux);
}
