import 'package:anvil/app/domains/loot_tables/loot_tables_editor_controller.dart';
import 'package:anvil/app/domains/loot_tables/loot_tables_editor_page.dart';
import 'package:anvil/app/editor/widgets/dirty_dot.dart';
import 'package:anvil/app/widgets/inspector_rail.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

Finder textIn(Key key) =>
    find.descendant(of: find.byKey(key), matching: find.byType(TextField));

Key entry(int i, String part) => LootTableEditorPage.entryKey(i, part);

String drop(WidgetTester tester, int i) =>
    tester.widget<Text>(find.byKey(entry(i, 'drop'))).data!;

Future<void> openEntries(WidgetTester tester) async {
  await tester.tap(find.byKey(LootTableEditorTab.entries.key));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

bool entriesDot(WidgetTester tester) => tester
    .widget<DirtyDot>(find.byKey(LootTableEditorTab.entries.dotKey))
    .visible;

void main() {
  late LootTableTestHarness h;

  Future<void> pumpEditor(WidgetTester tester, [String id = goblinId]) async {
    h = LootTableTestHarness();
    await h.pump(tester, LootTableEditorPage(id, onBack: () {}));
  }

  LootTableDraft draft(String id) =>
      h.container.read(lootTableEditorProvider(id)).requireValue.draft;

  test('drop percentages follow 0.1.6 formatPercent', () {
    List<String> of(List<int> weights) => dropPercentages([
      for (final w in weights) LootTableEntryDraft(itemId: 'x', weight: w),
    ]);
    // `toFixed(value >= 10 ? 1 : 2)`: one decimal from 10 % up.
    expect(of([1, 3]), ['25.0%', '75.0%']);
    expect(of([9, 1]), ['90.0%', '10.0%']);
    expect(of([1, 19]), ['5.00%', '95.0%']);
    expect(of([1, 2]), ['33.3%', '66.7%']);
    expect(of([60, 30, 10]), ['60.0%', '30.0%', '10.0%']);
    // A weight the blockers refuse still counts as 1, as 0.1.6 clamped it.
    expect(of([0, 1]), ['50.0%', '50.0%']);
    expect(of([]), isEmpty);
  });

  testWidgets('shows the header, the two tabs, the Overview and the NPCs '
      'rail', (tester) async {
    await pumpEditor(tester);

    expect(find.text('Goblin Drops'), findsWidgets);
    expect(find.text('goblin_drops'), findsOneWidget);
    for (final tab in LootTableEditorTab.values) {
      expect(find.byKey(tab.key), findsOneWidget);
    }
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('loot-table-overview-description')),
          )
          .data,
      'What goblins carry.',
    );
    expect(find.text('USED BY'), findsOneWidget);
    expect(find.text(LootTableEditorPage.npcsSection), findsOneWidget);
    expect(find.byKey(InspectorRail.entryKey(raiderId)), findsOneWidget);
    expect(find.text('Goblin Raider'), findsOneWidget);
  }, variant: linux);

  testWidgets('the Entries tab shows the rows with their drop percentages', (
    tester,
  ) async {
    await pumpEditor(tester);
    await openEntries(tester);

    expect(find.text(dropCaption), findsOneWidget);
    for (final label in ['Item', 'Weight', 'Drop', 'Min Qty', 'Max Qty']) {
      expect(find.text(label), findsWidgets);
    }
    expect(
      [drop(tester, 0), drop(tester, 1), drop(tester, 2)],
      ['60.0%', '30.0%', '10.0%'],
    );
    expect(find.text('Iron Ingot'), findsOneWidget);
    expect(
      tester.widget<TextField>(textIn(entry(0, 'max'))).controller!.text,
      '3',
    );
    expect(find.byKey(LootTableEditorPage.deletedWarningKey), findsNothing);
  }, variant: linux);

  testWidgets('weights recompute the percentages from the draft', (
    tester,
  ) async {
    await pumpEditor(tester, chestId);
    await openEntries(tester);
    expect(drop(tester, 0), '100.0%');

    await tapKey(tester, LootTableEditorPage.addEntryKey);
    await tester.enterText(textIn(entry(1, 'weight')), '3');
    await tester.pumpAndSettle();
    // 0.1.6's `toFixed(value >= 10 ? 1 : 2)`: 25 % has one decimal.
    expect([drop(tester, 0), drop(tester, 1)], ['25.0%', '75.0%']);

    await tester.enterText(textIn(entry(1, 'weight')), '19');
    await tester.pumpAndSettle();
    expect([drop(tester, 0), drop(tester, 1)], ['5.00%', '95.0%']);

    await tester.enterText(textIn(entry(0, 'weight')), '9');
    await tester.enterText(textIn(entry(1, 'weight')), '1');
    await tester.pumpAndSettle();
    expect([drop(tester, 0), drop(tester, 1)], ['90.0%', '10.0%']);
  }, variant: linux);

  testWidgets('adds, reorders and removes entries, each one undo step', (
    tester,
  ) async {
    await pumpEditor(tester);
    await openEntries(tester);
    expect(entriesDot(tester), isFalse);

    // Add Entry takes the first active item, as 0.1.6.
    await tapKey(tester, LootTableEditorPage.addEntryKey);
    expect(draft(goblinId).entries.last.itemId, potionId);
    expect(entriesDot(tester), isTrue);
    expect(find.byKey(const ValueKey('save-bar')), findsOneWidget);

    await tapKey(tester, entry(2, 'up'));
    expect(
      [for (final e in draft(goblinId).entries) e.itemId],
      [ingotId, swordId, potionId, potionId],
    );
    await tapKey(tester, entry(0, 'remove'));
    expect(draft(goblinId).entries, hasLength(3));

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tapKey(tester, const ValueKey('editor-undo'));
    expect(draft(goblinId).entries, hasLength(4));
    await tapKey(tester, const ValueKey('editor-undo'));
    expect(draft(goblinId).entries[1].itemId, potionId);
    await tapKey(tester, const ValueKey('editor-undo'));
    expect(draft(goblinId), goblinDraft());
    expect(entriesDot(tester), isFalse);
    expect(find.byKey(const ValueKey('save-bar')), findsNothing);
  }, variant: linux);

  testWidgets('a weight or minimum below 1 or a maximum below the minimum '
      'refuses Save with the core message', (tester) async {
    await pumpEditor(tester);
    await openEntries(tester);

    await tester.enterText(textIn(entry(0, 'weight')), '0');
    await tester.pumpAndSettle();
    expect(
      find.text('Entry 1: weight must be at least 1.'),
      findsNWidgets(2), // the row's line and the save bar
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('save-bar-save')))
          .onPressed,
      isNull,
    );

    await tester.enterText(textIn(entry(0, 'weight')), '5');
    await tester.enterText(textIn(entry(1, 'min')), '4');
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(entry(1, 'errors')),
        matching: find.text(
          'Entry 2: maximum quantity cannot be less than the minimum.',
        ),
      ),
      findsOneWidget,
    );
    expect(find.byKey(entry(0, 'errors')), findsNothing);

    await tester.enterText(textIn(entry(1, 'min')), '');
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(entry(1, 'errors')),
        matching: find.text('Entry 2: minimum quantity must be at least 1.'),
      ),
      findsOneWidget,
    );
  }, variant: linux);

  testWidgets('Save writes the draft and runs the record validation', (
    tester,
  ) async {
    await pumpEditor(tester);
    await openEntries(tester);
    await tester.enterText(textIn(LootTableEditorPage.descriptionKey), 'New.');
    await tester.enterText(textIn(entry(2, 'weight')), '20');
    await tester.pumpAndSettle();
    final before = h.epoch;

    await tapKey(tester, const ValueKey('save-bar-save'));
    expect(h.tables.drafts[goblinId]!.description, 'New.');
    expect(h.tables.drafts[goblinId]!.entries[2].weight, 20);
    expect(h.tables.drafts[goblinId]!.entries[2].conditionalFlags, {
      'boss_only': true,
    });
    expect(h.script.refreshes, 1);
    expect(h.epoch, before + 1);
    expect(find.byKey(const ValueKey('save-bar')), findsNothing);
  }, variant: linux);

  testWidgets('an entry naming a soft-deleted item shows 0.1.6 warnings', (
    tester,
  ) async {
    h = LootTableTestHarness();
    h.tables.drafts[chestId] = chestDraft().copyWith(
      entries: [LootTableEntryDraft(itemId: cursedId, weight: 2)],
    );
    await h.pump(tester, LootTableEditorPage(chestId, onBack: () {}));
    expect(find.text(deletedReferenceWarning), findsOneWidget);
    await openEntries(tester);

    expect(find.text('Cursed Dagger (deleted)'), findsOneWidget);
    expect(find.text('Soft-deleted item reference'), findsOneWidget);
  }, variant: linux);

  testWidgets('with no active items Add Entry is disabled with 0.1.6 notice', (
    tester,
  ) async {
    h = LootTableTestHarness(
      items: [item(cursedId, 'Cursed Dagger', deletedAt: '2026-10-31')],
    );
    await h.pump(tester, LootTableEditorPage(chestId, onBack: () {}));
    await openEntries(tester);

    expect(
      find.text('Create an active item before adding loot entries.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ButtonStyleButton>(
            find.byKey(LootTableEditorPage.addEntryKey),
          )
          .enabled,
      isFalse,
    );
  }, variant: linux);

  testWidgets('Duplicate is disabled while dirty and copies when clean', (
    tester,
  ) async {
    await pumpEditor(tester);
    Finder duplicate() => find.byKey(LootTableEditorPage.duplicateKey);
    expect(tester.widget<ButtonStyleButton>(duplicate()).enabled, isTrue);
    await openEntries(tester);
    await tester.enterText(textIn(entry(0, 'weight')), '61');
    await tester.pumpAndSettle();
    expect(tester.widget<ButtonStyleButton>(duplicate()).enabled, isFalse);
  }, variant: linux);

  testWidgets('lays out at natural height inside a scroll view, as in the '
      'editor dialog', (tester) async {
    h = LootTableTestHarness();
    await h.pump(
      tester,
      SingleChildScrollView(
        child: LootTableEditorPage(goblinId, onBack: () {}),
      ),
    );
    await openEntries(tester);
    expect(drop(tester, 2), '10.0%');
    await tester.enterText(textIn(entry(0, 'weight')), '61');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('save-bar')), findsOneWidget);
  }, variant: linux);

  testWidgets('an unknown id shows Loot table not found.', (tester) async {
    await pumpEditor(tester, 'missing');
    expect(find.text('Loot table not found.'), findsOneWidget);
    expect(find.text('Back to Loot Tables'), findsOneWidget);
  }, variant: linux);
}
