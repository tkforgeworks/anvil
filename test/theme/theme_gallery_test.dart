import 'dart:io';

import 'package:anvil/app/theme/theme_controller.dart';
import 'package:anvil/main.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'anvil_theme_test.dart' show sampleTheme;

void main() {
  Future<void> pumpGallery(WidgetTester tester, ThemeController c) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AnvilApp(controller: c));
    await tester.pumpAndSettle();
  }

  void expectCoreControls() {
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
    expect(find.byType(FilterChip), findsNWidgets(2));
    expect(find.byType(Switch), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('class-warrior'), findsWidgets);
    expect(find.text('2 errors block export'), findsOneWidget);
    expect(find.text('Export key is already in use'), findsOneWidget);
  }

  testWidgets('renders the core controls in dark', (tester) async {
    await pumpGallery(tester, ThemeController());
    expectCoreControls();
    expect(
      Theme.of(tester.element(find.text('Save'))).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the core controls in light', (tester) async {
    await pumpGallery(tester, ThemeController(const ThemeSelection.light()));
    expectCoreControls();
    expect(
      Theme.of(tester.element(find.text('Save'))).brightness,
      Brightness.light,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the core controls in custom', (tester) async {
    final colors = parseCustomThemeSource(sampleTheme).colors!;
    await pumpGallery(
      tester,
      ThemeController(ThemeSelection.custom(colors: colors, path: '/x.json')),
    );
    expectCoreControls();
    expect(find.text('/x.json'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.text('Save'))).colorScheme.primary,
      const Color(0xFFBB86FC),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the segmented control switches modes', (tester) async {
    final controller = ThemeController();
    await pumpGallery(tester, controller);
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(controller.value.mode, AnvilThemeMode.light);
    expect(
      Theme.of(tester.element(find.text('Save'))).brightness,
      Brightness.light,
    );
  });

  testWidgets('loading an invalid file shows its message', (tester) async {
    final dir = Directory.systemTemp.createTempSync('anvil-gallery');
    addTearDown(() => dir.deleteSync(recursive: true));
    final bad = File('${dir.path}/bad.json')..writeAsStringSync('{"mode": 3}');
    final controller = ThemeController();
    await pumpGallery(tester, controller);

    await tester.enterText(find.byType(TextField).first, bad.path);
    await tester.tap(find.text('Load'));
    await tester.pumpAndSettle();

    expect(
      find.text('"mode" must be "dark" or "light", got "3".'),
      findsOneWidget,
    );
    expect(controller.value.mode, AnvilThemeMode.dark);

    final good = File('${dir.path}/good.json')
      ..writeAsStringSync('{"mode": "light", "primary": "#aa0000"}');
    await tester.enterText(find.byType(TextField).first, good.path);
    await tester.tap(find.text('Load'));
    await tester.pumpAndSettle();

    expect(controller.value.mode, AnvilThemeMode.custom);
    expect(find.text(good.path), findsWidgets);
    expect(find.textContaining('must be'), findsNothing);
  });
}
