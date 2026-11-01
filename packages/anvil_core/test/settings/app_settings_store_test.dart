import 'dart:convert';
import 'dart:io';

import 'package:anvil_core/anvil_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

// app-settings.json exactly as 0.1.6's JSON.stringify(settings, null, 2).
const _electronFile = '''{
  "theme": "custom",
  "editingMode": "full-page",
  "autoSaveEnabled": false,
  "autoSaveIntervalMs": 8000,
  "defaultSaveLocation": "/home/u/Anvil Projects",
  "customThemePath": "/home/u/theme.json",
  "customThemeColors": {
    "mode": "light",
    "primary": "#336699",
    "divider": "#00000080"
  },
  "customShortcuts": {
    "save": "Ctrl+S",
    "export": "Ctrl+E"
  }
}''';

void main() {
  late Directory tmp;
  late String path;
  late AppSettingsStore store;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('anvil_settings_');
    path = p.join(tmp.path, 'sub', AppSettingsStore.fileName);
    store = AppSettingsStore(filePath: path);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('missing file reads as defaults', () {
    expect(store.read(), const AppSettings());
  });

  test('unparsable or non-object file reads as defaults', () {
    Directory(p.dirname(path)).createSync(recursive: true);
    File(path).writeAsStringSync('{not json');
    expect(store.read(), const AppSettings());
    File(path).writeAsStringSync('[1,2]');
    expect(store.read(), const AppSettings());
  });

  test('a 0.1.6 file reads, and read then write is byte-identical', () {
    Directory(p.dirname(path)).createSync(recursive: true);
    File(path).writeAsStringSync(_electronFile);
    final s = store.read();
    expect(s.theme, AppThemeMode.custom);
    expect(s.autoSaveIntervalMs, 8000);
    expect(s.customThemeColors?.divider, '#00000080');
    store.update((c) => c);
    expect(File(path).readAsStringSync(), _electronFile);
    store.write({});
    expect(File(path).readAsStringSync(), _electronFile);
  });

  test('defaults serialise with the eight keys and nulls, 2-space indent', () {
    store.write({});
    expect(File(path).readAsStringSync(), '''{
  "theme": "dark",
  "editingMode": "modal",
  "autoSaveEnabled": true,
  "autoSaveIntervalMs": 5000,
  "defaultSaveLocation": null,
  "customThemePath": null,
  "customThemeColors": null,
  "customShortcuts": null
}''');
  });

  test('partial write keeps the other keys', () {
    Directory(p.dirname(path)).createSync(recursive: true);
    File(path).writeAsStringSync(_electronFile);
    final s = store.write({'theme': 'light'});
    expect(s.theme, AppThemeMode.light);
    expect(s.defaultSaveLocation, '/home/u/Anvil Projects');
    expect(s.customShortcuts?['save'], 'Ctrl+S');
    final onDisk = jsonDecode(File(path).readAsStringSync()) as Map;
    expect(onDisk['theme'], 'light');
    expect(onDisk['editingMode'], 'full-page');
  });

  test('a null value in a partial clears the key', () {
    Directory(p.dirname(path)).createSync(recursive: true);
    File(path).writeAsStringSync(_electronFile);
    final s = store.write({'defaultSaveLocation': null});
    expect(s.defaultSaveLocation, isNull);
    expect(store.read().defaultSaveLocation, isNull);
  });

  test('write normalises invalid input and creates the directory', () {
    final s = store.write({'theme': 'neon', 'autoSaveIntervalMs': 1});
    expect(s.theme, AppThemeMode.dark);
    expect(s.autoSaveIntervalMs, 1000);
    expect(File(path).existsSync(), isTrue);
  });

  test('update applies a change over the current file', () {
    store.write({'theme': 'light'});
    final s = store.update(
      (c) => c.copyWith(editingMode: EditingMode.fullPage),
    );
    expect(s.theme, AppThemeMode.light);
    expect(store.read().editingMode, EditingMode.fullPage);
  });
}
