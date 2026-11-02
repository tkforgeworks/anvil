import 'package:anvil/app/domains/classes/classes_editor_controller.dart';
import 'package:anvil/app/editor/clock.dart';
import 'package:anvil/app/editor/editor_state.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../dialogs/fakes.dart' show copyFixture;
import 'class_fakes.dart';

const invalidKeyMessage =
    'Letters, digits, underscores only. Must start with a letter.';

void main() {
  group('over the fake repository', () {
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
      await h.container.read(editor.future);
    });

    test('loads the record through the repository as a clean draft', () {
      expect(s().draft, warriorDraft());
      expect(s().isDirty, isFalse);
      expect(s().blockers, isEmpty);
      expect(h.classes.calls, ['load $warriorId']);
    });

    test('assignment add, reorder and remove are one undo step each, '
        'undone one at a time', () {
      final seen = <List<String>>[s().draft.abilityIds];
      for (final step in <void Function()>[
        () => c().addAbility(retiredId),
        () => c().moveAbility(2, 0),
        () => c().removeAbility(slashId),
      ]) {
        step();
        seen.add(s().draft.abilityIds);
      }
      expect(seen, [
        [slashId, fireballId],
        [slashId, fireballId, retiredId],
        [retiredId, slashId, fireballId],
        [retiredId, fireballId],
      ]);
      for (final expected in seen.reversed.skip(1)) {
        c().undo();
        expect(s().draft.abilityIds, expected);
      }
      expect(s().isDirty, isFalse);
      expect(s().canUndo, isFalse);
      c().redo();
      expect(s().draft.abilityIds, seen[1]);
    });

    test('a repeated add, an unknown remove and out-of-range moves change '
        'nothing', () {
      c().addAbility(slashId);
      c().removeAbility(retiredId);
      c().moveAbility(0, 0);
      c().moveAbility(0, 2);
      c().moveAbility(-1, 0);
      c().removeMetadataField(3);
      c().setMetadataKey(3, 'x');
      expect(s().isDirty, isFalse);
      expect(s().canUndo, isFalse);
    });

    test(
      'a non-identifier metadata key blocks Save with 0.1.6\'s reason',
      () async {
        c().setMetadataKey(0, 'a-b');
        expect(s().blockers, [
          const SaveBlocker('metadataFields[0].fieldKey', invalidKeyMessage),
        ]);
        expect(s().canSave, isFalse);
        expect(await c().save(), SaveOutcome.blocked);
        expect(h.classes.calls, isNot(contains('save $warriorId')));
      },
    );

    test('a new metadata row starts empty at 0 and blocks until keyed', () {
      c().addMetadataField();
      expect(
        s().draft.metadataFields.last,
        const ClassMetadataField(fieldKey: '', value: 0),
      );
      expect(s().blockers.single.field, 'metadataFields[1].fieldKey');
      c().setMetadataKey(1, 'base_speed');
      expect(
        s().blockers.single.message,
        'Metadata field key "base_speed" is used more than once.',
      );
      c().setMetadataKey(1, 'base_speed2');
      expect(s().blockers, isEmpty);
      wait(600);
      c().removeMetadataField(1);
      expect(s().isDirty, isFalse);
    });

    test('typing coalesces per field and per metadata row', () {
      c().setDescription('A');
      wait(100);
      c().setDescription('AB');
      wait(100);
      c().setResourceMultiplier(2);
      wait(100);
      c().setResourceMultiplier(2.5);
      wait(100);
      c().setMetadataValue(0, 5);
      wait(100);
      c().setMetadataValue(0, 55);
      wait(100);
      c().setMetadataKey(0, 'speed');
      expect(
        s().draft.metadataFields.single,
        const ClassMetadataField(fieldKey: 'speed', value: 55),
      );
      c().undo();
      expect(s().draft.metadataFields.single.fieldKey, 'base_speed');
      expect(s().draft.metadataFields.single.value, 55);
      c().undo();
      expect(s().draft.metadataFields.single.value, 4);
      c().undo();
      expect(s().draft.resourceMultiplier, 1.25);
      c().undo();
      expect(s().draft.description, 'A sturdy fighter.');
      expect(s().isDirty, isFalse);
    });

    test('save trims the text fields, carries the ANVL-196 fields through, '
        'rebases and bumps the epoch once', () async {
      c().setDisplayName('  Warrior II ');
      c().setExportKey(' warrior2 ');
      c().setDescription(' Tough. ');
      c().addAbility(retiredId);
      final before = h.epoch;
      expect(await c().save(), SaveOutcome.saved);
      expect(h.epoch, before + 1);
      final saved = h.classes.saved.single;
      expect(saved.displayName, 'Warrior II');
      expect(saved.exportKey, 'warrior2');
      expect(saved.description, 'Tough.');
      expect(saved.abilityIds, [slashId, fireballId, retiredId]);
      final original = warriorDraft();
      expect(saved.statGrowth, original.statGrowth);
      expect(saved.statGrowthFormulas, original.statGrowthFormulas);
      expect(saved.derivedStatOverrides, original.derivedStatOverrides);
      expect(s().isDirty, isFalse);
      expect(s().canUndo, isTrue);
    });

    test('a failed save keeps the draft with the message', () async {
      c().setDescription('x');
      h.classes.saveError = const DuplicateExportKey('warrior');
      expect(await c().save(), SaveOutcome.failed);
      expect(s().isDirty, isTrue);
      expect(s().saveError, contains('warrior'));
    });

    test('duplicate copies the saved class and bumps the epoch', () async {
      final copy = await c().duplicate();
      expect(copy.displayName, 'Warrior (Copy)');
      expect(h.epoch, 1);
    });
  });

  test('over the real repository, save writes one history row and the '
      'ability order', () async {
    final db = ProjectDatabase.open(copyFixture());
    addTearDown(db.close);
    final repository = SqliteClassRepository(db);
    final container = ProviderContainer.test(
      overrides: [classRepositoryProvider.overrideWithValue(repository)],
      retry: (_, _) => null,
    );
    final mage = (await repository.list()).firstWhere(
      (r) => r.displayName == 'Mage',
    );
    final editor = classEditorProvider(mage.id);
    container.listen(editor, (_, _) {});
    await container.read(editor.future);
    final controller = container.read(editor.notifier);
    final before = readRecentSaves(db, limit: 100);
    final original = container.read(editor).requireValue.draft;
    expect(original.abilityIds, hasLength(2));

    controller.moveAbility(1, 0);
    controller.addMetadataField();
    controller.setMetadataKey(0, 'mana_bonus');
    controller.setMetadataValue(0, 1.5);
    controller.setResourceMultiplier(0.9);
    expect(await controller.save(), SaveOutcome.saved);

    final after = readRecentSaves(db, limit: 100);
    expect(after.length, before.length + 1);
    expect(
      after.where((e) => e.description == 'Mage - Class changed'),
      hasLength(1),
    );
    final stored = await repository.load(mage.id);
    expect(stored.abilityIds, original.abilityIds.reversed.toList());
    expect(stored.metadataFields, const [
      ClassMetadataField(fieldKey: 'mana_bonus', value: 1.5),
    ]);
    expect(stored.resourceMultiplier, 0.9);
    expect(container.read(editor).requireValue.draft, stored);
    expect(container.read(writeEpochProvider), 1);
  });
}
