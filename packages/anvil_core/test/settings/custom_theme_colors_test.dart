import 'dart:io';

import 'package:anvil_core/anvil_core.dart';
import 'package:test/test.dart';

/// The sample file the 0.1.x settings dialog offers users to copy.
const sampleTheme = '''{
  "mode": "dark",
  "primary": "#bb86fc",
  "secondary": "#03dac6",
  "backgroundDefault": "#121212",
  "backgroundPaper": "#1e1e1e",
  "textPrimary": "#e0e0e0",
  "textSecondary": "#a0a0a0",
  "error": "#cf6679",
  "warning": "#ffb74d",
  "info": "#64b5f6",
  "success": "#81c784",
  "divider": "#333333"
}''';

const validKeysText =
    'mode, primary, secondary, backgroundDefault, backgroundPaper, '
    'textPrimary, textSecondary, error, warning, info, success, divider';

void main() {
  group('parseCustomThemeSource', () {
    test('accepts the documented sample file with every key', () {
      final result = parseCustomThemeSource(sampleTheme);
      expect(result.success, isTrue);
      expect(result.error, isNull);
      final colors = result.colors!;
      expect(colors.mode, 'dark');
      expect(colors.primary, '#bb86fc');
      expect(colors.divider, '#333333');
      expect(colors.toJson().length, 12);
    });

    test('accepts a partial file and keeps only what it holds', () {
      final result = parseCustomThemeSource('{"primary": "#FF0000"}');
      expect(result.colors, const CustomThemeColors(primary: '#FF0000'));
      expect(result.colors!.mode, isNull);
    });

    test('accepts 8-digit hex with alpha', () {
      final result = parseCustomThemeSource('{"divider": "#ffffff1f"}');
      expect(result.colors!.divider, '#ffffff1f');
    });

    test('rejects malformed JSON with the parser message', () {
      final result = parseCustomThemeSource('{"primary": }');
      expect(result.success, isFalse);
      expect(result.error, startsWith('Invalid JSON: '));
    });

    test('rejects a non-object document', () {
      expect(
        parseCustomThemeSource('"#ffffff"').error,
        'Theme file must contain a JSON object.',
      );
      expect(
        parseCustomThemeSource('42').error,
        'Theme file must contain a JSON object.',
      );
      // `null` is falsy in JS, so 0.1.x gave the object message for it too.
      expect(
        parseCustomThemeSource('null').error,
        'Theme file must contain a JSON object.',
      );
    });

    test('treats an array as an object with no colours, like 0.1.x', () {
      expect(
        parseCustomThemeSource('[]').error,
        'Theme file has no valid color values.',
      );
    });

    test('rejects unknown keys and lists the valid ones', () {
      final result = parseCustomThemeSource(
        '{"primary": "#000000", "accent": "#ffffff", "Mode": "dark"}',
      );
      expect(
        result.error,
        'Unknown keys: accent, Mode. Valid keys: $validKeysText',
      );
    });

    test('rejects an invalid mode and quotes it', () {
      expect(
        parseCustomThemeSource('{"mode": "sepia"}').error,
        '"mode" must be "dark" or "light", got "sepia".',
      );
      expect(
        parseCustomThemeSource('{"mode": 1}').error,
        '"mode" must be "dark" or "light", got "1".',
      );
    });

    test('rejects a non-hex colour and quotes it the way JavaScript does', () {
      expect(
        parseCustomThemeSource('{"primary": "red"}').error,
        '"primary" must be a hex color (#RRGGBB or #RRGGBBAA), got "red".',
      );
      expect(
        parseCustomThemeSource('{"primary": "#fff"}').error,
        '"primary" must be a hex color (#RRGGBB or #RRGGBBAA), got "#fff".',
      );
      expect(
        parseCustomThemeSource('{"error": null}').error,
        '"error" must be a hex color (#RRGGBB or #RRGGBBAA), got "null".',
      );
      expect(
        parseCustomThemeSource('{"info": 255}').error,
        '"info" must be a hex color (#RRGGBB or #RRGGBBAA), got "255".',
      );
      expect(
        parseCustomThemeSource('{"info": 1.0}').error,
        '"info" must be a hex color (#RRGGBB or #RRGGBBAA), got "1".',
      );
      expect(
        parseCustomThemeSource('{"info": true}').error,
        '"info" must be a hex color (#RRGGBB or #RRGGBBAA), got "true".',
      );
      expect(
        parseCustomThemeSource('{"info": {"a": 1}}').error,
        '"info" must be a hex color (#RRGGBB or #RRGGBBAA), '
        'got "[object Object]".',
      );
      expect(
        parseCustomThemeSource('{"info": ["#ffffff", 2]}').error,
        '"info" must be a hex color (#RRGGBB or #RRGGBBAA), got "#ffffff,2".',
      );
    });

    test('stops at the first offending key in file order', () {
      final result = parseCustomThemeSource(
        '{"primary": "nope", "mode": "sepia"}',
      );
      expect(result.error, startsWith('"primary" must be a hex color'));
    });

    test('rejects an empty object', () {
      expect(
        parseCustomThemeSource('{}').error,
        'Theme file has no valid color values.',
      );
    });
  });

  group('parseCustomThemeFile', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('anvil-theme-test');
    });

    tearDown(() {
      dir.deleteSync(recursive: true);
    });

    test('reports a missing file with its path', () {
      final path = '${dir.path}/missing.json';
      expect(parseCustomThemeFile(path).error, 'File not found: $path');
    });

    test('reads a file from disk', () {
      final file = File('${dir.path}/theme.json')
        ..writeAsStringSync(sampleTheme);
      final result = parseCustomThemeFile(file.path);
      expect(result.success, isTrue);
      expect(result.colors!.secondary, '#03dac6');
    });
  });

  group('CustomThemeColors.normalize', () {
    test('keeps valid values and drops the rest', () {
      final colors = CustomThemeColors.normalize({
        'mode': 'light',
        'primary': '#123456',
        'secondary': 'blue',
        'extra': '#ffffff',
      });
      expect(
        colors,
        const CustomThemeColors(mode: 'light', primary: '#123456'),
      );
    });

    test('returns null when nothing valid remains', () {
      expect(CustomThemeColors.normalize({'mode': 'sepia'}), isNull);
      expect(CustomThemeColors.normalize('x'), isNull);
      expect(CustomThemeColors.normalize(null), isNull);
    });
  });

  test('toJson round-trips through parse', () {
    final colors = parseCustomThemeSource(sampleTheme).colors!;
    expect(CustomThemeColors.normalize(colors.toJson()), colors);
  });
}
