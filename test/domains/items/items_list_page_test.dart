import 'package:anvil/app/domains/items/item_create_dialog.dart';
import 'package:anvil/app/domains/items/items_editor_page.dart';
import 'package:anvil/app/domains/items/items_list_page.dart';
import 'package:anvil/app/domains/items/items_pages.dart';
import 'package:anvil/app/lists/list_toolbar.dart';
import 'package:anvil/app/lists/record_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'item_fakes.dart';

const activeNames = ['Elixir', 'Iron Sword', 'Tower Shield'];

/// The display names in the table, top to bottom.
List<String> shownNames(WidgetTester tester, [List<String>? candidates]) {
  final shown = [
    for (final name in candidates ?? [...activeNames, 'Old Club'])
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

Finder header(String label) =>
    find.descendant(of: find.byType(DataTable), matching: find.text(label));

Future<void> pick(WidgetTester tester, Key key, String label) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  late ItemHarness h;
  late List<String> opened;

  Future<void> pumpList(WidgetTester tester) async {
    h = ItemHarness();
    opened = [];
    await h.pump(tester, ItemListPage(onOpen: opened.add));
  }

  testWidgets('shows 0.1.6 columns with category and rarity names', (
    tester,
  ) async {
    await pumpList(tester);

    expect(find.text('Items'), findsOneWidget);
    expect(find.text('+ New Item'), findsOneWidget);
    for (final label in [
      'Name',
      'Export Key',
      'Category',
      'Rarity',
      'Description',
    ]) {
      expect(header(label), findsOneWidget);
    }
    expect(shownNames(tester), activeNames);
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('Weapon'),
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(Chip, 'Rare'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'Common'), findsNWidgets(2));
    expect(find.text('A plain blade.'), findsOneWidget);
    // An empty description shows 0.1.6's dash.
    expect(find.text('-'), findsNWidgets(2));

    await tester.tap(find.text('Tower Shield'));
    expect(opened, [shieldId]);
  }, variant: linux);

  testWidgets('filters by category and by rarity', (tester) async {
    await pumpList(tester);

    await pick(tester, ItemListPage.categoryFilterKey, 'Armor');
    expect(shownNames(tester), ['Tower Shield']);

    await pick(tester, ItemListPage.categoryFilterKey, 'All Categories');
    await pick(tester, ItemListPage.rarityFilterKey, 'Common');
    expect(shownNames(tester), ['Elixir', 'Iron Sword']);

    await pick(tester, ItemListPage.categoryFilterKey, 'Armor');
    expect(shownNames(tester), isEmpty);
    expect(find.text('No results match your filters'), findsOneWidget);
  }, variant: linux);

  testWidgets('search matches name, key and category name; sorts by Last '
      'Modified newest first', (tester) async {
    await pumpList(tester);

    await tester.enterText(find.byKey(ListToolbar.searchKey), 'potion');
    await tester.pumpAndSettle();
    expect(shownNames(tester), ['Elixir']);
    await tester.enterText(find.byKey(ListToolbar.searchKey), '');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ListToolbar.sortKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last Modified').last);
    await tester.pumpAndSettle();
    expect(shownNames(tester), ['Tower Shield', 'Elixir', 'Iron Sword']);
  }, variant: linux);

  testWidgets('New Item creates with the slugged key and the first category '
      'and rarity, bumps the epoch and opens the item', (tester) async {
    await pumpList(tester);

    await tester.tap(find.text('+ New Item'));
    await tester.pumpAndSettle();
    expect(find.text('New Item'), findsOneWidget);
    final create = find.byKey(CreateItemDialog.createKey);
    expect(tester.widget<FilledButton>(create).onPressed, isNull);

    await tester.enterText(
      find.byKey(CreateItemDialog.nameKey),
      '  Steel Axe!  ',
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(CreateItemDialog.exportKeyKey))
          .controller!
          .text,
      'steel-axe',
    );
    await pick(tester, CreateItemDialog.rarityKey, 'Rare');
    await tester.tap(create);
    await tester.pumpAndSettle();

    final input = h.items.created.single;
    expect(input.displayName, 'Steel Axe!');
    expect(input.exportKey, 'steel-axe');
    expect(input.itemCategoryId, weapon);
    expect(input.rarityId, rare);
    expect(h.epoch, 1);
    expect(find.text('New Item'), findsNothing);
    expect(opened, ['item-new-0']);
    expect(find.text('Steel Axe!'), findsOneWidget);
  }, variant: linux);

  testWidgets('an edited export key is kept, and Cancel creates nothing', (
    tester,
  ) async {
    await pumpList(tester);

    await tester.tap(find.text('+ New Item'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(CreateItemDialog.exportKeyKey), 'mine');
    await tester.enterText(find.byKey(CreateItemDialog.nameKey), 'Steel Axe');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(CreateItemDialog.exportKeyKey))
          .controller!
          .text,
      'mine',
    );
    await tester.tap(find.byKey(CreateItemDialog.cancelKey));
    await tester.pumpAndSettle();
    expect(h.items.created, isEmpty);
    expect(opened, isEmpty);
  }, variant: linux);

  testWidgets('Duplicate opens the copy', (tester) async {
    await pumpList(tester);

    await tester.tap(find.byKey(RecordTable.actionKey('Duplicate', swordId)));
    await tester.pumpAndSettle();
    expect(h.items.calls, contains('duplicate $swordId'));
    expect(opened.single, startsWith('item-copy-'));
    expect(find.text('Iron Sword (Copy)'), findsOneWidget);
  }, variant: linux);

  testWidgets('deletes to the archive, restores, and bulk-deletes', (
    tester,
  ) async {
    await pumpList(tester);

    await tester.tap(find.byKey(RecordTable.actionKey('Delete', elixirId)));
    await tester.pumpAndSettle();
    expect(shownNames(tester), ['Iron Sword', 'Tower Shield']);

    await tester.tap(find.text('Archived'));
    await tester.pumpAndSettle();
    expect(shownNames(tester), ['Elixir', 'Old Club']);
    await tester.tap(find.byKey(RecordTable.actionKey('Restore', elixirId)));
    await tester.pumpAndSettle();
    expect(shownNames(tester), ['Old Club']);

    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(RecordTable.selectKey(swordId)));
    await tester.tap(find.byKey(RecordTable.selectKey(shieldId)));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    await tester.tap(find.text('Delete Selected'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(h.items.calls, contains('bulkSoftDelete items $swordId,$shieldId'));
    expect(shownNames(tester), ['Elixir']);
  }, variant: linux);

  test('the registry functions build the two pages', () {
    expect(itemsListPage(), isA<ItemListPage>());
    final editor = itemEditor(swordId);
    expect(editor, isA<ItemEditorPage>());
    expect((editor as ItemEditorPage).id, swordId);
  });
}
