import 'dart:io';

import 'package:anvil/app/providers.dart';
import 'package:anvil/app/settings/app_settings_notifier.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_bootstrap_test.dart' show AppHarness;

void main() {
  late AppHarness harness;
  late ProviderContainer container;

  AppSettingsNotifier notifier() =>
      container.read(appSettingsProvider.notifier);
  AppSettings state() => container.read(appSettingsProvider);
  List<String> settingsLogLines() => harness.logLines
      .where((l) => l.contains('App settings updated'))
      .toList();

  setUp(() {
    harness = AppHarness.create(settingsJson: '{"theme":"light"}');
    container = ProviderContainer.test(
      overrides: harness.overrides,
      retry: (_, _) => null,
    );
  });

  test('build reflects the settings read at start-up', () {
    expect(state().theme, AppThemeMode.light);
    expect(state().editingMode, EditingMode.modal);
    expect(settingsLogLines(), isEmpty);
  });

  test('setTheme persists to the file and updates the state', () {
    notifier().setTheme(AppThemeMode.dark);

    expect(state().theme, AppThemeMode.dark);
    expect(harness.settingsFile['theme'], 'dark');
    expect(harness.store.read(), state());
    expect(settingsLogLines(), hasLength(1));
  });

  test('a valid theme file switches to custom with its colours', () {
    final file = File('${harness.directory.path}/theme.json')
      ..writeAsStringSync('{"mode": "dark", "primary": "#ff0000"}');

    expect(notifier().setCustomThemeFile(file.path), isNull);

    expect(state().theme, AppThemeMode.custom);
    expect(state().customThemePath, file.path);
    expect(
      state().customThemeColors,
      const CustomThemeColors(mode: 'dark', primary: '#ff0000'),
    );
    expect(container.read(customThemeErrorProvider), isNull);
    expect(harness.settingsFile['theme'], 'custom');
    expect(harness.settingsFile['customThemeColors'], {
      'mode': 'dark',
      'primary': '#ff0000',
    });
    expect(settingsLogLines(), hasLength(1));
  });

  test('an invalid theme file keeps the state and exposes the message', () {
    final before = state();
    final fileBefore = File(harness.store.filePath).readAsStringSync();
    final file = File('${harness.directory.path}/bad.json')
      ..writeAsStringSync('{"primary": "red"}');

    final message = notifier().setCustomThemeFile(file.path);

    const expected =
        '"primary" must be a hex color (#RRGGBB or #RRGGBBAA), got "red".';
    expect(message, expected);
    expect(container.read(customThemeErrorProvider), expected);
    expect(state(), before);
    expect(File(harness.store.filePath).readAsStringSync(), fileBefore);
    expect(settingsLogLines(), isEmpty);

    // The next theme change clears the message.
    notifier().setTheme(AppThemeMode.dark);
    expect(container.read(customThemeErrorProvider), isNull);
  });

  test('editing mode round-trips through the file', () {
    notifier().setEditingMode(EditingMode.fullPage);
    expect(state().editingMode, EditingMode.fullPage);
    expect(harness.settingsFile['editingMode'], 'full-page');
    expect(harness.store.read().editingMode, EditingMode.fullPage);

    notifier().setEditingMode(EditingMode.modal);
    expect(harness.store.read().editingMode, EditingMode.modal);
    expect(settingsLogLines(), hasLength(2));
  });

  test('the default save location is set and cleared', () {
    notifier().setDefaultSaveLocation('/projects');
    expect(harness.store.read().defaultSaveLocation, '/projects');
    notifier().setDefaultSaveLocation(null);
    expect(state().defaultSaveLocation, isNull);
    expect(harness.settingsFile['defaultSaveLocation'], isNull);
  });

  test('the file is the source of truth for keys this app did not change', () {
    // Another writer (0.1.6, or a second window) changed the file.
    harness.store.write({'editingMode': 'full-page'});
    notifier().setTheme(AppThemeMode.dark);
    expect(state().editingMode, EditingMode.fullPage);
  });
}
