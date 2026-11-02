import 'package:anvil/app/domains/abilities/abilities_editor_page.dart';
import 'package:anvil/app/domains/abilities/abilities_pages.dart';
import 'package:anvil/app/domains/classes/classes_editor_page.dart';
import 'package:anvil/app/editor/widgets/number_draft_field.dart';
import 'package:anvil/app/editor/widgets/dirty_dot.dart';
import 'package:anvil/app/shell/editor_dialog.dart';
import 'package:anvil/app/shell/shell_domain.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil/app/widgets/inspector_rail.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../classes/class_fakes.dart' show FakeClassRepository;
import 'fakes.dart';

Finder field(String name) => find.descendant(
  of: find.byKey(AbilityEditorPage.fieldKey(name)),
  matching: find.byType(EditableText),
);

Finder modifier(String statId) => find.descendant(
  of: find.byKey(AbilityEditorPage.modifierKey(statId)),
  matching: find.byType(EditableText),
);

String textOf(WidgetTester tester, Finder f) =>
    tester.widget<EditableText>(f).controller.text;

bool dotVisible(WidgetTester tester, String tab) =>
    tester.widget<DirtyDot>(find.byKey(ValueKey('dirty-dot-$tab'))).visible;

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(Tab, label));
  await tester.pumpAndSettle();
}

/// Waits past the 500 ms coalescing window so the next edit is its own
/// undo step.
Future<void> pause(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 600));

void main() {
  testWidgets('shows the header, the three tabs, the overview and the Used '
      'By rail', (tester) async {
    final h = AbilityHarness();
    h.repository.usedByOf[fireballId] = AbilityUsedBy(
      classes: const [UsedByRef('class-mage', 'Mage')],
      npcs: const [],
    );
    await h.pump(
      tester,
      abilityEditor(fireballId),
      overrides: [
        classRepositoryProvider.overrideWithValue(FakeClassRepository()),
      ],
    );

    for (final label in AbilityEditorPage.tabLabels) {
      expect(find.widgetWithText(Tab, label), findsOneWidget);
    }
    expect(find.text('Hurls a ball of fire.'), findsOneWidget);
    expect(find.text('USED BY'), findsOneWidget);
    expect(find.text(AbilityEditorPage.classesSection), findsOneWidget);
    expect(find.text(AbilityEditorPage.npcsSection), findsOneWidget);
    expect(find.text('Mage'), findsOneWidget);
    expect(find.text(InspectorRail.emptySectionMessage), findsOneWidget);
    expect(find.byKey(const ValueKey('save-bar')), findsNothing);

    // Click-through opens the class in the editing mode (modal here).
    await tester.tap(find.byKey(InspectorRail.entryKey('class-mage')));
    await tester.pumpAndSettle();
    final page = tester.widget<ClassEditorPage>(find.byType(ClassEditorPage));
    expect(page.id, 'class-mage');
  }, variant: linux);

  testWidgets('Details edits mark the tab, undo walks back, and Save writes '
      'once and shows record validation', (tester) async {
    final h = AbilityHarness();
    h.validation.issues = [
      ValidationIssue(
        id: 'v1',
        domain: ValidationDomain.abilities,
        recordId: fireballId,
        recordDisplayName: 'Fireball',
        field: 'abilityType',
        severity: ValidationSeverity.warning,
        message: 'Looks odd.',
      ),
    ];
    await h.pump(tester, abilityEditor(fireballId));
    await openTab(tester, 'Details');
    expect(textOf(tester, field('exportKey')), 'fireball');
    expect(textOf(tester, field('abilityType')), 'active');
    expect(textOf(tester, field('resourceCost')), '12');
    expect(textOf(tester, field('cooldown')), '2.5');
    expect(dotVisible(tester, 'Details'), isFalse);

    await tester.enterText(field('abilityType'), 'ultimate');
    await pause(tester);
    await tester.enterText(field('resourceType'), 'rage');
    await pause(tester);
    expect(dotVisible(tester, 'Details'), isTrue);
    expect(dotVisible(tester, 'Stat Modifiers'), isFalse);
    expect(find.byKey(const ValueKey('save-bar')), findsOneWidget);

    // The header's undo steps the draft back; the field follows.
    await tester.tap(find.byKey(const ValueKey('editor-undo')));
    await tester.pumpAndSettle();
    expect(textOf(tester, field('resourceType')), 'mana');
    expect(textOf(tester, field('abilityType')), 'ultimate');

    await tester.tap(find.byKey(const ValueKey('save-bar-save')));
    await tester.pumpAndSettle();
    expect(h.repository.saved, hasLength(1));
    expect(h.repository.saved.single.abilityType, 'ultimate');
    expect(h.repository.saved.single.resourceType, 'mana');
    expect(h.epoch, 1);
    expect(dotVisible(tester, 'Details'), isFalse);
    expect(find.byKey(const ValueKey('save-bar')), findsNothing);

    expect(h.validation.refreshes, 1);
    expect(find.text('Validation: 1 warning'), findsOneWidget);
    expect(find.text('abilityType: Looks odd.'), findsOneWidget);
  }, variant: linux);

  testWidgets('Ctrl+S saves from inside a field and refreshes validation', (
    tester,
  ) async {
    final h = AbilityHarness();
    await h.pump(tester, abilityEditor(fireballId));
    await openTab(tester, 'Details');
    await tester.enterText(field('description'), 'Burns.');
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(h.repository.saved.single.description, 'Burns.');
    expect(h.validation.refreshes, 1);
  }, variant: linux);

  testWidgets('a number field that does not parse leaves the draft and '
      'shows an error; undo rewrites it', (tester) async {
    final h = AbilityHarness();
    await h.pump(tester, abilityEditor(fireballId));
    await openTab(tester, 'Details');

    await tester.enterText(field('resourceCost'), 'abc');
    await tester.pump();
    expect(find.text(NumberDraftField.invalidMessage), findsOneWidget);
    expect(find.byKey(const ValueKey('save-bar')), findsNothing);

    await tester.enterText(field('resourceCost'), '7.5');
    await tester.pump();
    expect(find.text(NumberDraftField.invalidMessage), findsNothing);
    expect(find.byKey(const ValueKey('save-bar')), findsOneWidget);

    // Empty reads as 0, as 0.1.6's `parseFloat('') || 0` saved it.
    await pause(tester);
    await tester.enterText(field('cooldown'), '');
    await tester.pump();
    expect(find.text(NumberDraftField.invalidMessage), findsNothing);

    await tester.tap(find.byKey(const ValueKey('save-bar-save')));
    await tester.pumpAndSettle();
    expect(h.repository.saved.single.resourceCost, 7.5);
    expect(h.repository.saved.single.cooldown, 0);

    // Undo after the save brings the old cooldown back into the field.
    await tester.tap(find.byKey(const ValueKey('editor-undo')));
    await tester.pumpAndSettle();
    expect(textOf(tester, field('cooldown')), '2.5');
  }, variant: linux);

  testWidgets('an emptied export key blocks Save with the core message', (
    tester,
  ) async {
    final h = AbilityHarness();
    await h.pump(tester, abilityEditor(fireballId));
    await openTab(tester, 'Details');

    await tester.enterText(field('exportKey'), '');
    await tester.pump();
    expect(find.text('Export key is required.'), findsNWidgets(2));
    final save = tester.widget<FilledButton>(
      find.byKey(const ValueKey('save-bar-save')),
    );
    expect(save.onPressed, isNull);
  }, variant: linux);

  testWidgets('Stat Modifiers lists every stat; an empty field is no '
      'modifier', (tester) async {
    final h = AbilityHarness();
    await h.pump(tester, abilityEditor(fireballId));
    await openTab(tester, 'Stat Modifiers');

    expect(find.text('Strength'), findsOneWidget);
    expect(find.text('Intelligence'), findsOneWidget);
    expect(textOf(tester, modifier('stat-int')), '3');
    expect(textOf(tester, modifier('stat-str')), '');

    await tester.enterText(modifier('stat-str'), '-2');
    await pause(tester);
    await tester.enterText(modifier('stat-int'), '');
    await tester.pump();
    expect(dotVisible(tester, 'Stat Modifiers'), isTrue);
    expect(dotVisible(tester, 'Details'), isFalse);

    await tester.tap(find.byKey(const ValueKey('save-bar-save')));
    await tester.pumpAndSettle();
    expect(h.repository.saved.single.statModifiers, {'stat-str': -2.0});
  }, variant: linux);

  testWidgets('with no project stats the tab says so', (tester) async {
    final h = AbilityHarness(stats: const []);
    await h.pump(tester, abilityEditor(fireballId));
    await openTab(tester, 'Stat Modifiers');
    expect(find.text('No stats defined in this project.'), findsOneWidget);
  }, variant: linux);

  testWidgets('Duplicate waits for a clean draft and opens the copy', (
    tester,
  ) async {
    final h = AbilityHarness();
    await h.pump(tester, abilityEditor(fireballId));
    await openTab(tester, 'Details');

    await tester.enterText(field('abilityType'), 'passive');
    await tester.pump();
    final dirtyButton = tester.widget<OutlinedButton>(
      find.byKey(AbilityEditorPage.duplicateKey),
    );
    expect(dirtyButton.onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('save-bar-discard')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AbilityEditorPage.duplicateKey));
    await tester.pumpAndSettle();

    expect(h.repository.calls, contains('duplicate $fireballId'));
    expect(h.epoch, 1);
    final copy = h.repository.rows.last;
    expect(copy.displayName, 'Fireball (Copy)');
    // The copy opens as a second, stacked ability editor.
    final pages = tester
        .widgetList<AbilityEditorPage>(find.byType(AbilityEditorPage))
        .map((p) => p.id)
        .toList();
    expect(pages, [fireballId, copy.id]);
  }, variant: linux);

  testWidgets('a missing ability says so', (tester) async {
    final h = AbilityHarness();
    await h.pump(tester, abilityEditor('nope'));
    expect(find.text('Ability not found.'), findsOneWidget);
    expect(find.text('Back to Abilities'), findsOneWidget);
  }, variant: linux);

  testWidgets('inside the editor dialog it lays out at unbounded height and '
      'Back closes the dialog', (tester) async {
    final h = AbilityHarness();
    await h.pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => EditorDialog(
              domain: ShellDomain.abilities,
              id: fireballId,
              child: abilityEditor(fireballId),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(AbilityEditorPage), findsOneWidget);
    expect(find.text('Edit Ability'), findsOneWidget);
    await openTab(tester, 'Stat Modifiers');
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('editor-back')));
    await tester.pumpAndSettle();
    expect(find.byType(EditorDialog), findsNothing);
  }, variant: linux);
}
