import 'package:anvil/app/domains/loot_tables/loot_tables_create_dialog.dart';
import 'package:anvil/app/domains/loot_tables/loot_tables_list_adapter.dart';
import 'package:anvil/app/domains/loot_tables/loot_tables_pages.dart';
import 'package:anvil/app/lists/bulk_dialogs.dart';
import 'package:anvil/app/lists/record_table.dart';
import 'package:anvil/app/shell/editor_dialog.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

Finder header(String label) =>
    find.descendant(of: find.byType(DataTable), matching: find.text(label));

Finder cell(String text) =>
    find.descendant(of: find.byType(DataTable), matching: find.text(text));

/// The table's display names, top to bottom.
List<String> names(WidgetTester tester) => [
  for (final row in tester.widget<DataTable>(find.byType(DataTable)).rows)
    ((row.cells[1].child as Text).data!),
];

void main() {
  testWidgets('shows the 0.1.6 columns the record supports', (tester) async {
    final h = LootTableTestHarness();
    await h.pump(tester, lootTablesListPage());

    expect(find.text('Loot Tables'), findsOneWidget);
    for (final label in [
      'Name',
      'Export Key',
      LootTableListAdapter.assignedLabel,
      'Actions',
    ]) {
      expect(header(label), findsOneWidget);
    }
    expect(header('Entries'), findsNothing);
    expect(header(LootTableListAdapter.lastModifiedLabel), findsNothing);
    expect(cell('Goblin Drops'), findsOneWidget);
    expect(cell('goblin_drops'), findsOneWidget);
    expect(cell('Used by 2 NPCs'), findsOneWidget);
    expect(cell('Used by 0 NPCs'), findsOneWidget);
    expect(find.text('+ New Loot Table'), findsOneWidget);
  }, variant: linux);

  testWidgets('searches by name and sorts by Last Modified, newest first', (
    tester,
  ) async {
    final h = LootTableTestHarness();
    await h.pump(tester, lootTablesListPage());
    expect(names(tester), ['Goblin Drops', 'Old Chest']);

    await tester.tap(find.text('Name').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last Modified').last);
    await tester.pumpAndSettle();
    expect(names(tester), ['Old Chest', 'Goblin Drops']);

    await tester.enterText(find.byType(TextField).first, 'gob');
    await tester.pumpAndSettle();
    expect(cell('Goblin Drops'), findsOneWidget);
    expect(cell('Old Chest'), findsNothing);
  }, variant: linux);

  testWidgets('New Loot Table creates with the slugged key, bumps the epoch '
      'and opens the new loot table', (tester) async {
    final h = LootTableTestHarness();
    await h.pump(tester, lootTablesListPage());

    await tester.tap(find.text('+ New Loot Table'));
    await tester.pumpAndSettle();
    expect(find.text('New Loot Table'), findsOneWidget);
    final create = find.byKey(CreateLootTableDialog.createKey);
    expect(tester.widget<FilledButton>(create).onPressed, isNull);

    await tester.enterText(
      find.byKey(CreateLootTableDialog.nameKey),
      'Dragon Hoard!',
    );
    await tester.pump();
    expect(find.text('dragon-hoard'), findsOneWidget);

    final before = h.epoch;
    await tester.tap(create);
    await tester.pumpAndSettle();

    final id = h.tables.drafts.keys.last;
    expect(h.tables.drafts[id]!.displayName, 'Dragon Hoard!');
    expect(h.tables.drafts[id]!.exportKey, 'dragon-hoard');
    expect(h.epoch, before + 1);
    // Modal editing mode (the default): the editor dialog for the new id.
    expect(tester.widget<EditorDialog>(find.byType(EditorDialog)).id, id);
  }, variant: linux);

  testWidgets('a create failure stays in the dialog with the message', (
    tester,
  ) async {
    final h = LootTableTestHarness();
    await h.pump(tester, lootTablesListPage());
    h.tables.failures['create'] = const DuplicateExportKey('dup');

    await tester.tap(find.text('+ New Loot Table'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(CreateLootTableDialog.nameKey), 'Dup');
    await tester.pump();
    await tester.tap(find.byKey(CreateLootTableDialog.createKey));
    await tester.pumpAndSettle();

    expect(
      find.text('The export key "dup" is already used by another record.'),
      findsOneWidget,
    );
    expect(find.byType(EditorDialog), findsNothing);
  }, variant: linux);

  testWidgets('Duplicate opens the copy', (tester) async {
    final h = LootTableTestHarness();
    await h.pump(tester, lootTablesListPage());

    await tester.tap(find.byKey(RecordTable.actionKey('Duplicate', goblinId)));
    await tester.pumpAndSettle();

    expect(h.tables.calls, contains('duplicate $goblinId'));
    final dialog = tester.widget<EditorDialog>(find.byType(EditorDialog));
    expect(h.tables.drafts[dialog.id]!.displayName, 'Goblin Drops (Copy)');
  }, variant: linux);

  testWidgets('deletes to the archive, restores, bulk-deletes and '
      'permanently deletes', (tester) async {
    final h = LootTableTestHarness();
    await h.pump(tester, lootTablesListPage());

    await tester.tap(find.byKey(RecordTable.actionKey('Delete', chestId)));
    await tester.pumpAndSettle();
    expect(cell('Old Chest'), findsNothing);

    await tester.tap(find.text('Archived'));
    await tester.pumpAndSettle();
    expect(cell('Old Chest'), findsOneWidget);
    expect(header('Deleted At'), findsOneWidget);
    await tester.tap(find.byKey(RecordTable.actionKey('Restore', chestId)));
    await tester.pumpAndSettle();
    expect(find.text('No archived loot tables.'), findsOneWidget);

    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Selected'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(BulkDeleteDialog.confirmKey));
    await tester.pumpAndSettle();
    expect(
      h.tables.calls.where((c) => c.startsWith('bulkSoftDelete')),
      hasLength(1),
    );
    expect(h.tables.deleted.keys, containsAll([goblinId, chestId]));
    expect(find.text('No loot tables yet'), findsOneWidget);

    await tester.tap(find.text('Archived'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(RecordTable.actionKey('Permanently Delete', chestId)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(permanentDeleteConfirmKey));
    await tester.pumpAndSettle();
    expect(h.tables.calls, contains('hardDelete $chestId'));
    expect(cell('Old Chest'), findsNothing);
  }, variant: linux);
}
