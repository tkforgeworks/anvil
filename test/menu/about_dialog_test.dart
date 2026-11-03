import 'package:anvil/app/editor/clock.dart';
import 'package:anvil/app/menu/about_dialog.dart';
import 'package:anvil/app/menu/external_links.dart';
import 'package:anvil/app/menu/menu_commands.dart';
import 'package:anvil/app/providers.dart';
import 'package:anvil/app/shell/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'menu_harness.dart';

final _now = DateTime(2027, 3, 1, 12);

final _aboutOverrides = [
  appVersionProvider.overrideWith((ref) async => '0.2.0-rc.1'),
  clockProvider.overrideWithValue(() => _now),
];

Finder _inDialog(Finder finder) =>
    find.descendant(of: find.byType(AboutDialog), matching: finder);

Future<void> _openAbout(WidgetTester tester) async {
  await openSection(tester, 'Help');
  expect(rowWidget(tester, MenuCommand.about).onPressed, isNotNull);
  await tester.tap(row(MenuCommand.about));
  await tester.pumpAndSettle();
}

void main() {
  test('stripBuildNumber drops the build part', () {
    expect(stripBuildNumber('0.2.0+1'), '0.2.0');
    expect(stripBuildNumber('0.2.0-rc.1+7'), '0.2.0-rc.1');
    expect(stripBuildNumber('0.2.0'), '0.2.0');
    expect(aboutLegalese(2026), '© 2026 TK ForgeWorks · Apache-2.0');
  });

  testWidgets(
    'Help > About Anvil shows the name, version, legalese and links',
    (tester) async {
      final harness = await MenuHarness.pump(
        tester,
        overrides: _aboutOverrides,
      );
      await _openAbout(tester);

      expect(find.byType(AboutDialog), findsOneWidget);
      expect(_inDialog(find.text('Anvil')), findsOneWidget);
      expect(_inDialog(find.text('0.2.0-rc.1')), findsOneWidget);
      expect(
        _inDialog(find.text('© 2027 TK ForgeWorks · Apache-2.0')),
        findsOneWidget,
      );
      expect(_inDialog(find.text('RPG Data Management Tool')), findsOneWidget);
      expect(_inDialog(find.text('View licenses')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('about-repository')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('about-report-issue')));
      await tester.pumpAndSettle();
      expect(harness.launched, [
        Uri.parse(repositoryUrl),
        Uri.parse(issuesUrl),
      ]);

      await tester.tap(_inDialog(find.text('Close')));
      await tester.pumpAndSettle();
      expect(find.byType(AboutDialog), findsNothing);
    },
    variant: linux,
  );

  testWidgets('View licenses opens the licence page', (tester) async {
    await MenuHarness.pump(tester, overrides: _aboutOverrides);
    await _openAbout(tester);

    await tester.tap(_inDialog(find.text('View licenses')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(LicensePage), findsOneWidget);
  }, variant: linux);

  testWidgets('a version the platform cannot read shows no version', (
    tester,
  ) async {
    await MenuHarness.pump(
      tester,
      overrides: [
        appVersionProvider.overrideWith((ref) async => throw StateError('x')),
        clockProvider.overrideWithValue(() => _now),
      ],
    );
    await _openAbout(tester);

    expect(find.byType(AboutDialog), findsOneWidget);
    expect(_inDialog(find.text('Anvil')), findsOneWidget);
    expect(_inDialog(find.textContaining('0.2.0')), findsNothing);
  }, variant: linux);

  testWidgets('About is enabled and opens with no project open', (
    tester,
  ) async {
    final launched = <Uri>[];
    late WidgetRef capturedRef;
    final router = GoRouter(
      initialLocation: '/welcome',
      routes: [
        GoRoute(
          path: '/welcome',
          builder: (_, _) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return TextButton(
                  onPressed: () =>
                      dispatchCommand(context, ref, MenuCommand.about),
                  child: const Text('About'),
                );
              },
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._aboutOverrides,
          routerProvider.overrideWithValue(router),
          urlLauncherProvider.overrideWithValue((uri) async {
            launched.add(uri);
            return true;
          }),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    expect(capturedRef.read(projectSessionProvider), isNull);
    expect(commandEnabled(capturedRef, MenuCommand.about), isTrue);
    expect(disabledTooltip(capturedRef, MenuCommand.about), isNull);

    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
    expect(_inDialog(find.text('0.2.0-rc.1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('about-repository')));
    await tester.pumpAndSettle();
    expect(launched, [Uri.parse(repositoryUrl)]);
  });
}
