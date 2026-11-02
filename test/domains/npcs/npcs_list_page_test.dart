import 'package:anvil/app/domains/npcs/npcs_create_dialog.dart';
import 'package:anvil/app/domains/npcs/npcs_editor_page.dart';
import 'package:anvil/app/domains/npcs/npcs_list_page.dart';
import 'package:anvil/app/domains/npcs/npcs_pages.dart';
import 'package:anvil/app/lists/list_toolbar.dart';
import 'package:anvil/app/lists/record_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'npc_fakes.dart';

const activeNames = ['Goblin Raider', 'Marla'];

List<String> shownNames(WidgetTester tester) {
  final shown = [
    for (final name in [...activeNames, 'Old Hermit'])
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

Finder inTable(String text) =>
    find.descendant(of: find.byType(DataTable), matching: find.text(text));

Future<void> pick(WidgetTester tester, Key key, String label) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  late NpcHarness h;
  late List<String> opened;

  Future<void> pumpList(WidgetTester tester, {NpcHarness? harness}) async {
    h = harness ?? NpcHarness();
    opened = [];
    await h.pump(tester, NpcListPage(onOpen: opened.add));
  }

  testWidgets('shows the NPC Type and Loot Table columns with names', (
    tester,
  ) async {
    await pumpList(tester);
    expect(find.text('NPCs'), findsWidgets);
    expect(find.text('+ New NPC'), findsOneWidget);
    for (final label in ['Name', 'Export Key', 'NPC Type', 'Loot Table']) {
      expect(inTable(label), findsOneWidget);
    }
    expect(shownNames(tester), activeNames);
    expect(inTable('Enemy'), findsOneWidget);
    expect(inTable('Merchant'), findsOneWidget);
    expect(inTable('Goblin Drops'), findsOneWidget);
    expect(inTable('-'), findsOneWidget);

    await tester.tap(find.text('Marla'));
    expect(opened, [marlaId]);
  }, variant: linux);

  testWidgets('filters by NPC type, and back to all', (tester) async {
    await pumpList(tester);
    await pick(tester, NpcListPage.typeFilterKey, 'Merchant');
    expect(shownNames(tester), ['Marla']);
    await pick(tester, NpcListPage.typeFilterKey, 'Enemy');
    expect(shownNames(tester), ['Goblin Raider']);
    await pick(tester, NpcListPage.typeFilterKey, 'All NPC Types');
    expect(shownNames(tester), activeNames);
  }, variant: linux);

  testWidgets('search matches the type name; Last Modified sorts newest '
      'first', (tester) async {
    await pumpList(tester);
    await tester.enterText(find.byKey(ListToolbar.searchKey), 'merch');
    await tester.pumpAndSettle();
    expect(shownNames(tester), ['Marla']);
    await tester.enterText(find.byKey(ListToolbar.searchKey), 'enemy');
    await tester.pumpAndSettle();
    expect(shownNames(tester), ['Goblin Raider']);
    await tester.enterText(find.byKey(ListToolbar.searchKey), '');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ListToolbar.sortKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last Modified').last);
    await tester.pumpAndSettle();
    expect(shownNames(tester), ['Marla', 'Goblin Raider']);
  }, variant: linux);

  testWidgets('New NPC creates with the slugged key and the first type, '
      'bumps the epoch and opens the NPC', (tester) async {
    await pumpList(tester);
    await tester.tap(find.text('+ New NPC'));
    await tester.pumpAndSettle();
    expect(find.text('New NPC'), findsOneWidget);
    final create = find.byKey(CreateNpcDialog.createKey);
    expect(tester.widget<FilledButton>(create).onPressed, isNull);

    await tester.enterText(find.byKey(CreateNpcDialog.nameKey), ' Orc Brute ');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(CreateNpcDialog.exportKeyKey))
          .controller!
          .text,
      'orc-brute',
    );
    await pick(tester, CreateNpcDialog.typeKey, 'Merchant');
    await tester.tap(create);
    await tester.pumpAndSettle();

    final input = h.npcs.created.single;
    expect(input.displayName, 'Orc Brute');
    expect(input.exportKey, 'orc-brute');
    expect(input.npcTypeId, merchant);
    expect(h.epoch, 1);
    expect(opened, ['npc-new-0']);
    expect(find.text('Orc Brute'), findsOneWidget);
  }, variant: linux);

  testWidgets('with no NPC type the dialog says so and cannot create', (
    tester,
  ) async {
    // A project with no NPC type has no NPCs either.
    final harness = NpcHarness(npcs: const []);
    harness.meta.types.clear();
    await pumpList(tester, harness: harness);
    expect(find.text('No NPCs yet'), findsOneWidget);
    await tester.tap(find.text('+ New NPC'));
    await tester.pumpAndSettle();
    expect(find.text('Create an NPC type before adding NPCs.'), findsOneWidget);
    await tester.enterText(find.byKey(CreateNpcDialog.nameKey), 'Orc');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(CreateNpcDialog.createKey))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(CreateNpcDialog.cancelKey));
    await tester.pumpAndSettle();
    expect(h.npcs.created, isEmpty);
  }, variant: linux);

  testWidgets('Duplicate opens the copy', (tester) async {
    await pumpList(tester);
    await tester.tap(find.byKey(RecordTable.actionKey('Duplicate', marlaId)));
    await tester.pumpAndSettle();
    expect(h.npcs.calls, contains('duplicate $marlaId'));
    expect(opened.single, startsWith('npc-copy-'));
    expect(find.text('Marla (Copy)'), findsOneWidget);
  }, variant: linux);

  testWidgets('the archive lists the deleted NPC', (tester) async {
    await pumpList(tester);
    await tester.tap(find.text('Archived'));
    await tester.pumpAndSettle();
    expect(shownNames(tester), ['Old Hermit']);
  }, variant: linux);

  test('the registry functions build the two pages', () {
    expect(npcsListPage(), isA<NpcListPage>());
    final editor = npcEditor(goblinId);
    expect(editor, isA<NpcEditorPage>());
    expect((editor as NpcEditorPage).id, goblinId);
    expect(editor.key, const ValueKey(goblinId));
  });
}
