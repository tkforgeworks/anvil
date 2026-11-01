import 'dart:convert';
import 'dart:io';

import 'package:anvil/app/theme/theme_gallery_page.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_bootstrap_test.dart' show AppHarness;
import 'anvil_theme_test.dart' show sampleTheme;

void main() {
  /// Pumps the app over [settings] and opens the gallery from the
  /// debug-build home page.
  Future<AppHarness> pumpGallery(
    WidgetTester tester, {
    String? settings,
  }) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final harness = AppHarness.create(settingsJson: settings);
    await tester.pumpWidget(harness.app());
    await tester.tap(find.text('Open theme gallery'));
    await tester.pumpAndSettle();
    expect(find.byType(ThemeGalleryPage), findsOneWidget);
    return harness;
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
    await pumpGallery(tester);
    expectCoreControls();
    expect(
      Theme.of(tester.element(find.text('Save'))).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the core controls in light', (tester) async {
    await pumpGallery(tester, settings: '{"theme":"light"}');
    expectCoreControls();
    expect(
      Theme.of(tester.element(find.text('Save'))).brightness,
      Brightness.light,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the core controls in custom', (tester) async {
    await pumpGallery(
      tester,
      settings: jsonEncode({
        'theme': 'custom',
        'customThemePath': '/x.json',
        'customThemeColors': jsonDecode(sampleTheme),
      }),
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
    final harness = await pumpGallery(tester);
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(harness.store.read().theme, AppThemeMode.light);
    expect(
      Theme.of(tester.element(find.text('Save'))).brightness,
      Brightness.light,
    );
  });

  testWidgets('loading an invalid file shows its message', (tester) async {
    final harness = await pumpGallery(tester);
    final dir = harness.directory;
    final bad = File('${dir.path}/bad.json')..writeAsStringSync('{"mode": 3}');

    await tester.enterText(find.byType(TextField).first, bad.path);
    await tester.tap(find.text('Load'));
    await tester.pumpAndSettle();

    expect(
      find.text('"mode" must be "dark" or "light", got "3".'),
      findsOneWidget,
    );
    expect(harness.store.read().theme, AppThemeMode.dark);

    final good = File('${dir.path}/good.json')
      ..writeAsStringSync('{"mode": "light", "primary": "#aa0000"}');
    await tester.enterText(find.byType(TextField).first, good.path);
    await tester.tap(find.text('Load'));
    await tester.pumpAndSettle();

    final stored = harness.store.read();
    expect(stored.theme, AppThemeMode.custom);
    expect(stored.customThemePath, good.path);
    expect(find.text(good.path), findsWidgets);
    expect(find.textContaining('must be'), findsNothing);
    expect(
      Theme.of(tester.element(find.text('Save'))).brightness,
      Brightness.light,
    );
  });
}
