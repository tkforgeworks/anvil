import 'package:anvil_core/anvil_core.dart';
import 'package:test/test.dart';

void main() {
  group('AppSettings.normalize', () {
    test('empty map gives the defaults', () {
      final s = AppSettings.normalize({});
      expect(s, const AppSettings());
      expect(s.theme, AppThemeMode.dark);
      expect(s.editingMode, EditingMode.modal);
      expect(s.autoSaveEnabled, isTrue);
      expect(s.autoSaveIntervalMs, 5000);
      expect(s.defaultSaveLocation, isNull);
      expect(s.customThemePath, isNull);
      expect(s.customThemeColors, isNull);
      expect(s.customShortcuts, isNull);
    });

    test('keeps valid values', () {
      final s = AppSettings.normalize({
        'theme': 'custom',
        'editingMode': 'full-page',
        'autoSaveEnabled': false,
        'autoSaveIntervalMs': 12000,
        'defaultSaveLocation': '/home/x/Anvil',
        'customThemePath': '/home/x/t.json',
        'customThemeColors': {'mode': 'light', 'primary': '#112233'},
        'customShortcuts': {'save': 'Ctrl+S'},
      });
      expect(s.theme, AppThemeMode.custom);
      expect(s.editingMode, EditingMode.fullPage);
      expect(s.autoSaveEnabled, isFalse);
      expect(s.autoSaveIntervalMs, 12000);
      expect(s.defaultSaveLocation, '/home/x/Anvil');
      expect(s.customThemePath, '/home/x/t.json');
      expect(s.customThemeColors?.primary, '#112233');
      expect(s.customThemeColors?.mode, 'light');
      expect(s.customShortcuts, {'save': 'Ctrl+S'});
    });

    test('theme: light accepted, unknown or wrong type gives dark', () {
      expect(
        AppSettings.normalize({'theme': 'light'}).theme,
        AppThemeMode.light,
      );
      expect(AppSettings.normalize({'theme': 'neon'}).theme, AppThemeMode.dark);
      expect(AppSettings.normalize({'theme': 3}).theme, AppThemeMode.dark);
    });

    test('editingMode: unknown or wrong type gives modal', () {
      expect(
        AppSettings.normalize({'editingMode': 'tabs'}).editingMode,
        EditingMode.modal,
      );
      expect(
        AppSettings.normalize({'editingMode': true}).editingMode,
        EditingMode.modal,
      );
    });

    test('autoSaveEnabled: non-bool gives true', () {
      expect(
        AppSettings.normalize({'autoSaveEnabled': 'no'}).autoSaveEnabled,
        isTrue,
      );
      expect(
        AppSettings.normalize({'autoSaveEnabled': 0}).autoSaveEnabled,
        isTrue,
      );
    });

    test(
      'autoSaveIntervalMs: floor 1000, truncated, wrong type gives 5000',
      () {
        expect(
          AppSettings.normalize({'autoSaveIntervalMs': 10}).autoSaveIntervalMs,
          1000,
        );
        expect(
          AppSettings.normalize({'autoSaveIntervalMs': -5}).autoSaveIntervalMs,
          1000,
        );
        expect(
          AppSettings.normalize({'autoSaveIntervalMs': 2500.9})
              .autoSaveIntervalMs,
          2500,
        );
        expect(
          AppSettings.normalize({'autoSaveIntervalMs': '9000'})
              .autoSaveIntervalMs,
          5000,
        );
        expect(
          AppSettings.normalize({'autoSaveIntervalMs': double.infinity})
              .autoSaveIntervalMs,
          5000,
        );
      },
    );

    test('string paths: empty or wrong type gives null', () {
      final s = AppSettings.normalize({
        'defaultSaveLocation': '',
        'customThemePath': 5,
      });
      expect(s.defaultSaveLocation, isNull);
      expect(s.customThemePath, isNull);
    });

    test('customThemeColors: bad hex drops that colour only', () {
      final s = AppSettings.normalize({
        'customThemeColors': {
          'primary': '#abcdef',
          'secondary': '#12345',
          'error': '#11223344',
          'warning': 'red',
          'mode': 'sepia',
        },
      });
      expect(s.customThemeColors?.primary, '#abcdef');
      expect(s.customThemeColors?.secondary, isNull);
      expect(s.customThemeColors?.error, '#11223344');
      expect(s.customThemeColors?.warning, isNull);
      expect(s.customThemeColors?.mode, isNull);
    });

    test('customThemeColors: nothing valid, or wrong type, gives null', () {
      expect(
        AppSettings.normalize({
          'customThemeColors': {'primary': 'nope'},
        }).customThemeColors,
        isNull,
      );
      expect(
        AppSettings.normalize({'customThemeColors': 'x'}).customThemeColors,
        isNull,
      );
    });

    test('customShortcuts: drops empty and non-string values', () {
      final s = AppSettings.normalize({
        'customShortcuts': {'a': 'Ctrl+A', 'b': '', 'c': 3},
      });
      expect(s.customShortcuts, {'a': 'Ctrl+A'});
      expect(
        AppSettings.normalize({
          'customShortcuts': {'b': ''},
        }).customShortcuts,
        isNull,
      );
      expect(
        AppSettings.normalize({'customShortcuts': []}).customShortcuts,
        isNull,
      );
    });
  });

  group('AppSettings value semantics', () {
    test('toJson lists the eight keys in 0.1.6 order', () {
      expect(const AppSettings().toJson().keys.toList(), [
        'theme',
        'editingMode',
        'autoSaveEnabled',
        'autoSaveIntervalMs',
        'defaultSaveLocation',
        'customThemePath',
        'customThemeColors',
        'customShortcuts',
      ]);
    });

    test('fromJson(toJson) round-trips, == and hashCode agree', () {
      final a = const AppSettings().copyWith(
        theme: AppThemeMode.light,
        customShortcuts: {'x': 'Y', 'z': 'W'},
        customThemeColors: const CustomThemeColors(primary: '#010203'),
      );
      final b = AppSettings.fromJson(a.toJson());
      expect(b, a);
      expect(b.hashCode, a.hashCode);
      expect(a, isNot(const AppSettings()));
    });

    test('copyWith clears nullable fields only on request', () {
      final a = const AppSettings().copyWith(defaultSaveLocation: '/x');
      expect(a.copyWith(theme: AppThemeMode.light).defaultSaveLocation, '/x');
      expect(
        a.copyWith(clearDefaultSaveLocation: true).defaultSaveLocation,
        isNull,
      );
    });
  });
}
