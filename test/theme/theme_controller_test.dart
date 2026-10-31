import 'dart:io';

import 'package:anvil/app/theme/anvil_theme.dart';
import 'package:anvil/app/theme/theme_controller.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('anvil-theme-controller');
  });

  tearDown(() {
    dir.deleteSync(recursive: true);
  });

  test('starts dark and switches to light', () {
    final controller = ThemeController();
    expect(controller.value.mode, AnvilThemeMode.dark);
    expect(controller.value.spec, AnvilThemeSpec.dark);
    controller.selectLight();
    expect(controller.value.spec, AnvilThemeSpec.light);
  });

  test('custom cannot be selected before a file has loaded', () {
    final controller = ThemeController();
    controller.selectCustom();
    expect(controller.value.mode, AnvilThemeMode.dark);
  });

  test('loading a valid file applies it and records the path', () {
    final file = File('${dir.path}/theme.json')
      ..writeAsStringSync('{"mode": "light", "primary": "#ff0000"}');
    final controller = ThemeController();
    var notified = 0;
    controller.addListener(() => notified++);

    expect(controller.loadCustomFile(file.path), isNull);
    expect(notified, 1);
    final s = controller.value;
    expect(s.mode, AnvilThemeMode.custom);
    expect(s.customPath, file.path);
    expect(
      s.customColors,
      const CustomThemeColors(mode: 'light', primary: '#ff0000'),
    );
    expect(s.customError, isNull);
    expect(s.spec.brightness, Brightness.light);
    expect(s.spec.primary, const Color(0xFFFF0000));
  });

  test('a failed load keeps the theme and reports the message', () {
    final file = File('${dir.path}/bad.json')
      ..writeAsStringSync('{"primary": "red"}');
    final controller = ThemeController();
    controller.selectLight();

    final error = controller.loadCustomFile(file.path);
    expect(
      error,
      '"primary" must be a hex color (#RRGGBB or #RRGGBBAA), got "red".',
    );
    expect(controller.value.mode, AnvilThemeMode.light);
    expect(controller.value.customError, error);
    expect(controller.value.customColors, isNull);

    final missing = controller.loadCustomFile('${dir.path}/nope.json');
    expect(missing, 'File not found: ${dir.path}/nope.json');
  });

  test('switching mode clears the error but keeps the loaded colours', () {
    final good = File('${dir.path}/good.json')
      ..writeAsStringSync('{"primary": "#00ff00"}');
    final controller = ThemeController()
      ..loadCustomFile(good.path)
      ..loadCustomFile('${dir.path}/missing.json');
    expect(controller.value.customError, isNotNull);
    expect(controller.value.mode, AnvilThemeMode.custom);

    controller.selectDark();
    expect(controller.value.customError, isNull);
    expect(controller.value.customColors, isNotNull);

    controller.selectCustom();
    expect(controller.value.mode, AnvilThemeMode.custom);
    expect(controller.value.spec.primary, const Color(0xFF00FF00));
  });

  test('custom without colours resolves to dark', () {
    expect(
      ThemeSelection.custom(colors: const CustomThemeColors(mode: 'light'))
          .spec,
      AnvilThemeSpec.light,
    );
  });
}
