import 'package:anvil/app/domains/classes/classes_derived_stats_tab.dart';
import 'package:anvil/app/domains/classes/classes_editor_page.dart';
import 'package:anvil/app/domains/classes/classes_growth_chart.dart';
import 'package:anvil/app/domains/classes/classes_growth_providers.dart';
import 'package:anvil/app/domains/classes/classes_pages.dart';
import 'package:anvil/app/domains/classes/classes_stat_growth_tab.dart';
import 'package:anvil/app/editor/widgets/dirty_dot.dart';
import 'package:anvil/app/shell/editor_dialog.dart';
import 'package:anvil/app/shell/shell_domain.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil/app/theme/anvil_palette.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_fakes.dart';
import 'growth_fakes.dart';

const str = 'stat-str';
const intel = 'stat-int';

Finder editable(Key key) =>
    find.descendant(of: find.byKey(key), matching: find.byType(EditableText));

bool dotVisible(WidgetTester tester, String tab) =>
    tester.widget<DirtyDot>(find.byKey(ClassEditorPage.dotKey(tab))).visible;

bool saveEnabled(WidgetTester tester) =>
    tester
        .widget<ButtonStyleButton>(find.byKey(const ValueKey('editor-save')))
        .onPressed !=
    null;

/// The text a grid cell shows: a manual cell's field text or a formula
/// cell's computed value.
String cellText(WidgetTester tester, String statId, int level) {
  final cell = find.byKey(ClassStatGrowthTab.cellKey(statId, level));
  final field = find.descendant(of: cell, matching: find.byType(EditableText));
  if (field.evaluate().isNotEmpty) {
    return tester.widget<EditableText>(field).controller.text;
  }
  return tester
      .widget<Text>(find.descendant(of: cell, matching: find.byType(Text)))
      .data!;
}

bool isManualCell(String statId, int level) => find
    .descendant(
      of: find.byKey(ClassStatGrowthTab.cellKey(statId, level)),
      matching: find.byType(EditableText),
    )
    .evaluate()
    .isNotEmpty;

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(Tab, label));
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

/// The derived tab's text inside [key] (a result or breakpoint cell).
String markerText(WidgetTester tester, Key key) => tester
    .widget<Text>(
      find.descendant(of: find.byKey(key), matching: find.byType(Text)),
    )
    .data!;

void main() {
  testWidgets('M → F → M with Keep: the formula blocks Save until typed, '
      'its values arrive 300 ms after the last keystroke and Keep bakes '
      'them; undo steps back', (tester) async {
    final h = ClassHarness();
    await h.pump(tester, classEditor(warriorId));
    await openTab(tester, 'Stat Growth');

    expect(find.text('Primary Stat Growth — levels 1–10'), findsOneWidget);
    expect(cellText(tester, str, 1), '10');
    expect(cellText(tester, str, 2), '');
    expect(isManualCell(intel, 1), isFalse);
    expect(cellText(tester, intel, 3), '6');
    expect(dotVisible(tester, 'Stat Growth'), isFalse);

    // M → F: an empty formula, which blocks Save.
    await tap(tester, find.byKey(ClassStatGrowthTab.modeKey(str)));
    expect(find.byKey(ClassStatGrowthTab.formulaKey(str)), findsOneWidget);
    expect(find.text('Stat growth formula is required.'), findsWidgets);
    expect(saveEnabled(tester), isFalse);
    expect(dotVisible(tester, 'Stat Growth'), isTrue);
    expect(isManualCell(str, 1), isFalse);
    expect(cellText(tester, str, 1), '10');

    await type(tester, ClassStatGrowthTab.formulaKey(str), 'level * ');
    expect(saveEnabled(tester), isFalse);
    await tester.pump(const Duration(milliseconds: 100));
    await type(tester, ClassStatGrowthTab.formulaKey(str), 'level * 3');
    expect(saveEnabled(tester), isTrue);
    await tester.pump(const Duration(milliseconds: 299));
    expect(cellText(tester, str, 2), '');
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(cellText(tester, str, 2), '6');
    expect(cellText(tester, str, 10), '30');

    // F → M through the dialog; Cancel changes nothing.
    await tap(tester, find.byKey(ClassStatGrowthTab.modeKey(str)));
    expect(find.text('Switch to Manual Mode'), findsOneWidget);
    expect(
      find.text(
        'How would you like to handle the computed values for this stat?',
      ),
      findsOneWidget,
    );
    await tap(tester, find.byKey(const ValueKey('class-growth-manual-cancel')));
    expect(find.byKey(ClassStatGrowthTab.formulaKey(str)), findsOneWidget);
    await tap(tester, find.byKey(ClassStatGrowthTab.formulaManualKey(str)));
    await tap(tester, find.byKey(const ValueKey('class-growth-manual-keep')));
    expect(find.byKey(ClassStatGrowthTab.formulaKey(str)), findsNothing);
    expect(isManualCell(str, 2), isTrue);
    expect(cellText(tester, str, 1), '3');
    expect(cellText(tester, str, 2), '6');

    // Undo: back to the formula, then the empty formula, then manual.
    await tap(tester, find.byKey(const ValueKey('editor-undo')));
    expect(find.byKey(ClassStatGrowthTab.formulaKey(str)), findsOneWidget);
    expect(
      tester
          .widget<EditableText>(editable(ClassStatGrowthTab.formulaKey(str)))
          .controller
          .text,
      'level * 3',
    );
    await tap(tester, find.byKey(const ValueKey('editor-undo')));
    await tap(tester, find.byKey(const ValueKey('editor-undo')));
    expect(find.byKey(ClassStatGrowthTab.formulaKey(str)), findsNothing);
    expect(cellText(tester, str, 1), '10');
    expect(dotVisible(tester, 'Stat Growth'), isFalse);
    await tester.pump(previewDebounce);
  }, variant: linux);

  testWidgets('Clear Values empties the column; a cell edit, Fill and '
      'Interpolate write the draft and Save writes it with the class', (
    tester,
  ) async {
    final h = ClassHarness();
    await h.pump(tester, classEditor(warriorId));
    await openTab(tester, 'Stat Growth');

    await tap(tester, find.byKey(ClassStatGrowthTab.modeKey(intel)));
    await tap(tester, find.byKey(const ValueKey('class-growth-manual-clear')));
    expect(isManualCell(intel, 1), isTrue);
    expect(cellText(tester, intel, 1), '');

    await type(tester, ClassStatGrowthTab.cellKey(str, 2), '12');
    expect(dotVisible(tester, 'Stat Growth'), isTrue);

    // Fill column: the first manual stat (Strength) is preselected.
    await type(tester, ClassStatGrowthTab.fillValueKey, '5');
    await tap(tester, find.byKey(ClassStatGrowthTab.fillApplyKey));
    expect(cellText(tester, str, 1), '5');
    expect(cellText(tester, str, 10), '5');

    // Interpolate Strength from 0 at level 1 to 9 at level 10.
    await type(tester, ClassStatGrowthTab.interpFromValueKey, '0');
    await type(tester, ClassStatGrowthTab.interpToValueKey, '9');
    await tap(tester, find.byKey(ClassStatGrowthTab.interpApplyKey));
    expect(cellText(tester, str, 4), '3');

    await tap(tester, find.byKey(const ValueKey('editor-save')));
    final saved = h.classes.saved.single;
    expect(saved.statGrowthFormulas, isEmpty);
    expect(saved.statGrowth, {
      for (var l = 1; l <= 10; l++) StatGrowthKey(str, l): l - 1.0,
    });
    expect(dotVisible(tester, 'Stat Growth'), isFalse);
    await tester.pump(previewDebounce);
  }, variant: linux);

  testWidgets('the chart draws one straight line per stat in the series '
      'colours, and the legend toggles a line', (tester) async {
    final h = ClassHarness();
    await h.pump(tester, classEditor(warriorId));
    await openTab(tester, 'Stat Growth');

    LineChartData data() =>
        tester.widget<LineChart>(find.byKey(StatGrowthChart.chartKey)).data;
    final bars = data().lineBarsData;
    expect(bars, hasLength(2));
    expect([for (final b in bars) b.color], AnvilPalette.chartSeries.take(2));
    for (final b in bars) {
      expect(b.isCurved, isFalse);
      expect(b.barWidth, 2);
      expect(b.dotData.show, isFalse);
      expect(b.show, isTrue);
    }
    // Strength: 10 at level 1, empty (0) after; Intelligence: level * 2.
    expect(bars[0].spots.first, const FlSpot(1, 10));
    expect(bars[0].spots[1], const FlSpot(2, 0));
    expect(bars[1].spots.last, const FlSpot(10, 20));
    expect(data().gridData.getDrawingHorizontalLine(0).dashArray, [3, 3]);

    await tap(tester, find.byKey(StatGrowthChart.legendKey(intel)));
    expect(data().lineBarsData[1].show, isFalse);
    expect(data().lineBarsData[0].show, isTrue);
    await tap(tester, find.byKey(StatGrowthChart.legendKey(intel)));
    expect(data().lineBarsData[1].show, isTrue);

    // A manual edit reaches the chart.
    await type(tester, ClassStatGrowthTab.cellKey(str, 2), '14');
    expect(data().lineBarsData[0].spots[1], const FlSpot(2, 14));
    await tester.pump(previewDebounce);
  }, variant: linux);

  testWidgets('a max level change mid-edit redraws the grid and keeps the '
      'draft', (tester) async {
    final h = ClassHarness();
    await h.pump(tester, classEditor(warriorId));
    await openTab(tester, 'Stat Growth');
    await type(tester, ClassStatGrowthTab.cellKey(str, 2), '12');

    h.meta.maxLevel = 4;
    h.container.read(writeEpochProvider.notifier).bump();
    await tester.pumpAndSettle();
    expect(find.text('Primary Stat Growth — levels 1–4'), findsOneWidget);
    expect(find.byKey(ClassStatGrowthTab.cellKey(str, 5)), findsNothing);
    expect(cellText(tester, str, 2), '12');
    expect(cellText(tester, intel, 4), '8');
    expect(dotVisible(tester, 'Stat Growth'), isTrue);
    expect(h.classes.calls.where((c) => c.startsWith('load')), hasLength(1));
    await tester.pump(previewDebounce);
  }, variant: linux);

  testWidgets('Derived Stats: values in dependency order, an override with '
      'a syntax error disables Save, a runtime error saves, two overrides '
      'referencing each other show the cycle marker', (tester) async {
    final h = ClassHarness();
    h.classes.drafts[warriorId] = warriorDraft().copyWith(
      derivedStatOverrides: const {},
    );
    await h.pump(tester, classEditor(warriorId));
    await openTab(tester, 'Derived Stats');
    await tester.pump(previewDebounce);
    await tester.pumpAndSettle();

    expect(find.byKey(ClassDerivedStatsTab.tabKey), findsOneWidget);
    expect(markerText(tester, ClassDerivedStatsTab.resultKey(hpId)), '100');
    expect(markerText(tester, ClassDerivedStatsTab.resultKey(mpId)), '35');
    expect(dotVisible(tester, 'Derived Stats'), isFalse);

    // Switch on: the project formula to edit, then a syntax error.
    await tap(tester, find.byKey(ClassDerivedStatsTab.switchKey(hpId)));
    expect(
      tester
          .widget<EditableText>(
            editable(ClassDerivedStatsTab.overrideKey(hpId)),
          )
          .controller
          .text,
      'strength * 10',
    );
    expect(dotVisible(tester, 'Derived Stats'), isTrue);
    await type(tester, ClassDerivedStatsTab.overrideKey(hpId), 'con * ');
    expect(find.text(validateFormula('con * ')!), findsWidgets);
    expect(saveEnabled(tester), isFalse);

    // A runtime error (unknown variable) is a marker, not a blocker.
    await type(tester, ClassDerivedStatsTab.overrideKey(hpId), 'con * 2');
    expect(saveEnabled(tester), isTrue);
    await tester.pump(previewDebounce);
    await tester.pumpAndSettle();
    expect(markerText(tester, ClassDerivedStatsTab.resultKey(hpId)), 'error');
    // Mana depends on Health, so it has no value.
    expect(markerText(tester, ClassDerivedStatsTab.resultKey(mpId)), '—');

    // Two overrides referencing each other.
    await type(tester, ClassDerivedStatsTab.overrideKey(hpId), 'mp * 2');
    await tap(tester, find.byKey(ClassDerivedStatsTab.switchKey(mpId)));
    await type(tester, ClassDerivedStatsTab.overrideKey(mpId), 'hp + 1');
    await tester.pump(previewDebounce);
    await tester.pumpAndSettle();
    expect(markerText(tester, ClassDerivedStatsTab.resultKey(hpId)), 'cycle');
    expect(markerText(tester, ClassDerivedStatsTab.resultKey(mpId)), 'cycle');
    expect(
      markerText(tester, ClassDerivedStatsTab.breakpointKey(10, mpId)),
      'cycle',
    );
    expect(find.byTooltip(ClassDerivedStatsTab.cycleTooltip), findsWidgets);

    // Save writes both overrides with the class; switching one off
    // removes it.
    await tap(tester, find.byKey(const ValueKey('editor-save')));
    expect(h.classes.saved.single.derivedStatOverrides, {
      hpId: 'mp * 2',
      mpId: 'hp + 1',
    });
    await tap(tester, find.byKey(ClassDerivedStatsTab.switchKey(mpId)));
    expect(find.byKey(ClassDerivedStatsTab.overrideKey(mpId)), findsNothing);
    await tester.pump(previewDebounce);
  }, variant: linux);

  testWidgets('the breakpoint table starts at the default levels, adds a '
      'level in range once and removes one', (tester) async {
    final h = ClassHarness();
    h.classes.drafts[warriorId] = warriorDraft().copyWith(
      derivedStatOverrides: const {},
    );
    await h.pump(tester, classEditor(warriorId));
    await openTab(tester, 'Derived Stats');
    await tester.pump(previewDebounce);
    await tester.pumpAndSettle();

    for (final level in [1, 2, 4, 6, 8, 10]) {
      expect(find.text('Lvl $level'), findsOneWidget);
    }
    // Level 2: strength has no entry (0), intelligence 4.
    expect(
      markerText(tester, ClassDerivedStatsTab.breakpointKey(2, hpId)),
      '0',
    );
    expect(
      markerText(tester, ClassDerivedStatsTab.breakpointKey(2, mpId)),
      '20',
    );

    Finder addField() => find.descendant(
      of: find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(
              ClassDerivedStatsTab.addLevelKey.value,
            ),
      ),
      matching: find.byType(EditableText),
    );
    await tester.ensureVisible(addField());
    await tester.enterText(addField(), '3');
    await tester.pump();
    await tap(tester, find.byKey(ClassDerivedStatsTab.addLevelButtonKey));
    await tester.pump(previewDebounce);
    await tester.pumpAndSettle();
    expect(find.text('Lvl 3'), findsOneWidget);
    expect(
      markerText(tester, ClassDerivedStatsTab.breakpointKey(3, mpId)),
      '30',
    );
    // Out of range and repeated levels are ignored.
    for (final text in ['11', '3']) {
      await tester.enterText(addField(), text);
      await tester.pump();
      await tap(tester, find.byKey(ClassDerivedStatsTab.addLevelButtonKey));
    }
    expect(find.text('Lvl 11'), findsNothing);
    expect(find.text('Lvl 3'), findsOneWidget);

    for (final level in [1, 2, 3, 4, 6, 8, 10]) {
      await tap(tester, find.byKey(ClassDerivedStatsTab.removeLevelKey(level)));
    }
    expect(find.text('No breakpoint levels configured.'), findsOneWidget);
    await tester.pump(previewDebounce);
  }, variant: linux);

  testWidgets('both tabs lay out inside the editor dialog\'s scroll view', (
    tester,
  ) async {
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

    await openTab(tester, 'Stat Growth');
    expect(find.byKey(StatGrowthChart.chartKey), findsOneWidget);
    await type(tester, ClassStatGrowthTab.cellKey(str, 2), '12');
    expect(dotVisible(tester, 'Stat Growth'), isTrue);
    await tester.ensureVisible(find.widgetWithText(Tab, 'Derived Stats'));
    await tester.pumpAndSettle();
    await openTab(tester, 'Derived Stats');
    await tester.pump(previewDebounce);
    await tester.pumpAndSettle();
    expect(find.byKey(ClassDerivedStatsTab.resultKey(hpId)), findsOneWidget);
    expect(find.text('Breakpoint Table'), findsOneWidget);
    await tester.pump(previewDebounce);
  }, variant: linux);
}
