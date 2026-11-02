import 'package:anvil/app/domains/abilities/abilities_editor_page.dart';
import 'package:anvil/app/domains/classes/classes_ability_panel.dart';
import 'package:anvil/app/domains/classes/classes_derived_stats_tab.dart';
import 'package:anvil/app/domains/classes/classes_editor_page.dart';
import 'package:anvil/app/domains/classes/classes_pages.dart';
import 'package:anvil/app/domains/classes/classes_stat_growth_tab.dart';
import 'package:anvil/app/domains/npcs/npcs_editor_page.dart';
import 'package:anvil/app/editor/widgets/dirty_dot.dart';
import 'package:anvil/app/shell/editor_dialog.dart';
import 'package:anvil/app/shell/shell_domain.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil/app/widgets/inspector_rail.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../npcs/npc_fakes.dart'
    show
        FakeNpcCustomFieldRepository,
        FakeNpcItemRepository,
        FakeNpcLootTableRepository,
        FakeNpcRepository;
import 'class_fakes.dart';

const invalidKeyMessage =
    'Letters, digits, underscores only. Must start with a letter.';

Finder field(String name) => find.descendant(
  of: find.byKey(ClassEditorPage.fieldKey(name)),
  matching: find.byType(EditableText),
);

Finder editable(Key key) =>
    find.descendant(of: find.byKey(key), matching: find.byType(EditableText));

bool dotVisible(WidgetTester tester, String tab) =>
    tester.widget<DirtyDot>(find.byKey(ClassEditorPage.dotKey(tab))).visible;

bool enabled(WidgetTester tester, Key key) =>
    tester.widget<ButtonStyleButton>(find.byKey(key)).onPressed != null;

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(Tab, label));
  await tester.pumpAndSettle();
}

/// The assigned abilities' names, top to bottom.
List<String> assignedNames(WidgetTester tester) {
  final rows = find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('class-ability-row-'),
  );
  final ids = [
    for (final e in rows.evaluate())
      ((e.widget.key! as ValueKey<String>).value.substring(18), e),
  ];
  ids.sort(
    (a, b) => tester
        .getTopLeft(find.byWidget(a.$2.widget))
        .dy
        .compareTo(tester.getTopLeft(find.byWidget(b.$2.widget)).dy),
  );
  return [for (final (id, _) in ids) id];
}

Future<void> undo(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('editor-undo')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the five tabs, the overview, the stat growth and '
      'derived stats tabs and the NPCs rail', (tester) async {
    final h = ClassHarness();
    h.classes.usedByOf[warriorId] = const [UsedByRef('npc-guard', 'Guard')];
    await h.pump(
      tester,
      classEditor(warriorId),
      overrides: [
        npcRepositoryProvider.overrideWithValue(FakeNpcRepository()),
        lootTableRepositoryProvider.overrideWithValue(
          FakeNpcLootTableRepository(),
        ),
        itemRepositoryProvider.overrideWithValue(FakeNpcItemRepository()),
        customFieldRepositoryProvider.overrideWithValue(
          FakeNpcCustomFieldRepository(),
        ),
      ],
    );

    for (final label in ClassEditorPage.tabLabels) {
      expect(find.widgetWithText(Tab, label), findsOneWidget);
    }
    expect(find.text('A sturdy fighter.'), findsOneWidget);
    expect(find.text('USED BY'), findsOneWidget);
    expect(find.text(ClassEditorPage.npcsSection), findsOneWidget);
    expect(find.text('Guard'), findsOneWidget);
    expect(find.byKey(const ValueKey('save-bar')), findsNothing);
    // Every tab but the Overview carries a dot, hidden while clean.
    for (final tab in ClassEditorPage.tabLabels.skip(1)) {
      expect(dotVisible(tester, tab), isFalse);
    }

    // The ANVL-196 tabs (their own tests are in stat_growth_*_test.dart).
    await openTab(tester, 'Stat Growth');
    expect(find.byKey(ClassStatGrowthTab.tabKey), findsOneWidget);
    await openTab(tester, 'Derived Stats');
    expect(find.byKey(ClassDerivedStatsTab.tabKey), findsOneWidget);

    // Click-through opens the NPC in the editing mode (modal here).
    await tester.tap(find.byKey(InspectorRail.entryKey('npc-guard')));
    await tester.pumpAndSettle();
    final page = tester.widget<NpcEditorPage>(find.byType(NpcEditorPage));
    expect(
      (find.byType(EditorDialog).evaluate().length, page.id),
      (1, 'npc-guard'),
    );
  }, variant: linux);

  testWidgets('a non-identifier metadata key disables Save with 0.1.6\'s '
      'reason', (tester) async {
    final h = ClassHarness();
    await h.pump(tester, classEditor(warriorId));
    await openTab(tester, 'Details');

    expect(find.text(ClassEditorPage.resourceMultiplierHelper), findsOneWidget);
    expect(find.text('Class Metadata Fields'), findsOneWidget);
    await tester.enterText(editable(ClassEditorPage.metadataKeyKey(0)), 'a-b');
    await tester.pumpAndSettle();

    expect(find.text(invalidKeyMessage), findsWidgets);
    expect(enabled(tester, const ValueKey('editor-save')), isFalse);
    expect(enabled(tester, const ValueKey('save-bar-save')), isFalse);
    expect(dotVisible(tester, 'Details'), isTrue);
    expect(dotVisible(tester, 'Abilities'), isFalse);

    await tester.enterText(editable(ClassEditorPage.metadataKeyKey(0)), 'ab');
    await tester.pumpAndSettle();
    expect(find.text(invalidKeyMessage), findsNothing);
    expect(enabled(tester, const ValueKey('editor-save')), isTrue);
  }, variant: linux);

  testWidgets('Details edits the multiplier and metadata rows, and Save '
      'writes them once', (tester) async {
    final h = ClassHarness();
    await h.pump(tester, classEditor(warriorId));
    await openTab(tester, 'Details');

    await tester.enterText(field('resourceMultiplier'), '1.5');
    await tester.tap(find.byKey(ClassEditorPage.addMetadataKey));
    await tester.pumpAndSettle();
    expect(find.text('Metadata field key is required.'), findsWidgets);
    await tester.enterText(
      editable(ClassEditorPage.metadataKeyKey(1)),
      'armor',
    );
    await tester.enterText(editable(ClassEditorPage.metadataValueKey(1)), '3');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ClassEditorPage.metadataRemoveKey(0)));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<EditableText>(editable(ClassEditorPage.metadataKeyKey(0)))
          .controller
          .text,
      'armor',
    );

    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();
    final saved = h.classes.saved.single;
    expect(saved.resourceMultiplier, 1.5);
    expect(saved.metadataFields, const [
      ClassMetadataField(fieldKey: 'armor', value: 3),
    ]);
    expect(h.validation.refreshes, 1);
    expect(find.byKey(const ValueKey('save-bar')), findsNothing);
    expect(dotVisible(tester, 'Details'), isFalse);
  }, variant: linux);

  testWidgets('Abilities adds, reorders and removes, each undone one at a '
      'time', (tester) async {
    final h = ClassHarness();
    await h.pump(tester, classEditor(mageId));
    await openTab(tester, 'Abilities');
    expect(find.text(ClassAbilityPanel.emptyMessage), findsOneWidget);
    expect(enabled(tester, ClassAbilityPanel.addKey), isFalse);

    Future<void> add(String name) async {
      await tester.tap(find.byKey(ClassAbilityPanel.pickerKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text(name).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ClassAbilityPanel.addKey));
      await tester.pumpAndSettle();
    }

    await add('Slash');
    await add('Fireball');
    expect(assignedNames(tester), [slashId, fireballId]);
    // Both active abilities are assigned and the archived one is offered
    // nowhere.
    expect(find.text('All abilities are assigned'), findsOneWidget);
    expect(dotVisible(tester, 'Abilities'), isTrue);

    await tester.tap(find.byKey(ClassAbilityPanel.upKey(1)));
    await tester.pumpAndSettle();
    expect(assignedNames(tester), [fireballId, slashId]);
    await tester.tap(find.byKey(ClassAbilityPanel.removeKey(0)));
    await tester.pumpAndSettle();
    expect(assignedNames(tester), [slashId]);

    await undo(tester);
    expect(assignedNames(tester), [fireballId, slashId]);
    await undo(tester);
    expect(assignedNames(tester), [slashId, fireballId]);
    await undo(tester);
    expect(assignedNames(tester), [slashId]);
    await undo(tester);
    expect(assignedNames(tester), isEmpty);
    expect(dotVisible(tester, 'Abilities'), isFalse);
  }, variant: linux);

  testWidgets('a soft-deleted assigned ability shows the warning, and a '
      'name opens the ability editor', (tester) async {
    final h = ClassHarness();
    h.classes.drafts[warriorId] = warriorDraft().copyWith(
      abilityIds: [slashId, retiredId],
    );
    await h.pump(tester, classEditor(warriorId));
    await openTab(tester, 'Abilities');

    expect(find.byKey(ClassAbilityPanel.deletedKey(retiredId)), findsOneWidget);
    expect(find.byKey(ClassAbilityPanel.deletedKey(slashId)), findsNothing);
    expect(find.byTooltip(ClassAbilityPanel.deletedTooltip), findsOneWidget);
    expect(find.text('Retired Move'), findsOneWidget);

    await tester.tap(find.byKey(ClassAbilityPanel.linkKey(slashId)));
    await tester.pumpAndSettle();
    final page = tester.widget<AbilityEditorPage>(
      find.byType(AbilityEditorPage),
    );
    expect(page.id, slashId);
  }, variant: linux);

  testWidgets('the save bar writes the assignments with the class', (
    tester,
  ) async {
    final h = ClassHarness();
    await h.pump(tester, classEditor(warriorId));
    await openTab(tester, 'Abilities');
    await tester.tap(find.byKey(ClassAbilityPanel.downKey(0)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-bar-save')));
    await tester.pumpAndSettle();
    expect(h.classes.saved.single.abilityIds, [fireballId, slashId]);
    expect(h.classes.calls.where((c) => c.startsWith('save')), hasLength(1));
  }, variant: linux);

  testWidgets('works inside the editor dialog\'s scroll view', (tester) async {
    final h = ClassHarness();
    await h.pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => EditorDialog(
              domain: ShellDomain.classes,
              id: warriorId,
              child: classEditor(warriorId),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await openTab(tester, 'Details');
    await tester.ensureVisible(find.byKey(ClassEditorPage.addMetadataKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ClassEditorPage.addMetadataKey));
    await tester.pumpAndSettle();
    expect(find.text('Metadata field key is required.'), findsWidgets);
    await tester.ensureVisible(find.widgetWithText(Tab, 'Abilities'));
    await tester.pumpAndSettle();
    await openTab(tester, 'Abilities');
    await tester.tap(find.byKey(ClassAbilityPanel.removeKey(0)));
    await tester.pumpAndSettle();
    expect(assignedNames(tester), [fireballId]);
    expect(dotVisible(tester, 'Details'), isTrue);
    expect(dotVisible(tester, 'Abilities'), isTrue);
    expect(find.byKey(const ValueKey('save-bar')), findsOneWidget);
  }, variant: linux);

  testWidgets('an unknown id shows Class not found', (tester) async {
    final h = ClassHarness();
    await h.pump(tester, classEditor('nope'));
    expect(find.text('Class not found.'), findsOneWidget);
    expect(find.text('Back to Classes'), findsOneWidget);
  }, variant: linux);
}
