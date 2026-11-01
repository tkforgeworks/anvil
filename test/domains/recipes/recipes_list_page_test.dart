import 'package:anvil/app/domains/recipes/recipes_create_dialog.dart';
import 'package:anvil/app/domains/recipes/recipes_list_page.dart';
import 'package:anvil/app/domains/recipes/recipes_pages.dart';
import 'package:anvil/app/lists/bulk_dialogs.dart';
import 'package:anvil/app/lists/record_table.dart';
import 'package:anvil/app/shell/editor_dialog.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

/// A header label of the table.
Finder header(String label) =>
    find.descendant(of: find.byType(DataTable), matching: find.text(label));

Finder cell(String text) =>
    find.descendant(of: find.byType(DataTable), matching: find.text(text));

Future<void> pick(WidgetTester tester, Key picker, String option) async {
  await tester.tap(find.byKey(picker));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows 0.1.6 columns with resolved names', (tester) async {
    final h = RecipeTestHarness();
    await h.pump(tester, recipesListPage());

    for (final label in [
      'Name',
      'Export Key',
      'Output',
      'Station',
      'Specialization',
      'Actions',
    ]) {
      expect(header(label), findsOneWidget);
    }
    expect(cell('Forge Iron Sword'), findsOneWidget);
    expect(cell('Iron Sword x1'), findsOneWidget);
    expect(cell('Forge'), findsOneWidget);
    expect(cell('Blacksmithing'), findsOneWidget);
    expect(cell('Healing Potion x3'), findsOneWidget);
    expect(cell('Alchemy Table'), findsOneWidget);
    // The potion has no specialization.
    expect(cell('-'), findsOneWidget);
    expect(find.text('+ New Recipe'), findsOneWidget);
  }, variant: linux);

  testWidgets('filters by station and specialization', (tester) async {
    final h = RecipeTestHarness();
    await h.pump(tester, recipesListPage());

    await pick(tester, RecipeListPage.stationFilterKey, 'Alchemy Table');
    expect(cell('Brew Healing Potion'), findsOneWidget);
    expect(cell('Forge Iron Sword'), findsNothing);

    await pick(tester, RecipeListPage.stationFilterKey, 'All Stations');
    await pick(
      tester,
      RecipeListPage.specializationFilterKey,
      'No Specialization',
    );
    expect(cell('Brew Healing Potion'), findsOneWidget);
    expect(cell('Forge Iron Sword'), findsNothing);

    await pick(tester, RecipeListPage.specializationFilterKey, 'Alchemy');
    expect(find.text('No results match your filters'), findsOneWidget);
  }, variant: linux);

  testWidgets('searches by name', (tester) async {
    final h = RecipeTestHarness();
    await h.pump(tester, recipesListPage());
    await tester.enterText(find.byType(TextField).first, 'potion');
    await tester.pumpAndSettle();
    expect(cell('Brew Healing Potion'), findsOneWidget);
    expect(cell('Forge Iron Sword'), findsNothing);
  }, variant: linux);

  testWidgets('New Recipe creates with the slugged key, bumps the epoch and '
      'opens the new recipe', (tester) async {
    final h = RecipeTestHarness();
    await h.pump(tester, recipesListPage());

    await tester.tap(find.text('+ New Recipe'));
    await tester.pumpAndSettle();
    expect(find.text('New Recipe'), findsOneWidget);
    final create = find.byKey(CreateRecipeDialog.createKey);
    expect(tester.widget<FilledButton>(create).onPressed, isNull);

    await tester.enterText(
      find.byKey(CreateRecipeDialog.nameKey),
      'Tan Leather!',
    );
    await tester.pump();
    expect(find.text('tan-leather'), findsOneWidget);
    await pick(tester, CreateRecipeDialog.stationKey, 'Forge');

    final before = h.epoch;
    await tester.tap(create);
    await tester.pumpAndSettle();

    final id = h.recipes.drafts.keys.last;
    final created = h.recipes.drafts[id]!;
    expect(created.displayName, 'Tan Leather!');
    expect(created.exportKey, 'tan-leather');
    // The first active item, as 0.1.6 defaulted the output.
    expect(created.outputItemId, potionItemId);
    expect(created.craftingStationId, 'station-forge');
    expect(created.craftingSpecializationId, isNull);
    expect(h.epoch, before + 1);
    // Modal editing mode (the default): the editor dialog for the new id.
    final dialog = tester.widget<EditorDialog>(find.byType(EditorDialog));
    expect(dialog.id, id);
    expect(cell('Tan Leather!'), findsOneWidget);
  }, variant: linux);

  testWidgets('a create failure stays in the dialog with the message', (
    tester,
  ) async {
    final h = RecipeTestHarness();
    await h.pump(tester, recipesListPage());
    h.recipes.failures['create'] = const DuplicateExportKey('dup');

    await tester.tap(find.text('+ New Recipe'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(CreateRecipeDialog.nameKey), 'Dup');
    await tester.pump();
    await tester.tap(find.byKey(CreateRecipeDialog.createKey));
    await tester.pumpAndSettle();

    expect(
      find.text('The export key "dup" is already used by another record.'),
      findsOneWidget,
    );
    expect(find.byType(EditorDialog), findsNothing);
  }, variant: linux);

  testWidgets('Duplicate opens the copy', (tester) async {
    final h = RecipeTestHarness();
    await h.pump(tester, recipesListPage());

    await tester.tap(find.byKey(RecordTable.actionKey('Duplicate', swordId)));
    await tester.pumpAndSettle();

    expect(h.recipes.calls, contains('duplicate $swordId'));
    final dialog = tester.widget<EditorDialog>(find.byType(EditorDialog));
    expect(h.recipes.drafts[dialog.id]!.displayName, 'Forge Iron Sword (Copy)');
  }, variant: linux);

  testWidgets('deletes to the archive, restores and bulk-deletes', (
    tester,
  ) async {
    final h = RecipeTestHarness();
    await h.pump(tester, recipesListPage());

    await tester.tap(find.byKey(RecordTable.actionKey('Delete', swordId)));
    await tester.pumpAndSettle();
    expect(cell('Forge Iron Sword'), findsNothing);

    await tester.tap(find.text('Archived'));
    await tester.pumpAndSettle();
    expect(cell('Forge Iron Sword'), findsOneWidget);
    expect(header('Deleted At'), findsOneWidget);
    await tester.tap(find.byKey(RecordTable.actionKey('Restore', swordId)));
    await tester.pumpAndSettle();
    expect(find.text('No archived recipes.'), findsOneWidget);

    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();
    // Select all, then the bulk delete with its impact dialog.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Selected'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(BulkDeleteDialog.confirmKey));
    await tester.pumpAndSettle();
    expect(
      h.recipes.calls.where((c) => c.startsWith('bulkSoftDelete')),
      hasLength(1),
    );
    expect(h.recipes.deleted.keys, containsAll([swordId, potionId]));
  }, variant: linux);
}
