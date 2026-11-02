import 'package:anvil/app/domains/classes/classes_editor_controller.dart';
import 'package:anvil/app/domains/classes/classes_editor_page.dart';
import 'package:anvil/app/domains/classes/classes_growth_providers.dart';
import 'package:anvil/app/domains/classes/classes_pages.dart';
import 'package:anvil/app/domains/classes/classes_stat_growth_tab.dart';
import 'package:anvil/app/editor/widgets/dirty_dot.dart';
import 'package:anvil/app/editor/widgets/draft_picker.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_fakes.dart';

const str = 'stat-str';
const intel = 'stat-int';

typedef GrowthTab = ClassStatGrowthTab;

Finder editable(Key key) =>
    find.descendant(of: find.byKey(key), matching: find.byType(EditableText));

bool dotVisible(WidgetTester tester) => tester
    .widget<DirtyDot>(find.byKey(ClassEditorPage.dotKey('Stat Growth')))
    .visible;

String previewText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(GrowthTab.ffillPreviewKey)).data!;

Color? previewColor(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(GrowthTab.ffillPreviewKey)).style?.color;

bool applyEnabled(WidgetTester tester) =>
    tester
        .widget<ButtonStyleButton>(find.byKey(GrowthTab.ffillApplyKey))
        .onPressed !=
    null;

/// The manual entries of [statId] in the open editor's draft, by level.
Map<int, double> manualColumn(ClassHarness h, String statId) {
  final draft = h.container.read(classEditorProvider(warriorId)).value!.draft;
  return {
    for (final MapEntry(:key, :value) in draft.statGrowth.entries)
      if (key.statId == statId) key.level: value,
  };
}

Future<void> openStatGrowth(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(Tab, 'Stat Growth'));
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> type(WidgetTester tester, Key key, String text) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.enterText(editable(key), text);
  await tester.pump();
}

Future<void> pickShape(WidgetTester tester, String label) async {
  await tap(tester, find.byKey(GrowthTab.ffillShapeKey));
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> undoWithKeyboard(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the stat picker lists only the manual stats', (tester) async {
    final h = ClassHarness();
    await h.pump(tester, classEditor(warriorId));
    await openStatGrowth(tester);

    final picker = tester.widget<DraftPicker<String?>>(
      find.descendant(
        of: find.byKey(GrowthTab.ffillStatKey),
        matching: find.byType(DraftPicker<String?>),
      ),
    );
    // Intelligence is in formula mode in the warrior fixture.
    expect([for (final o in picker.options) o.label], ['Strength']);
    expect(picker.value, str);
    await tester.pump(previewDebounce);
  }, variant: linux);

  testWidgets('the preview follows every input: the seeded start, a typed '
      'start, the range, the shape, and the ellipsis past 12 entries', (
    tester,
  ) async {
    final h = ClassHarness();
    await h.pump(tester, classEditor(warriorId));
    await openStatGrowth(tester);

    expect(applyEnabled(tester), isFalse);
    // A blank Start is seeded from the grid's level-1 Strength value, 10.
    await type(tester, GrowthTab.ffillIncrementKey, '2');
    expect(
      previewText(tester),
      'L1 10 · L2 12 · L3 14 · L4 16 · L5 18 · L6 20 · L7 22 · L8 24 · '
      'L9 26 · L10 28',
    );
    expect(applyEnabled(tester), isTrue);

    await type(tester, GrowthTab.ffillStartKey, '0');
    await type(tester, GrowthTab.ffillToKey, '4');
    expect(previewText(tester), 'L1 0 · L2 2 · L3 4 · L4 6');

    await pickShape(tester, 'Multiply with cap');
    expect(find.byKey(GrowthTab.ffillIncrementKey), findsNothing);
    expect(applyEnabled(tester), isFalse);
    await type(tester, GrowthTab.ffillStartKey, '3');
    await type(tester, GrowthTab.ffillFactorKey, '2');
    await type(tester, GrowthTab.ffillCapKey, '10');
    expect(previewText(tester), 'L1 3 · L2 6 · L3 10 · L4 10');

    await pickShape(tester, 'Approach limit');
    await type(tester, GrowthTab.ffillLimitKey, '100');
    await type(tester, GrowthTab.ffillRateKey, '0.5');
    await type(tester, GrowthTab.ffillStartKey, '0');
    expect(previewText(tester), 'L1 0 · L2 50 · L3 75 · L4 87.5');

    // Past 12 entries the preview skips to the last one.
    h.meta.maxLevel = 20;
    h.container.read(writeEpochProvider.notifier).bump();
    await tester.pumpAndSettle();
    await pickShape(tester, 'Step');
    await type(tester, GrowthTab.ffillIncrementKey, '1');
    await type(tester, GrowthTab.ffillToKey, '20');
    expect(
      previewText(tester),
      'L1 0 · L2 1 · L3 2 · L4 3 · L5 4 · L6 5 · L7 6 · L8 7 · L9 8 · '
      'L10 9 · L11 10 · L12 11 · … L20 19',
    );
    await tester.pump(previewDebounce);
  }, variant: linux);

  testWidgets('an Expression error shows inline in the error colour, Apply '
      'is disabled and nothing is written', (tester) async {
    final h = ClassHarness();
    await h.pump(tester, classEditor(warriorId));
    await openStatGrowth(tester);
    final errorColor = Theme.of(
      tester.element(find.byKey(GrowthTab.ffillPreviewKey)),
    ).colorScheme.error;

    await pickShape(tester, 'Expression');
    expect(find.text(GrowthTab.ffillExpressionHint), findsOneWidget);
    await type(tester, GrowthTab.ffillExpressionKey, 'prev *');
    expect(previewText(tester), validateFormula('prev *'));
    expect(previewColor(tester), errorColor);
    expect(applyEnabled(tester), isFalse);

    await type(tester, GrowthTab.ffillExpressionKey, 'prev + speed');
    expect(
      previewText(tester),
      evaluateFormula('prev + speed', {
        'level': 1,
        'max_level': 10,
        'prev': 10,
      }).error,
    );
    expect(applyEnabled(tester), isFalse);
    expect(manualColumn(h, str), {1: 10});
    expect(dotVisible(tester), isFalse);

    // prev starts at the seeded 10: L1 = 10 * 2 + 1, L2 = 21 * 2 + 2.
    await type(tester, GrowthTab.ffillExpressionKey, 'prev * 2 + level');
    await type(tester, GrowthTab.ffillToKey, '2');
    expect(previewText(tester), 'L1 21 · L2 44');
    expect(previewColor(tester), isNot(errorColor));
    expect(applyEnabled(tester), isTrue);
    await tester.pump(previewDebounce);
  }, variant: linux);

  testWidgets('Apply writes the cells, marks the tab dirty and is one undo '
      'step', (tester) async {
    final h = ClassHarness();
    await h.pump(tester, classEditor(warriorId));
    await openStatGrowth(tester);

    await type(tester, GrowthTab.ffillIncrementKey, '2');
    await tap(tester, find.byKey(GrowthTab.ffillApplyKey));
    expect(manualColumn(h, str), {
      for (var l = 1; l <= 10; l++) l: 10.0 + 2 * (l - 1),
    });
    expect(
      tester
          .widget<EditableText>(editable(GrowthTab.cellKey(str, 2)))
          .controller
          .text,
      '12',
    );
    expect(dotVisible(tester), isTrue);

    // One Ctrl+Z restores the column as it was before the fill.
    // No field has focus after the button tap, so Ctrl+Z steps the draft.
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'editor');
    await undoWithKeyboard(tester);
    expect(manualColumn(h, str), {1: 10});
    expect(dotVisible(tester), isFalse);
    await tester.pump(previewDebounce);
  }, variant: linux);

  testWidgets('a second range with a blank Start chains from the first '
      'range\'s last value', (tester) async {
    final h = ClassHarness();
    h.meta.maxLevel = 20;
    await h.pump(tester, classEditor(warriorId));
    await openStatGrowth(tester);

    await type(tester, GrowthTab.ffillToKey, '10');
    await type(tester, GrowthTab.ffillIncrementKey, '2');
    await tap(tester, find.byKey(GrowthTab.ffillApplyKey));
    expect(manualColumn(h, str)[10], 28);

    await type(tester, GrowthTab.ffillFromKey, '10');
    await type(tester, GrowthTab.ffillToKey, '20');
    await type(tester, GrowthTab.ffillIncrementKey, '3');
    expect(previewText(tester), startsWith('L10 28 · L11 31 · '));
    await tap(tester, find.byKey(GrowthTab.ffillApplyKey));
    final column = manualColumn(h, str);
    expect(column[9], 26);
    expect(column[10], 28);
    expect(column[11], 31);
    expect(column[20], 58);
    expect(column, hasLength(20));
    await tester.pump(previewDebounce);
  }, variant: linux);
}
