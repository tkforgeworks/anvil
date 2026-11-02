import 'package:anvil/app/domains/classes/classes_editor_controller.dart';
import 'package:anvil/app/domains/classes/classes_growth_math.dart';
import 'package:anvil/app/domains/classes/classes_growth_providers.dart';
import 'package:anvil/app/editor/clock.dart';
import 'package:anvil/app/editor/editor_state.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../dialogs/fakes.dart' show copyFixture;
import 'class_fakes.dart';
import 'growth_fakes.dart';

const str = 'stat-str';
const intel = 'stat-int';

StatGrowthKey k(String stat, int level) => StatGrowthKey(stat, level);

/// `level * 2` for levels 1 to [maxLevel].
List<double> doubled(int maxLevel) => [
  for (var l = 1; l <= maxLevel; l++) l * 2.0,
];

void main() {
  group('stat growth and override intents', () {
    late ClassHarness h;
    late DateTime now;
    final editor = classEditorProvider(warriorId);
    ClassEditorController c() => h.container.read(editor.notifier);
    EditorState<ClassDraft> s() => h.container.read(editor).requireValue;
    void wait(int ms) => now = now.add(Duration(milliseconds: ms));

    setUp(() async {
      h = ClassHarness();
      now = DateTime(2026, 11, 1, 12);
      h.build(overrides: [clockProvider.overrideWithValue(() => now)]);
      h.container.listen(editor, (_, _) {});
      // The tabs keep the max level loaded; the intents read it.
      h.container.listen(classMaxLevelProvider, (_, _) {});
      await h.container.read(editor.future);
      await h.container.read(classMaxLevelProvider.future);
    });

    test('a cell edit coalesces per cell, an emptied cell removes the '
        'entry, and each cell is its own undo step', () {
      c().setStatGrowthValue(str, 2, 1);
      wait(100);
      c().setStatGrowthValue(str, 2, 12);
      wait(100);
      c().setStatGrowthValue(str, 1, null);
      expect(s().draft.statGrowth, {k(str, 2): 12});
      c().undo();
      expect(s().draft.statGrowth, {k(str, 1): 10, k(str, 2): 12});
      c().undo();
      expect(s().draft.statGrowth, {k(str, 1): 10});
      expect(s().isDirty, isFalse);
    });

    test('M → F → M with Keep bakes the computed values, and undo steps '
        'back one intent at a time', () {
      c().switchToFormula(str);
      expect(s().draft.statGrowthFormulas, {intel: 'level * 2', str: ''});
      // The empty formula blocks Save (ANVL-164); manual entries stay.
      expect(s().blockers.map((b) => (b.field, b.message)), [
        ('statGrowthFormulas.$str', 'Stat growth formula is required.'),
      ]);
      expect(s().draft.statGrowth, {k(str, 1): 10});
      wait(600);
      c().setStatGrowthFormula(str, 'level');
      wait(100);
      c().setStatGrowthFormula(str, 'level + 5');
      expect(s().blockers, isEmpty);
      wait(600);
      c().switchToManual(str, keep: true);
      expect(s().draft.statGrowthFormulas, {intel: 'level * 2'});
      expect(s().draft.statGrowth, {
        for (var l = 1; l <= 10; l++) k(str, l): l + 5.0,
      });

      c().undo();
      expect(s().draft.statGrowthFormulas[str], 'level + 5');
      expect(s().draft.statGrowth, {k(str, 1): 10});
      c().undo();
      expect(s().draft.statGrowthFormulas[str], '');
      c().undo();
      expect(s().draft.statGrowthFormulas, {intel: 'level * 2'});
      expect(s().isDirty, isFalse);
    });

    test('Clear Values removes the formula and every manual entry of the '
        'stat', () {
      c().setStatGrowthValue(intel, 3, 7);
      wait(600);
      c().switchToManual(intel, keep: false);
      expect(s().draft.statGrowthFormulas, isEmpty);
      expect(s().draft.statGrowth, {k(str, 1): 10});
      c().undo();
      expect(s().draft.statGrowthFormulas, {intel: 'level * 2'});
      expect(s().draft.statGrowth[k(intel, 3)], 7);
    });

    test('Keep Values on a formula failing at level 1 leaves the manual '
        'entries as they are', () {
      c().setStatGrowthValue(intel, 3, 7);
      wait(600);
      c().setStatGrowthFormula(intel, 'nope * 2');
      wait(600);
      c().switchToManual(intel, keep: true);
      expect(s().draft.statGrowthFormulas, isEmpty);
      expect(s().draft.statGrowth, {k(str, 1): 10, k(intel, 3): 7});
    });

    test('fill and interpolate are one undo step each over 1..max level '
        'and skip formula stats', () {
      c().fillColumn(str, 4);
      expect(s().draft.statGrowth, {
        for (var l = 1; l <= 10; l++) k(str, l): 4,
      });
      c().interpolate(str, 2, 1, 5, 2);
      expect(
        [for (var l = 1; l <= 6; l++) s().draft.statGrowth[k(str, l)]],
        [4, 1, 1.333, 1.667, 2, 4],
      );
      // Clipped at max level, and from >= to does nothing.
      c().interpolate(str, 9, 0, 12, 30);
      expect(s().draft.statGrowth[k(str, 10)], 10);
      expect(s().draft.statGrowth.containsKey(k(str, 11)), isFalse);
      final before = s().draft;
      c().interpolate(str, 5, 0, 5, 1);
      c().fillColumn(intel, 9);
      c().interpolate(intel, 1, 0, 10, 9);
      expect(s().draft, same(before));

      c().undo();
      expect(s().draft.statGrowth[k(str, 2)], 1);
      c().undo();
      expect(s().draft.statGrowth[k(str, 2)], 4);
      c().undo();
      expect(s().isDirty, isFalse);
    });

    test('an override typed is coalesced, the switch is its own step, '
        'and empty text is kept as a blocker', () {
      c().setDerivedOverride(mpId, 'intelligence', typing: false);
      wait(100);
      c().setDerivedOverride(mpId, 'intelligence * 3');
      wait(100);
      c().setDerivedOverride(mpId, '');
      expect(s().draft.derivedStatOverrides[mpId], '');
      expect(s().blockers.map((b) => (b.field, b.message)), [
        ('derivedStatOverrides.$mpId', 'Formula is empty'),
      ]);
      c().undo();
      expect(s().draft.derivedStatOverrides[mpId], 'intelligence');
      c().undo();
      expect(s().draft.derivedStatOverrides.containsKey(mpId), isFalse);
      wait(600);
      c().setDerivedOverride(hpId, null, typing: false);
      expect(s().draft.derivedStatOverrides, isEmpty);
    });

    test('an override with a syntax error blocks Save with the engine '
        'message; a runtime error saves', () async {
      c().setDerivedOverride(hpId, 'con * ');
      expect(s().canSave, isFalse);
      expect(s().blockers.single.field, 'derivedStatOverrides.$hpId');
      expect(s().blockers.single.message, validateFormula('con * '));
      expect(await c().save(), SaveOutcome.blocked);

      wait(600);
      c().setDerivedOverride(hpId, 'con * 2');
      expect(
        evaluateFormula('con * 2', const {}).error,
        isNotNull,
        reason: 'con is unbound, so the formula fails at runtime',
      );
      expect(s().blockers, isEmpty);
      expect(await c().save(), SaveOutcome.saved);
      expect(h.classes.saved.single.derivedStatOverrides[hpId], 'con * 2');
    });

    test('a growth, formula and override edit save in one save with the '
        'class', () async {
      c().setStatGrowthValue(str, 2, 11);
      c().setStatGrowthFormula(intel, 'level * 3');
      c().setDerivedOverride(mpId, 'intelligence', typing: false);
      expect(await c().save(), SaveOutcome.saved);
      expect(h.classes.calls.where((x) => x.startsWith('save')), [
        'save $warriorId',
      ]);
      final saved = h.classes.saved.single;
      expect(saved.statGrowth, {k(str, 1): 10, k(str, 2): 11});
      expect(saved.statGrowthFormulas, {intel: 'level * 3'});
      expect(saved.derivedStatOverrides, {
        hpId: 'level * 12',
        mpId: 'intelligence',
      });
    });

    test('a max level change mid-edit keeps the draft and its history, and '
        'the intents use the new max level', () async {
      c().setStatGrowthValue(str, 2, 11);
      final draft = s().draft;
      h.meta.maxLevel = 4;
      h.container.read(writeEpochProvider.notifier).bump();
      expect(await h.container.read(classMaxLevelProvider.future), 4);
      expect(s().draft, same(draft));
      expect(s().canUndo, isTrue);
      expect(h.classes.calls.where((x) => x.startsWith('load')), [
        'load $warriorId',
      ]);
      c().fillColumn(str, 1);
      expect(
        s().draft.statGrowth.keys.where((key) => key.statId == str).length,
        4,
      );
      c().undo();
      expect(s().draft, same(draft));
    });
  });

  group('previews', () {
    final preview = statGrowthPreviewProvider(warriorId);
    final derived = derivedStatPreviewProvider(warriorId);

    Future<ClassHarness> start(
      WidgetTester tester, {
      List overrides = const [],
    }) async {
      final h = ClassHarness();
      h.build(overrides: overrides);
      h.container.listen(preview, (_, _) {});
      h.container.listen(derived, (_, _) {});
      await tester.pump();
      await tester.pump();
      return h;
    }

    testWidgets('the growth preview evaluates on open, then 300 ms after the '
        'last formula change', (tester) async {
      final h = await start(tester);
      expect(h.container.read(preview), {
        intel: GrowthPreview(values: doubled(10)),
      });

      final c = h.container.read(classEditorProvider(warriorId).notifier);
      c.setStatGrowthFormula(intel, 'level * ');
      await tester.pump(const Duration(milliseconds: 200));
      c.setStatGrowthFormula(intel, 'level * 3');
      await tester.pump(const Duration(milliseconds: 299));
      expect(h.container.read(preview)[intel]!.at(10), 20);
      await tester.pump(const Duration(milliseconds: 1));
      expect(h.container.read(preview)[intel]!.at(10), 30);

      // A formula failing at level 1 shows its error over the last values.
      c.setStatGrowthFormula(intel, 'level * nope');
      await tester.pump(previewDebounce);
      final failed = h.container.read(preview)[intel]!;
      expect(failed.error, contains('nope'));
      expect(failed.at(10), 30);

      // A new stat in formula mode gets its own entry.
      c.switchToFormula(str);
      c.setStatGrowthFormula(str, 'max_level - level');
      await tester.pump(previewDebounce);
      expect(h.container.read(preview)[str]!.values!.first, 9);
      await tester.pump(previewDebounce);
    });

    testWidgets('the growth preview follows the max level at once', (
      tester,
    ) async {
      final h = await start(tester);
      h.meta.maxLevel = 3;
      h.container.read(writeEpochProvider.notifier).bump();
      // Riverpod refreshes on a zero-length timer, which only an
      // elapsing pump fires.
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(h.container.read(preview)[intel]!.values, doubled(3));
      await tester.pump(previewDebounce);
    });

    test('a batch at the isolate threshold returns what the in-process '
        'path returns', () async {
      Future<GrowthPreview> run(int threshold) async {
        final h = ClassHarness();
        h.meta.maxLevel = 50;
        h.build(
          overrides: [
            growthBatchThresholdProvider.overrideWithValue(threshold),
          ],
        );
        h.container.listen(preview, (_, _) {});
        for (var i = 0; i < 200; i++) {
          final p = h.container.read(preview)[intel];
          if (p != null) return p;
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        fail('no preview');
      }

      final isolate = await run(1);
      final inProcess = await run(isolateThreshold);
      expect(isolate.values, doubled(50));
      expect(isolate, inProcess);
    });

    testWidgets('derived previews evaluate in dependency order with the '
        "grid's values, and mark a cycle of two overrides", (tester) async {
      final h = ClassHarness();
      h.classes.drafts[warriorId] = warriorDraft().copyWith(
        derivedStatOverrides: const {},
      );
      h.build();
      h.container.listen(preview, (_, _) {});
      h.container.listen(derived, (_, _) {});
      await tester.pump();
      await tester.pump();
      await tester.pump(previewDebounce);
      var d = h.container.read(derived);
      expect(d.ready, isTrue);
      expect(d.cyclicIds, isEmpty);
      // Level 1: strength 10 (manual), intelligence 2 (formula).
      expect(d.result(1, hpId)!.value, 100);
      expect(d.result(1, mpId)!.value, 2 * 5 + 100 / 4);
      // Level 10: strength has no entry (0), intelligence 20.
      expect(d.result(10, hpId)!.value, 0);
      expect(d.result(10, mpId)!.value, 100);
      // The default breakpoints of max level 10.
      expect(d.byLevel.keys.toSet(), {1, 2, 4, 6, 8, 10});

      final c = h.container.read(classEditorProvider(warriorId).notifier);
      c.setDerivedOverride(hpId, 'mp * 2', typing: false);
      c.setDerivedOverride(mpId, 'hp + 1', typing: false);
      await tester.pump(const Duration(milliseconds: 299));
      expect(h.container.read(derived).cyclicIds, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      d = h.container.read(derived);
      expect(d.cyclicIds, {hpId, mpId});
      expect(d.result(1, hpId), isNull);

      // A runtime error is a result with an error; its dependent has none.
      c.setDerivedOverride(mpId, null, typing: false);
      c.setDerivedOverride(hpId, 'nope + 1', typing: false);
      await tester.pump(previewDebounce);
      d = h.container.read(derived);
      expect(d.cyclicIds, isEmpty);
      expect(d.result(1, hpId)!.error, isNotNull);
      expect(d.result(1, mpId), isNull);
      await tester.pump(previewDebounce);
    });
  });

  group('pure rules', () {
    test('jsRound rounds halves up like Math.round', () {
      expect(jsRound(2.5), 3);
      expect(jsRound(-2.5), -2);
      expect(jsRound(-2.6), -3);
      expect(jsRound(0.49999999999999994), 0);
    });

    test('0.1.6 defaultBreakpointLevels', () {
      expect(defaultBreakpointLevels(3), [1, 2, 3]);
      expect(defaultBreakpointLevels(100), [1, 20, 40, 60, 80, 100]);
      expect(defaultBreakpointLevels(7), [1, 3, 4, 6, 7]);
    });

    test('formatDerivedValue follows formatResult over applyOutputConfig', () {
      const integer = DerivedStatDefinition(
        id: 'a',
        displayName: 'A',
        exportKey: 'a',
        formula: '1',
        outputType: DerivedStatOutputType.integer,
        roundingMode: RoundingMode.floor,
        sortOrder: 1,
      );
      expect(formatDerivedValue(integer, 12.9), '12');
      expect(formatDerivedValue(sampleDerivedStats[1], 12.5), '12.5');
      expect(formatDerivedValue(sampleDerivedStats[1], 10), '10');
      expect(formatDerivedValue(sampleDerivedStats[1], 1 / 3), '0.333');
    });
  });

  test('over the real repository, the growth tab edits save in one '
      'history row', () async {
    final db = ProjectDatabase.open(copyFixture());
    addTearDown(db.close);
    final repository = SqliteClassRepository(db);
    final meta = SqliteMetaRepository(db);
    final container = ProviderContainer.test(
      overrides: [
        classRepositoryProvider.overrideWithValue(repository),
        metaRepositoryProvider.overrideWithValue(meta),
      ],
      retry: (_, _) => null,
    );
    final mage = (await repository.list()).firstWhere(
      (r) => r.displayName == 'Mage',
    );
    final stats = await meta.listStats();
    final derivedStats = await meta.listDerivedStats();
    final editor = classEditorProvider(mage.id);
    container.listen(editor, (_, _) {});
    container.listen(classMaxLevelProvider, (_, _) {});
    await container.read(editor.future);
    final maxLevel = await container.read(classMaxLevelProvider.future);
    final controller = container.read(editor.notifier);
    final before = readRecentSaves(db, limit: 100);

    final stat = stats.first.id;
    controller.switchToManual(stat, keep: false);
    controller.fillColumn(stat, 3);
    controller.setDerivedOverride(
      derivedStats.first.id,
      '${stats.first.exportKey} * 4',
      typing: false,
    );
    expect(await controller.save(), SaveOutcome.saved);

    final after = readRecentSaves(db, limit: 100);
    expect(after.length, before.length + 1);
    expect(after.first.description, 'Mage - Class changed');
    final stored = await repository.load(mage.id);
    expect(
      stored.statGrowth.entries.where((e) => e.key.statId == stat).length,
      maxLevel,
    );
    expect(stored.statGrowthFormulas.containsKey(stat), isFalse);
    expect(
      stored.derivedStatOverrides[derivedStats.first.id],
      '${stats.first.exportKey} * 4',
    );
  });
}
