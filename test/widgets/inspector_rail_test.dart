import 'package:anvil/app/shell/editor_dialog.dart';
import 'package:anvil/app/shell/shell_domain.dart';
import 'package:anvil/app/theme/anvil_metrics.dart';
import 'package:anvil/app/theme/theme_selection.dart';
import 'package:anvil/app/widgets/inspector_rail.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../app_bootstrap_test.dart' show AppHarness;

final linux = TargetPlatformVariant.only(TargetPlatform.linux);

const sections = [
  UsedBySection(
    title: 'Classes',
    domain: ShellDomain.classes,
    refs: [
      UsedByRef('class-warrior', 'Warrior'),
      UsedByRef('class-mage', 'Mage'),
    ],
  ),
  UsedBySection(title: 'NPCs', domain: ShellDomain.npcs, refs: []),
];

/// The rail on `/` of a router that also has the 0.1.6 class editor route,
/// under the app's root overrides with [settingsJson].
Future<GoRouter> pumpRail(
  WidgetTester tester, {
  required String settingsJson,
  List<UsedBySection> sections = sections,
  bool loading = false,
}) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final app = AppHarness.create(settingsJson: settingsJson);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: InspectorRail(sections: sections, loading: loading),
          ),
        ),
      ),
      GoRoute(
        path: '/classes/:id',
        builder: (_, state) =>
            Scaffold(body: Text('class editor ${state.pathParameters['id']}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: app.overrides,
      retry: (_, _) => null,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          theme: ref.watch(themeDataProvider),
          routerConfig: router,
        ),
      ),
    ),
  );
  // A spinning progress indicator never settles.
  loading ? await tester.pump() : await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('lists each section with its count and refs, "Not used" for an '
      'empty one, at the rail width', (tester) async {
    await pumpRail(tester, settingsJson: '{"editingMode":"full-page"}');

    expect(find.text('USED BY'), findsOneWidget);
    expect(find.text('Classes'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Warrior'), findsOneWidget);
    expect(find.text('Mage'), findsOneWidget);
    expect(find.text('NPCs'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text(InspectorRail.emptySectionMessage), findsOneWidget);
    expect(find.text('Not used'), findsOneWidget);
    expect(
      tester.getSize(find.byType(InspectorRail)).width,
      AnvilLayout.inspectorRailWidth,
    );
  }, variant: linux);

  testWidgets('no sections and loading have their own states', (tester) async {
    await pumpRail(tester, settingsJson: '{}', sections: const []);
    expect(find.text(InspectorRail.noSectionsMessage), findsOneWidget);

    await pumpRail(tester, settingsJson: '{}', loading: true);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Warrior'), findsNothing);
  }, variant: linux);

  testWidgets('a ref opens its editor route in full-page mode', (tester) async {
    final router = await pumpRail(
      tester,
      settingsJson: '{"editingMode":"full-page"}',
    );

    await tester.tap(find.byKey(InspectorRail.entryKey('class-mage')));
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/classes/class-mage',
    );
    expect(find.text('class editor class-mage'), findsOneWidget);
  }, variant: linux);

  testWidgets('a ref opens the editor dialog in modal mode', (tester) async {
    final router = await pumpRail(tester, settingsJson: '{}');

    await tester.tap(find.text('Warrior'));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/');
    expect(find.byType(EditorDialog), findsOneWidget);
    expect(find.text('Edit Class'), findsOneWidget);
  }, variant: linux);
}
