import 'package:anvil/app/export/export_controller.dart';
import 'package:anvil/app/lists/record_list_page.dart';
import 'package:anvil/app/lists/record_table.dart';
import 'package:anvil/app/lists/undo_snackbar.dart';
import 'package:anvil/app/shell/app_router.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil/app/theme/anvil_metrics.dart';
import 'package:anvil/app/theme/anvil_theme.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_list_adapter.dart';

final linux = TargetPlatformVariant.only(TargetPlatform.linux);

const menuLabels = ['Edit', 'Duplicate', 'Export', 'Move to Recycle Bin'];

/// The list page over a fake store at `/recipes`, with `/export` as a
/// stand-in, at 1400×800 with the sidebar's width taken.
class MenuHarness {
  final store = FakeRecipeListStore();
  late final lifecycle = FakeLifecycleRepository(store);
  late final adapter = FakeRecipeListAdapter(store);
  final opened = <String>[];
  late ProviderContainer container;
  late GoRouter router;

  String get location =>
      router.routerDelegate.currentConfiguration.uri.toString();

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    router = GoRouter(
      initialLocation: '/recipes',
      routes: [
        GoRoute(
          path: '/recipes',
          builder: (_, _) => Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(width: AnvilLayout.sidebarWidth),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AnvilSpacing.lg),
                    child: RecordListPage<RecipeRecord>(
                      adapter: adapter,
                      onOpen: opened.add,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/export',
          builder: (_, _) => const Scaffold(body: Text('Export stand-in')),
        ),
      ],
    );
    addTearDown(router.dispose);
    container = ProviderContainer(
      overrides: [
        lifecycleRepositoryProvider.overrideWithValue(lifecycle),
        routerProvider.overrideWithValue(router),
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: anvilTheme(AnvilThemeSpec.dark),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

/// Right-clicks the name cell of the row named [name].
Future<void> rightClick(WidgetTester tester, String name) async {
  final cell = find.text(name);
  await tester.ensureVisible(cell);
  await tester.pumpAndSettle();
  await tester.tapAt(tester.getCenter(cell), buttons: kSecondaryButton);
  await tester.pumpAndSettle();
}

Finder menuRow(String label, String id) =>
    find.byKey(RecordTable.contextMenuKey(label, id));

/// The context menu rows on screen, as label-id keys.
List<String> shownMenuRows(Iterable<String> ids) => [
  for (final id in ids)
    for (final label in menuLabels)
      if (menuRow(label, id).evaluate().isNotEmpty) '$label $id',
];

const ids = ['r-sword', 'r-potion', 'r-leather', 'r-old'];

Future<void> pick(WidgetTester tester, String label, String id) async {
  await tester.tap(menuRow(label, id));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'a right-click on an active row opens Edit, Duplicate, Export and Move '
    'to Recycle Bin at the pointer; Edit opens the record and closes the menu',
    (tester) async {
      final h = MenuHarness();
      await h.pump(tester);

      await rightClick(tester, 'Brew Potion');
      expect(shownMenuRows(ids), [for (final l in menuLabels) '$l r-potion']);
      // The menu opens at the pointer, below and right of it.
      final pointer = tester.getCenter(find.text('Brew Potion'));
      final menuTop = tester.getTopLeft(menuRow('Edit', 'r-potion'));
      expect((menuTop.dx - pointer.dx).abs(), lessThan(24));
      expect((menuTop.dy - pointer.dy).abs(), lessThan(24));
      // The danger row is drawn in the error colour.
      final danger = tester.widget<MenuItemButton>(
        menuRow('Move to Recycle Bin', 'r-potion'),
      );
      final context = tester.element(find.byType(RecordListPage<RecipeRecord>));
      expect(
        danger.style?.foregroundColor?.resolve({}),
        Theme.of(context).colorScheme.error,
      );

      await pick(tester, 'Edit', 'r-potion');
      expect(h.opened, ['r-potion']);
      expect(shownMenuRows(ids), isEmpty);
    },
    variant: linux,
  );

  testWidgets('Duplicate goes through the adapter', (tester) async {
    final h = MenuHarness();
    await h.pump(tester);

    await rightClick(tester, 'Tan Leather');
    await pick(tester, 'Duplicate', 'r-leather');

    expect(h.store.calls, contains('duplicate r-leather'));
    expect(find.text('Tan Leather (Copy)'), findsOneWidget);
    expect(shownMenuRows(ids), isEmpty);
  }, variant: linux);

  testWidgets('Move to Recycle Bin soft-deletes at once and offers Undo', (
    tester,
  ) async {
    final h = MenuHarness();
    await h.pump(tester);

    await rightClick(tester, 'Brew Potion');
    await pick(tester, 'Move to Recycle Bin', 'r-potion');

    expect(h.store.calls, contains('softDelete r-potion'));
    expect(find.text('Brew Potion'), findsNothing);
    expect(find.byKey(undoSnackBarKey), findsOneWidget);
    expect(find.text('Deleted "Brew Potion"'), findsOneWidget);
  }, variant: linux);

  testWidgets(
    'Export sets the export request for the record and goes to /export',
    (tester) async {
      final h = MenuHarness();
      await h.pump(tester);
      expect(h.container.read(exportRequestProvider), isNull);

      await rightClick(tester, 'Forge Iron Sword');
      await pick(tester, 'Export', 'r-sword');

      expect(
        h.container.read(exportRequestProvider),
        const ExportRequest(ExportDomain.recipes, 'r-sword'),
      );
      expect(h.location, '/export');
      expect(find.text('Export stand-in'), findsOneWidget);
    },
    variant: linux,
  );

  testWidgets('Esc closes the menu', (tester) async {
    final h = MenuHarness();
    await h.pump(tester);

    await rightClick(tester, 'Brew Potion');
    expect(shownMenuRows(ids), isNotEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(shownMenuRows(ids), isEmpty);
    expect(h.opened, isEmpty);
  }, variant: linux);

  testWidgets('a click outside closes the menu without acting', (tester) async {
    final h = MenuHarness();
    await h.pump(tester);

    await rightClick(tester, 'Brew Potion');
    await tester.tapAt(const Offset(1300, 760));
    await tester.pumpAndSettle();

    expect(shownMenuRows(ids), isEmpty);
    expect(h.opened, isEmpty);
    expect(h.store.calls.where((c) => !c.startsWith('list')), isEmpty);
  }, variant: linux);

  testWidgets('right-clicking a second row closes the first menu and shows the '
      "second row's", (tester) async {
    final h = MenuHarness();
    await h.pump(tester);

    // The lower row first: the menu opens below the pointer and would
    // cover the rows beneath it.
    await rightClick(tester, 'Tan Leather');
    expect(shownMenuRows(ids), [for (final l in menuLabels) '$l r-leather']);
    await rightClick(tester, 'Brew Potion');
    expect(shownMenuRows(ids), [for (final l in menuLabels) '$l r-potion']);

    await pick(tester, 'Edit', 'r-potion');
    expect(h.opened, ['r-potion']);
  }, variant: linux);

  testWidgets('Arrow Down then Enter activates the second row', (tester) async {
    final h = MenuHarness();
    await h.pump(tester);

    await rightClick(tester, 'Brew Potion');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(h.store.calls, contains('duplicate r-potion'));
    expect(h.opened, isEmpty);
    expect(shownMenuRows(ids), isEmpty);
  }, variant: linux);

  testWidgets('archived rows open no menu', (tester) async {
    final h = MenuHarness();
    await h.pump(tester);

    await tester.tap(find.text('Archived'));
    await tester.pumpAndSettle();
    expect(find.text('Old Recipe'), findsOneWidget);

    await rightClick(tester, 'Old Recipe');
    expect(shownMenuRows(ids), isEmpty);
    expect(find.byType(MenuItemButton), findsNothing);
  }, variant: linux);
}
