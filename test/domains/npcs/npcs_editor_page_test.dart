import 'package:anvil/app/domains/npcs/npcs_editor_controller.dart';
import 'package:anvil/app/domains/npcs/npcs_editor_page.dart';
import 'package:anvil/app/domains/npcs/npcs_editor_sections.dart';
import 'package:anvil/app/editor/widgets/custom_fields_panel.dart';
import 'package:anvil/app/editor/widgets/dirty_dot.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'npc_fakes.dart';

Finder field(Key key) =>
    find.descendant(of: find.byKey(key), matching: find.byType(TextField));

String textOf(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data!;

String fieldText(WidgetTester tester, Key key) =>
    tester.widget<TextField>(field(key)).controller!.text;

Future<void> pick(WidgetTester tester, Key key, String label) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

Future<void> undo(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('editor-undo')));
  await tester.pumpAndSettle();
}

void main() {
  late NpcHarness h;

  Future<void> pumpEditor(WidgetTester tester, [String id = goblinId]) async {
    h = NpcHarness();
    await h.pump(tester, NpcEditorPage(id, onBack: () {}));
  }

  Future<void> openDetails(WidgetTester tester) async {
    await tester.tap(find.byKey(NpcEditorTab.details.key));
    await tester.pumpAndSettle();
  }

  NpcDraft draft(String id) =>
      h.container.read(npcEditorProvider(id)).requireValue.draft;

  bool detailsDot(WidgetTester tester) => tester
      .widget<DirtyDot>(find.byKey(const ValueKey('npc-tab-dot-details')))
      .visible;

  testWidgets('shows the header, the two tabs and the Overview', (
    tester,
  ) async {
    await pumpEditor(tester);
    expect(find.text('Goblin Raider'), findsWidgets);
    expect(find.text('goblin_raider'), findsOneWidget);
    for (final tab in NpcEditorTab.values) {
      expect(find.byKey(tab.key), findsOneWidget);
    }
    expect(
      textOf(tester, const ValueKey('npc-overview-description')),
      'Sneaky.',
    );
  }, variant: linux);

  testWidgets('the Details tab shows the sections in 0.1.6 order', (
    tester,
  ) async {
    await pumpEditor(tester);
    await openDetails(tester);
    final titles = [
      'Classes',
      'Stat Block',
      'Abilities',
      'Loot Table',
      'Type Fields',
    ];
    final ys = [
      for (final t in titles) tester.getTopLeft(find.text(t).first).dy,
    ];
    expect([...ys]..sort(), ys);
    expect(
      tester.getTopLeft(find.byKey(NpcEditorPage.typeKey)).dy,
      lessThan(ys.first),
    );
    // The loot table's entries, read-only, with their chances.
    expect(find.text('Goblin Drops'), findsWidgets);
    expect(find.text('(2 entries)'), findsOneWidget);
    expect(find.text('75.0%'), findsOneWidget);
    expect(find.text('1–4'), findsOneWidget);
    // The type's fields.
    expect(
      find.byKey(CustomFieldsPanel.fieldKey('field-title')),
      findsOneWidget,
    );
  }, variant: linux);

  testWidgets('adds a class, changes its level and removes it, each undone '
      'from the header', (tester) async {
    await pumpEditor(tester);
    await openDetails(tester);
    expect(find.text('Warrior'), findsOneWidget);

    await pick(tester, ClassAssignmentsSection.pickerKey, 'Mage');
    await tapKey(tester, ClassAssignmentsSection.addKey);
    expect(draft(goblinId).classAssignments.map((a) => a.classId), [
      warrior,
      mage,
    ]);
    expect(fieldText(tester, ClassAssignmentsSection.levelKey(1)), '1');
    expect(detailsDot(tester), isTrue);
    // Mage is no longer offered.
    await tester.tap(find.byKey(ClassAssignmentsSection.pickerKey));
    await tester.pumpAndSettle();
    expect(find.text('Mage'), findsOneWidget);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    await tester.enterText(field(ClassAssignmentsSection.levelKey(1)), '7');
    await tester.pumpAndSettle();
    expect(draft(goblinId).classAssignments[1].level, 7);

    await tapKey(tester, const ValueKey('npc-class-0-remove'));
    expect(draft(goblinId).classAssignments, const [
      NpcClassAssignment(classId: mage, level: 7),
    ]);

    await undo(tester);
    expect(draft(goblinId).classAssignments, hasLength(2));
    await undo(tester);
    expect(draft(goblinId).classAssignments[1].level, 1);
    expect(fieldText(tester, ClassAssignmentsSection.levelKey(1)), '1');
    await undo(tester);
    expect(draft(goblinId).classAssignments, hasLength(1));
    expect(detailsDot(tester), isFalse);
    expect(find.byKey(const ValueKey('save-bar')), findsNothing);
  }, variant: linux);

  testWidgets('a level above the max level is clamped in the field', (
    tester,
  ) async {
    await pumpEditor(tester);
    await openDetails(tester);
    await tester.enterText(field(ClassAssignmentsSection.levelKey(0)), '50');
    await tester.pumpAndSettle();
    expect(draft(goblinId).classAssignments[0].level, 20);
    expect(fieldText(tester, ClassAssignmentsSection.levelKey(0)), '20');
  }, variant: linux);

  testWidgets('the stat block follows the class level and shows an override '
      'against the inherited value', (tester) async {
    await pumpEditor(tester);
    await openDetails(tester);
    // Warrior 3: Strength 6, Wisdom 1; stats in sort order.
    expect(textOf(tester, StatBlockSection.inheritedKey(strength)), '6');
    expect(textOf(tester, StatBlockSection.inheritedKey(wisdom)), '1');
    expect(
      tester.getTopLeft(find.text('Strength')).dy,
      lessThan(tester.getTopLeft(find.text('Wisdom')).dy),
    );

    await tester.enterText(field(ClassAssignmentsSection.levelKey(0)), '5');
    await tester.pumpAndSettle();
    expect(textOf(tester, StatBlockSection.inheritedKey(strength)), '10');
    expect(textOf(tester, StatBlockSection.finalKey(strength)), '10');

    // Adding Mage 1 adds 3 Wisdom.
    await pick(tester, ClassAssignmentsSection.pickerKey, 'Mage');
    await tapKey(tester, ClassAssignmentsSection.addKey);
    expect(textOf(tester, StatBlockSection.inheritedKey(wisdom)), '4');

    await tester.enterText(field(StatBlockSection.overrideKey(strength)), '42');
    await tester.pumpAndSettle();
    expect(draft(goblinId).combatStats, {strength: 42});
    expect(textOf(tester, StatBlockSection.inheritedKey(strength)), '10');
    expect(textOf(tester, StatBlockSection.finalKey(strength)), '42');

    await tapKey(tester, StatBlockSection.revertKey(strength));
    expect(draft(goblinId).combatStats, isEmpty);
    expect(textOf(tester, StatBlockSection.finalKey(strength)), '10');
    expect(fieldText(tester, StatBlockSection.overrideKey(strength)), '');
  }, variant: linux);

  testWidgets('changing the type re-scopes the custom fields, keeping the '
      'shared field', (tester) async {
    await pumpEditor(tester);
    await openDetails(tester);
    expect(
      find.byKey(CustomFieldsPanel.fieldKey('field-aggression')),
      findsOneWidget,
    );

    await pick(tester, NpcEditorPage.typeKey, 'Merchant');
    expect(draft(goblinId).npcTypeId, merchant);
    expect(
      find.byKey(CustomFieldsPanel.fieldKey('field-aggression')),
      findsNothing,
    );
    expect(
      fieldText(tester, CustomFieldsPanel.fieldKey('field-title')),
      'Scout',
    );
    expect(
      fieldText(tester, CustomFieldsPanel.fieldKey('field-discount')),
      '5',
    );

    await undo(tester);
    expect(draft(goblinId).npcTypeId, enemy);
    expect(
      find.byKey(CustomFieldsPanel.fieldKey('field-aggression')),
      findsOneWidget,
    );
  }, variant: linux);

  testWidgets('abilities add and remove; the loot table clears to None', (
    tester,
  ) async {
    await pumpEditor(tester);
    await openDetails(tester);
    await pick(tester, AbilityAssignmentsSection.pickerKey, 'Fireball');
    await tapKey(tester, AbilityAssignmentsSection.addKey);
    expect(draft(goblinId).abilityIds, [slash, fireball]);
    await tapKey(tester, const ValueKey('npc-ability-0-remove'));
    expect(draft(goblinId).abilityIds, [fireball]);

    await pick(tester, LootTableSection.pickerKey, 'None');
    expect(draft(goblinId).lootTableId, isNull);
    expect(find.text('(2 entries)'), findsNothing);
  }, variant: linux);

  testWidgets('a soft-deleted assigned class shows the Deleted chip and the '
      'warning', (tester) async {
    h = NpcHarness(
      npcs: [
        StoredNpc(
          goblinId,
          NpcDraft(
            displayName: 'Goblin Raider',
            exportKey: 'goblin_raider',
            npcTypeId: enemy,
            classAssignments: const [
              NpcClassAssignment(classId: retired, level: 1),
            ],
          ),
        ),
      ],
    );
    await h.pump(tester, NpcEditorPage(goblinId, onBack: () {}));
    await openDetails(tester);
    expect(find.byKey(const ValueKey('npc-class-0-deleted')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('npc-deleted-classes-warning')),
      findsOneWidget,
    );
    expect(textOf(tester, StatBlockSection.inheritedKey(strength)), '100');
  }, variant: linux);

  testWidgets('Save writes the draft once and clears the dot', (tester) async {
    await pumpEditor(tester);
    await openDetails(tester);
    await tester.enterText(field(NpcEditorPage.descriptionKey), 'Loud.');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-bar-save')));
    await tester.pumpAndSettle();
    expect(h.npcs.saved.single.description, 'Loud.');
    expect(detailsDot(tester), isFalse);
    expect(h.epoch, 1);
  }, variant: linux);

  testWidgets('lays out at its natural height inside a scroll view, as in '
      'the editor dialog', (tester) async {
    h = NpcHarness();
    await h.pump(
      tester,
      SingleChildScrollView(child: NpcEditorPage(goblinId, onBack: () {})),
    );
    await openDetails(tester);
    expect(find.text('Type Fields'), findsOneWidget);
    expect(find.byKey(const ValueKey('save-bar')), findsNothing);
  }, variant: linux);

  testWidgets('an unknown id shows NPC not found', (tester) async {
    await pumpEditor(tester, 'npc-missing');
    expect(find.text('NPC not found.'), findsOneWidget);
    expect(find.text('Back to NPCs'), findsOneWidget);
  }, variant: linux);
}
