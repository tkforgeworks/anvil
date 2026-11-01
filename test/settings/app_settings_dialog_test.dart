import 'dart:io';

import 'package:anvil/app/dialogs/file_dialogs.dart';
import 'package:anvil/app/menu/menu_commands.dart';
import 'package:anvil/app/menu/shortcut_registry.dart';
import 'package:anvil/app/providers.dart';
import 'package:anvil/app/settings/app_settings_dialog.dart';
import 'package:anvil/app/theme/theme_selection.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_bootstrap_test.dart' show AppHarness;
import '../dialogs/fakes.dart' show FakeFileDialogs;

final linux = TargetPlatformVariant.only(TargetPlatform.linux);

void main() {
  late AppHarness harness;
  late FakeFileDialogs dialogs;
  late ProviderContainer container;

  void setUpWith({String? settingsJson}) {
    harness = AppHarness.create(settingsJson: settingsJson);
    dialogs = FakeFileDialogs();
    container = ProviderContainer.test(
      overrides: [
        ...harness.overrides,
        fileDialogsProvider.overrideWithValue(dialogs),
      ],
      retry: (_, _) => null,
    );
  }

  AppSettings settings() => container.read(appSettingsProvider);
  Finder key(String k) => find.byKey(ValueKey(k));
  final dialog = find.byType(AppSettingsDialog);

  /// Pumps an app themed by [themeDataProvider] with an Open button that
  /// shows the dialog through [showAppSettingsDialog], and opens it.
  Future<void> open(WidgetTester tester, {String? tab}) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: ref.watch(themeDataProvider),
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () => showAppSettingsDialog(context, ref),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    if (tab != null) await showTab(tester, tab);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  String themeFile(String name, String json) {
    final file = File('${harness.directory.path}/$name')
      ..writeAsStringSync(json);
    return file.path;
  }

  /// Presses [key] with the given modifiers held.
  Future<void> chord(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool control = false,
    bool shift = false,
    bool alt = false,
  }) async {
    final modifiers = [
      if (control) LogicalKeyboardKey.controlLeft,
      if (shift) LogicalKeyboardKey.shiftLeft,
      if (alt) LogicalKeyboardKey.altLeft,
    ];
    for (final m in modifiers) {
      await tester.sendKeyDownEvent(m);
    }
    await tester.sendKeyDownEvent(key);
    await tester.sendKeyUpEvent(key);
    for (final m in modifiers.reversed) {
      await tester.sendKeyUpEvent(m);
    }
    await tester.pumpAndSettle();
  }

  Future<void> capture(
    WidgetTester tester,
    String id,
    LogicalKeyboardKey pressed, {
    bool control = true,
    bool shift = false,
    bool alt = false,
  }) async {
    await tap(tester, key('shortcut-binding-$id'));
    expect(
      find.descendant(
        of: key('shortcut-binding-$id'),
        matching: find.text('Press keys…'),
      ),
      findsOneWidget,
    );
    await chord(tester, pressed, control: control, shift: shift, alt: alt);
  }

  String bindingText(WidgetTester tester, String id) => tester
      .widget<Text>(
        find.descendant(
          of: key('shortcut-binding-$id'),
          matching: find.byType(Text),
        ),
      )
      .data!;

  group('tabs', () {
    setUp(() => setUpWith());

    testWidgets('the four 0.1.6 tabs render with no auto-save control', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('Application Settings'), findsOneWidget);
      for (final label in ['General', 'Appearance', 'Editor', 'Shortcuts']) {
        expect(find.widgetWithText(Tab, label), findsOneWidget);
      }

      // General opens first.
      expect(find.text('Default Save Location'), findsOneWidget);
      expect(find.text('Not set — uses system default'), findsOneWidget);
      expect(find.text('Clear'), findsNothing);

      final expected = {
        'Appearance': 'UI Theme',
        'Editor': 'Preferred Editing Mode',
        // "Keyboard Shortcuts" is also a registry row's label.
        'Shortcuts': 'Click a binding to re-assign it. Press Escape to cancel.',
      };
      for (final MapEntry(key: tab, value: heading) in expected.entries) {
        await showTab(tester, tab);
        expect(find.text(heading), findsOneWidget, reason: tab);
        expect(find.textContaining('uto-save'), findsNothing);
        expect(find.byType(Switch), findsNothing);
      }
      await showTab(tester, 'General');
      expect(find.textContaining('uto-save'), findsNothing);
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(TextField), findsNothing);
    }, variant: linux);

    testWidgets('the close button and Escape close it', (tester) async {
      await open(tester);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
    }, variant: linux);
  });

  group('General and Editor', () {
    setUp(() => setUpWith());

    testWidgets('the default save location is browsed for and cleared', (
      tester,
    ) async {
      await open(tester);
      dialogs.directory = '/home/test/Worlds';
      await tap(tester, key('settings-browse-folder'));

      expect(dialogs.requests, ['directory from null']);
      expect(harness.settingsFile['defaultSaveLocation'], '/home/test/Worlds');
      expect(find.text('/home/test/Worlds'), findsOneWidget);

      // Browsing again starts at the stored folder; cancelling keeps it.
      dialogs.directory = null;
      await tap(tester, key('settings-browse-folder'));
      expect(dialogs.requests.last, 'directory from /home/test/Worlds');
      expect(settings().defaultSaveLocation, '/home/test/Worlds');

      await tap(tester, key('settings-clear-folder'));
      expect(harness.settingsFile['defaultSaveLocation'], isNull);
      expect(settings().defaultSaveLocation, isNull);
      expect(find.text('Not set — uses system default'), findsOneWidget);
    }, variant: linux);

    testWidgets('the editing mode round-trips through the store', (
      tester,
    ) async {
      await open(tester, tab: 'Editor');
      expect(
        find.text(
          'Opens the editor in a dialog overlay on top of the list '
          'view.',
        ),
        findsOneWidget,
      );
      await tap(tester, key('settings-editing-full-page'));
      expect(harness.settingsFile['editingMode'], 'full-page');
      expect(harness.store.read().editingMode, EditingMode.fullPage);

      await tap(tester, key('settings-editing-modal'));
      expect(harness.settingsFile['editingMode'], 'modal');
      expect(settings().editingMode, EditingMode.modal);
    }, variant: linux);
  });

  group('Appearance', () {
    setUp(() => setUpWith());

    testWidgets('a theme change writes the store and changes the app theme', (
      tester,
    ) async {
      await open(tester, tab: 'Appearance');
      expect(container.read(themeDataProvider).brightness, Brightness.dark);
      expect(key('settings-theme-file'), findsNothing);

      await tap(tester, key('settings-theme-light'));

      expect(harness.settingsFile['theme'], 'light');
      expect(container.read(themeDataProvider).brightness, Brightness.light);
      expect(Theme.of(tester.element(dialog)).brightness, Brightness.light);
    }, variant: linux);

    testWidgets('a theme file is applied; a rejected one shows the parser '
        'message and keeps the theme', (tester) async {
      await open(tester, tab: 'Appearance');

      // Custom with no file shows dark and offers the picker, as 0.1.6 did.
      await tap(tester, key('settings-theme-custom'));
      expect(settings().theme, AppThemeMode.custom);
      expect(container.read(themeDataProvider).brightness, Brightness.dark);
      expect(find.text('Select Theme File'), findsOneWidget);
      expect(find.text('Theme file reference & sample'), findsOneWidget);

      final good = themeFile('good.json', '{"mode": "light"}');
      dialogs.themeFile = good;
      await tap(tester, key('settings-theme-file'));

      expect(dialogs.requests, ['theme file from null']);
      expect(harness.settingsFile['customThemePath'], good);
      expect(harness.settingsFile['customThemeColors'], {'mode': 'light'});
      expect(container.read(themeDataProvider).brightness, Brightness.light);
      expect(find.text('Change Theme File'), findsOneWidget);
      expect(find.text(good), findsOneWidget);

      final before = harness.store.read();
      final theme = container.read(themeDataProvider);
      dialogs.themeFile = themeFile('bad.json', '{"primary": "red"}');
      await tap(tester, key('settings-theme-file'));

      const message =
          '"primary" must be a hex color (#RRGGBB or #RRGGBBAA), got "red".';
      expect(
        find.descendant(
          of: key('settings-theme-error'),
          matching: find.text(message),
        ),
        findsOneWidget,
      );
      expect(harness.store.read(), before);
      expect(settings(), before);
      expect(container.read(themeDataProvider), same(theme));
      expect(find.text(good), findsOneWidget);

      // Reopening the dialog clears the old message, as 0.1.6 did.
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await showTab(tester, 'Appearance');
      expect(key('settings-theme-error'), findsNothing);
    }, variant: linux);

    testWidgets('a cancelled theme file pick changes nothing', (tester) async {
      await open(tester, tab: 'Appearance');
      await tap(tester, key('settings-theme-custom'));
      final before = harness.store.read();
      await tap(tester, key('settings-theme-file'));
      expect(harness.store.read(), before);
      expect(key('settings-theme-error'), findsNothing);
    }, variant: linux);
  });

  group('Shortcuts', () {
    setUp(() => setUpWith());

    testWidgets('lists the registry by group with the binding in effect', (
      tester,
    ) async {
      await open(tester, tab: 'Shortcuts');
      expect(
        find.text('Click a binding to re-assign it. Press Escape to cancel.'),
        findsOneWidget,
      );
      for (final group in ShortcutGroup.values) {
        expect(find.text(group.label.toUpperCase()), findsOneWidget);
      }
      for (final entry in shortcutRegistry) {
        expect(key('shortcut-row-${entry.id}'), findsOneWidget);
      }
      expect(bindingText(tester, 'export'), 'Ctrl+E');
      expect(key('shortcuts-reset-all'), findsNothing);
      expect(find.byTooltip('Reset to Ctrl+E'), findsNothing);
    }, variant: linux);

    testWidgets('a captured shortcut is stored and takes effect at once', (
      tester,
    ) async {
      await open(tester, tab: 'Shortcuts');
      await capture(tester, 'export', LogicalKeyboardKey.keyE, shift: true);

      expect(harness.settingsFile['customShortcuts'], {
        'export': 'Ctrl+Shift+E',
      });
      expect(bindingText(tester, 'export'), 'Ctrl+Shift+E');
      expect(find.byTooltip('Reset to Ctrl+E'), findsOneWidget);
      expect(key('shortcuts-reset-all'), findsOneWidget);
      final effective = bindingFor(
        container.read(shortcutBindingsProvider),
        MenuCommand.exportData,
      )!;
      expect(effective.binding, 'Ctrl+Shift+E');
      expect(dialog, findsOneWidget);
    }, variant: linux);

    testWidgets('a duplicate or unmodified key is refused with the message', (
      tester,
    ) async {
      await open(tester, tab: 'Shortcuts');
      await capture(tester, 'export', LogicalKeyboardKey.keyB);
      expect(
        find.descendant(
          of: key('shortcut-capture-error'),
          matching: find.text('Conflicts with "Toggle Sidebar"'),
        ),
        findsOneWidget,
      );
      expect(harness.store.read().customShortcuts, isNull);
      // Still capturing: the next press is taken.
      expect(bindingText(tester, 'export'), 'Press keys…');

      await chord(tester, LogicalKeyboardKey.keyK);
      expect(
        find.text('Shortcut must include Ctrl, Shift, or Alt'),
        findsOneWidget,
      );
      expect(harness.store.read().customShortcuts, isNull);

      // Escape cancels the capture and leaves the dialog open.
      await chord(tester, LogicalKeyboardKey.escape);
      expect(dialog, findsOneWidget);
      expect(bindingText(tester, 'export'), 'Ctrl+E');
      expect(key('shortcut-capture-error'), findsNothing);
      expect(harness.store.read().customShortcuts, isNull);

      // Not capturing, Escape closes the dialog again.
      await chord(tester, LogicalKeyboardKey.escape);
      expect(dialog, findsNothing);
    }, variant: linux);

    testWidgets('the row reset and a capture of the default remove the '
        'override; Reset All clears every one to null', (tester) async {
      await open(tester, tab: 'Shortcuts');
      await capture(tester, 'export', LogicalKeyboardKey.keyE, shift: true);
      await capture(tester, 'save', LogicalKeyboardKey.keyS, alt: true);
      expect(harness.settingsFile['customShortcuts'], {
        'export': 'Ctrl+Shift+E',
        'save': 'Ctrl+Alt+S',
      });

      await tap(tester, key('shortcut-reset-save'));
      expect(harness.settingsFile['customShortcuts'], {
        'export': 'Ctrl+Shift+E',
      });
      expect(bindingText(tester, 'save'), 'Ctrl+S');

      // Capturing the default again removes the override.
      await capture(tester, 'export', LogicalKeyboardKey.keyE);
      expect(harness.settingsFile['customShortcuts'], isNull);
      expect(key('shortcuts-reset-all'), findsNothing);

      await capture(tester, 'export', LogicalKeyboardKey.keyE, shift: true);
      await capture(tester, 'zoom-in', LogicalKeyboardKey.equal, alt: true);
      await tap(tester, key('shortcuts-reset-all'));
      expect(harness.settingsFile['customShortcuts'], isNull);
      expect(settings().customShortcuts, isNull);
      expect(bindingText(tester, 'export'), 'Ctrl+E');
      expect(bindingText(tester, 'zoom-in'), 'Ctrl+=');
      expect(key('shortcuts-reset-all'), findsNothing);
    }, variant: linux);
  });
}

/// Selects the dialog tab [label].
Future<void> showTab(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(Tab, label));
  await tester.pumpAndSettle();
}
