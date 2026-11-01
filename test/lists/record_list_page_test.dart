import 'dart:async';

import 'package:anvil/app/lists/bulk_dialogs.dart';
import 'package:anvil/app/lists/empty_state.dart';
import 'package:anvil/app/lists/list_columns.dart';
import 'package:anvil/app/lists/list_toolbar.dart';
import 'package:anvil/app/lists/record_list_page.dart';
import 'package:anvil/app/lists/record_table.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil/app/theme/anvil_theme.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_list_adapter.dart';

final linux = TargetPlatformVariant.only(TargetPlatform.linux);

/// The page over a fake store, in the app theme at 1400×1000.
class ListHarness {
  ListHarness._(this.store, this.lifecycle, this.adapter);

  factory ListHarness([List<RecipeRecord>? rows]) {
    final store = FakeRecipeListStore(rows);
    return ListHarness._(
      store,
      FakeLifecycleRepository(store),
      FakeRecipeListAdapter(store),
    );
  }

  final FakeRecipeListStore store;
  final FakeLifecycleRepository lifecycle;
  final FakeRecipeListAdapter adapter;
  final opened = <String>[];
  final duplicated = <RecipeRecord>[];
  var newPressed = 0;
  late ProviderContainer container;

  int get epoch => container.read(writeEpochProvider);

  Future<void> pump(WidgetTester tester, {Widget? filterSlot}) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: [lifecycleRepositoryProvider.overrideWithValue(lifecycle)],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: anvilTheme(AnvilThemeSpec.dark),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: RecordListPage<RecipeRecord>(
                adapter: adapter,
                filterSlot: filterSlot,
                onNew: () => newPressed++,
                onOpen: opened.add,
                onDuplicated: duplicated.add,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

/// The display names in the table, top to bottom.
List<String> shownNames(WidgetTester tester, Iterable<String> candidates) {
  final shown = [
    for (final name in candidates)
      if (find.text(name).evaluate().isNotEmpty) name,
  ];
  shown.sort(
    (a, b) => tester
        .getTopLeft(find.text(a))
        .dy
        .compareTo(tester.getTopLeft(find.text(b)).dy),
  );
  return shown;
}

/// A header label of the table (the Sort by menu holds the same labels).
Finder header(String label) =>
    find.descendant(of: find.byType(DataTable), matching: find.text(label));

const activeNames = ['Brew Potion', 'Forge Iron Sword', 'Tan Leather'];

Future<void> archived(WidgetTester tester) async {
  await tester.tap(find.text('Archived'));
  await tester.pumpAndSettle();
}

Future<void> active(WidgetTester tester) async {
  await tester.tap(find.text('Active'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the title, toolbar and active rows', (tester) async {
    final h = ListHarness();
    await h.pump(tester);

    expect(find.text('Recipes'), findsOneWidget);
    expect(find.text('+ New Recipe'), findsOneWidget);
    expect(find.text('Sort by'), findsOneWidget);
    for (final label in ['Name', 'Export Key', 'Output', 'Actions']) {
      expect(header(label), findsOneWidget);
    }
    expect(shownNames(tester, [...activeNames, 'Old Recipe']), activeNames);

    await tester.tap(find.text('+ New Recipe'));
    await tester.tap(find.text('Tan Leather'));
    await tester.tap(find.byKey(RecordTable.actionKey('Edit', 'r-sword')));
    expect(h.newPressed, 1);
    expect(h.opened, ['r-leather', 'r-sword']);
  }, variant: linux);

  testWidgets('search filters by display name and by export key', (
    tester,
  ) async {
    final h = ListHarness();
    await h.pump(tester);

    await tester.enterText(find.byKey(ListToolbar.searchKey), 'POTION');
    await tester.pumpAndSettle();
    expect(shownNames(tester, activeNames), ['Brew Potion']);

    // Only the export key of Tan Leather contains "tanning".
    await tester.enterText(find.byKey(ListToolbar.searchKey), 'tanning');
    await tester.pumpAndSettle();
    expect(shownNames(tester, activeNames), ['Tan Leather']);

    await tester.enterText(find.byKey(ListToolbar.searchKey), 'zzz');
    await tester.pumpAndSettle();
    expect(shownNames(tester, activeNames), isEmpty);
    expect(find.text('No results match your search'), findsOneWidget);

    await tester.enterText(find.byKey(ListToolbar.searchKey), '');
    await tester.pumpAndSettle();
    expect(shownNames(tester, activeNames), activeNames);
  }, variant: linux);

  testWidgets('a page with a filter slot says filters when nothing matches', (
    tester,
  ) async {
    final h = ListHarness();
    await h.pump(tester, filterSlot: const Text('Station filter'));
    expect(find.text('Station filter'), findsOneWidget);

    await tester.enterText(find.byKey(ListToolbar.searchKey), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No results match your filters'), findsOneWidget);
  }, variant: linux);

  testWidgets('sorts by a column in both directions, from the header and '
      'from the Sort by menu', (tester) async {
    final h = ListHarness();
    await h.pump(tester);
    expect(shownNames(tester, activeNames), activeNames);

    // Name is the current sort: its header flips it.
    await tester.tap(header('Name'));
    await tester.pumpAndSettle();
    expect(shownNames(tester, activeNames), activeNames.reversed);
    await tester.tap(header('Name'));
    await tester.pumpAndSettle();
    expect(shownNames(tester, activeNames), activeNames);

    // Another header starts ascending, then flips.
    final byKey = ['Brew Potion', 'Forge Iron Sword', 'Tan Leather'];
    await tester.tap(header('Export Key'));
    await tester.pumpAndSettle();
    // brew_potion < forge_iron_sword < leather_tanning
    expect(shownNames(tester, activeNames), byKey);
    await tester.tap(header('Export Key'));
    await tester.pumpAndSettle();
    expect(shownNames(tester, activeNames), byKey.reversed);

    // The menu picks an option ascending: Output (item-hide < item-potion
    // < item-sword).
    await tester.tap(find.byKey(ListToolbar.sortKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Output').last);
    await tester.pumpAndSettle();
    expect(shownNames(tester, activeNames), [
      'Tan Leather',
      'Brew Potion',
      'Forge Iron Sword',
    ]);
  }, variant: linux);

  testWidgets('Active/Archived switches the rows and clears the selection', (
    tester,
  ) async {
    final h = ListHarness();
    await h.pump(tester);
    await tester.tap(find.byKey(RecordTable.selectKey('r-sword')));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    await archived(tester);
    expect(find.text('1 selected'), findsNothing);
    expect(shownNames(tester, [...activeNames, 'Old Recipe']), ['Old Recipe']);
    expect(header('Deleted At'), findsOneWidget);
    expect(header('Output'), findsNothing);
    expect(find.text(formatDeletedAt('2026-10-31 14:05:09')), findsOneWidget);
    expect(find.text('+ New Recipe'), findsNothing);
    expect(find.byTooltip('Restore'), findsOneWidget);
    expect(find.byTooltip('Permanently Delete'), findsOneWidget);
    expect(h.store.calls, contains('list deletedOnly'));

    // Archived rows do not open.
    await tester.tap(find.text('Old Recipe'));
    expect(h.opened, isEmpty);

    await active(tester);
    expect(shownNames(tester, [...activeNames, 'Old Recipe']), activeNames);
    expect(find.text('1 selected'), findsNothing);
  }, variant: linux);

  testWidgets('multi-select shows the bulk toolbar; select all toggles', (
    tester,
  ) async {
    final h = ListHarness();
    await h.pump(tester);
    expect(find.text('Delete Selected'), findsNothing);

    await tester.tap(find.byKey(RecordTable.selectKey('r-sword')));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.text('Delete Selected'), findsOneWidget);

    await tester.tap(find.byKey(RecordTable.selectAllKey));
    await tester.pumpAndSettle();
    expect(find.text('3 selected'), findsOneWidget);

    await tester.tap(find.byKey(RecordTable.selectAllKey));
    await tester.pumpAndSettle();
    expect(find.text('Delete Selected'), findsNothing);

    // Select all covers only the rows the search shows.
    await tester.enterText(find.byKey(ListToolbar.searchKey), 'iron');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(RecordTable.selectAllKey));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    expect(h.store.calls.where((c) => !c.startsWith('list')), isEmpty);
  }, variant: linux);

  testWidgets('bulk delete shows the impact, then soft-deletes on confirm', (
    tester,
  ) async {
    final h = ListHarness();
    h.lifecycle.impactGate = Completer();
    h.lifecycle.impact = DeleteImpact(
      recordCount: 2,
      references: const [
        DeleteImpactReference(
          domain: LifecycleDomain.npcs,
          field: 'npc_class_assignments',
          recordCount: 3,
          description: 'NPC class assignments',
        ),
      ],
    );
    await h.pump(tester);
    await tester.tap(find.byKey(RecordTable.selectKey('r-sword')));
    await tester.tap(find.byKey(RecordTable.selectKey('r-potion')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete Selected'));
    await tester.pump();
    expect(find.text('Delete 2 Records?'), findsOneWidget);
    expect(find.text('Computing impact...'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.descendant(
              of: find.byKey(BulkDeleteDialog.confirmKey),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );

    h.lifecycle.impactGate!.complete();
    await tester.pumpAndSettle();
    expect(
      find.text(
        '2 records will be moved to the archive. '
        'You can restore them from the Recycle Bin.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('This will affect references in other domains:'),
      findsOneWidget,
    );
    expect(find.text('•  3 NPC class assignments'), findsOneWidget);

    // Cancel leaves everything as it was.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(h.store.calls.where((c) => c.startsWith('bulk')), isEmpty);
    expect(find.text('2 selected'), findsOneWidget);

    h.lifecycle.impact = null;
    await tester.tap(find.text('Delete Selected'));
    await tester.pumpAndSettle();
    expect(
      find.text('This will affect references in other domains:'),
      findsNothing,
    );
    await tester.tap(find.byKey(BulkDeleteDialog.confirmKey));
    await tester.pumpAndSettle();

    expect(h.store.calls, contains('bulkSoftDelete recipes r-sword,r-potion'));
    expect(h.epoch, 1);
    expect(shownNames(tester, activeNames), ['Tan Leather']);
    expect(find.text('2 selected'), findsNothing);

    await archived(tester);
    expect(shownNames(tester, [...activeNames, 'Old Recipe']), [
      'Brew Potion',
      'Forge Iron Sword',
      'Old Recipe',
    ]);
  }, variant: linux);

  testWidgets('bulk restore runs at once in the archived view', (tester) async {
    final h = ListHarness();
    await h.pump(tester);
    await archived(tester);

    await tester.tap(find.byKey(RecordTable.selectKey('r-old')));
    await tester.pumpAndSettle();
    expect(find.text('Restore Selected'), findsOneWidget);
    await tester.tap(find.text('Restore Selected'));
    await tester.pumpAndSettle();

    expect(h.store.calls, contains('bulkRestore recipes r-old'));
    expect(h.epoch, 1);
    expect(find.text('No archived recipes.'), findsOneWidget);
    await active(tester);
    expect(shownNames(tester, [...activeNames, 'Old Recipe']), [
      'Brew Potion',
      'Forge Iron Sword',
      'Old Recipe',
      'Tan Leather',
    ]);
  }, variant: linux);

  testWidgets('bulk permanent delete asks for confirmation', (tester) async {
    final h = ListHarness();
    h.store.softDelete('r-leather');
    await h.pump(tester);
    await archived(tester);
    await tester.tap(find.byKey(RecordTable.selectAllKey));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Permanently Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Permanently Delete 2 Records?'), findsOneWidget);
    expect(
      find.text(
        '2 records will be permanently deleted. This action cannot be undone.',
        findRichText: true,
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(h.store.calls.where((c) => c.startsWith('bulk')), isEmpty);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Permanently Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(permanentDeleteConfirmKey));
    await tester.pumpAndSettle();

    expect(h.store.calls, contains('bulkHardDelete recipes r-old,r-leather'));
    expect(h.store.rows.map((r) => r.id), ['r-sword', 'r-potion']);
    expect(find.text('No archived recipes.'), findsOneWidget);
  }, variant: linux);

  testWidgets('a single permanent delete confirms; restore runs at once', (
    tester,
  ) async {
    final h = ListHarness();
    h.store.softDelete('r-leather');
    await h.pump(tester);
    await archived(tester);

    await tester.tap(
      find.byKey(RecordTable.actionKey('Permanently Delete', 'r-old')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Permanently Delete Recipe?'), findsOneWidget);
    expect(
      find.text(
        'Old Recipe will be permanently deleted. This action cannot be undone.',
        findRichText: true,
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(h.store.calls, isNot(contains('hardDelete r-old')));

    await tester.tap(
      find.byKey(RecordTable.actionKey('Permanently Delete', 'r-old')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(permanentDeleteConfirmKey));
    await tester.pumpAndSettle();
    expect(h.store.calls, contains('hardDelete r-old'));
    expect(h.epoch, 1);

    await tester.tap(find.byKey(RecordTable.actionKey('Restore', 'r-leather')));
    await tester.pumpAndSettle();
    expect(h.store.calls, contains('restore r-leather'));
    expect(h.epoch, 2);
    expect(find.text('No archived recipes.'), findsOneWidget);
  }, variant: linux);

  testWidgets('Delete soft-deletes at once and Duplicate hands back the copy', (
    tester,
  ) async {
    final h = ListHarness();
    await h.pump(tester);

    await tester.tap(find.byKey(RecordTable.actionKey('Delete', 'r-potion')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(h.store.calls, contains('softDelete r-potion'));
    expect(shownNames(tester, activeNames), [
      'Forge Iron Sword',
      'Tan Leather',
    ]);

    await tester.tap(find.byKey(RecordTable.actionKey('Duplicate', 'r-sword')));
    await tester.pumpAndSettle();
    expect(h.duplicated.single.displayName, 'Forge Iron Sword (Copy)');
    expect(find.text('Forge Iron Sword (Copy)'), findsOneWidget);
    expect(h.epoch, 2);
    expect(h.opened, isEmpty);
  }, variant: linux);

  testWidgets('the empty state shows with no records and its CTA fires', (
    tester,
  ) async {
    final h = ListHarness([]);
    await h.pump(tester);

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('No recipes yet'), findsOneWidget);
    expect(
      find.text('Create your first recipe to get started.'),
      findsOneWidget,
    );
    expect(find.byType(DataTable), findsNothing);
    await tester.tap(find.text('+ Create First Recipe'));
    expect(h.newPressed, 1);

    await archived(tester);
    expect(find.text('No archived recipes.'), findsOneWidget);
  }, variant: linux);

  testWidgets('a repository failure shows the error line until dismissed', (
    tester,
  ) async {
    final h = ListHarness();
    h.store.failures['list'] = StateError('disk gone');
    await h.pump(tester);
    expect(find.text('Failed to load recipes.'), findsOneWidget);

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.byKey(RecordListPage.errorKey), findsNothing);

    // The next write reloads the list.
    h.store.failures['softDelete'] = const SaveFailed(
      'FOREIGN KEY constraint failed',
      'cause',
    );
    await archived(tester);
    await active(tester);
    expect(shownNames(tester, activeNames), activeNames);
    await tester.tap(find.byKey(RecordTable.actionKey('Delete', 'r-sword')));
    await tester.pumpAndSettle();
    expect(find.text('FOREIGN KEY constraint failed'), findsOneWidget);
    expect(h.epoch, 0);
    expect(shownNames(tester, activeNames), activeNames);

    h.store.failures['duplicate'] = const RecordNotFound('recipes', 'r-sword');
    await tester.tap(find.byKey(RecordTable.actionKey('Duplicate', 'r-sword')));
    await tester.pumpAndSettle();
    expect(
      find.text('This record no longer exists. It may have been deleted.'),
      findsOneWidget,
    );
    expect(h.duplicated, isEmpty);

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.byKey(RecordListPage.errorKey), findsNothing);
  }, variant: linux);

  testWidgets('a failing bulk permanent delete keeps the rows and says why', (
    tester,
  ) async {
    final h = ListHarness();
    h.store.failures['bulkHardDelete'] = const SaveFailed(
      'FOREIGN KEY constraint failed',
      'cause',
    );
    await h.pump(tester);
    await archived(tester);
    await tester.tap(find.byKey(RecordTable.selectKey('r-old')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Permanently Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(permanentDeleteConfirmKey));
    await tester.pumpAndSettle();

    expect(find.text('FOREIGN KEY constraint failed'), findsOneWidget);
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.text('Old Recipe'), findsOneWidget);
  }, variant: linux);
}
