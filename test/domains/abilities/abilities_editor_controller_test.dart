import 'dart:io';

import 'package:anvil/app/editor/clock.dart';
import 'package:anvil/app/editor/editor_state.dart';
import 'package:anvil/app/providers.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil/app/domains/abilities/abilities_editor_controller.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../dialogs/fakes.dart' show copyFixture;
import 'fakes.dart';

void main() {
  group('over the fake repository', () {
    late FakeAbilityRepository repository;
    late ProviderContainer container;
    late DateTime now;

    final editor = abilitiesEditorProvider(fireballId);
    AbilityEditorController controller() => container.read(editor.notifier);
    EditorState<AbilityDraft> state() => container.read(editor).requireValue;
    void wait(int ms) => now = now.add(Duration(milliseconds: ms));

    setUp(() async {
      repository = FakeAbilityRepository();
      now = DateTime(2026, 11, 1, 12);
      container = ProviderContainer.test(
        overrides: [
          abilityRepositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(() => now),
        ],
        retry: (_, _) => null,
      );
      container.listen(editor, (_, _) {});
      await container.read(editor.future);
    });

    test('loads the ability as a clean draft', () {
      expect(state().draft, draftOf(repository.byId(fireballId)));
      expect(state().isDirty, isFalse);
      expect(state().blockers, isEmpty);
    });

    test('every field has an intent, and undo walks each one back', () {
      final c = controller();
      c.setDisplayName('Fire Bolt');
      wait(600);
      c.setExportKey('fire_bolt');
      wait(600);
      c.setDescription('Hot.');
      wait(600);
      c.setAbilityType('ultimate');
      wait(600);
      c.setResourceType('rage');
      wait(600);
      c.setResourceCost(4.5);
      wait(600);
      c.setCooldown(0);
      wait(600);
      c.setStatModifier('stat-str', 2);

      expect(
        state().draft,
        AbilityDraft(
          displayName: 'Fire Bolt',
          exportKey: 'fire_bolt',
          description: 'Hot.',
          abilityType: 'ultimate',
          resourceType: 'rage',
          resourceCost: 4.5,
          cooldown: 0,
          statModifiers: const {'stat-int': 3, 'stat-str': 2},
        ),
      );
      expect(state().history.past, hasLength(8));
      for (var i = 0; i < 8; i++) {
        c.undo();
      }
      expect(state().draft, draftOf(repository.byId(fireballId)));
      expect(state().isDirty, isFalse);
    });

    test('typing in one field within 500 ms is one undo step', () {
      controller().setResourceType('m');
      wait(100);
      controller().setResourceType('ma');
      wait(100);
      controller().setResourceType('man');
      expect(state().history.past, hasLength(1));
    });

    test('a zero or empty modifier removes the stat from the map', () {
      controller().setStatModifier('stat-int', 0);
      expect(state().draft.statModifiers, isEmpty);
      controller().setStatModifier('stat-str', 1.5);
      wait(600);
      controller().setStatModifier('stat-str', null);
      expect(state().draft.statModifiers, isEmpty);
    });

    test('an empty name or key blocks the save with the core messages', () {
      controller().setDisplayName('  ');
      controller().setExportKey('');
      expect(state().blockers.map((b) => b.message), [
        'Display name is required.',
        'Export key is required.',
      ]);
      expect(state().canSave, isFalse);
    });

    test('save trims the text fields, as 0.1.6 did, and lands clean', () async {
      controller().setDisplayName('  Fire Bolt ');
      wait(600);
      controller().setAbilityType(' active ');
      expect(await controller().save(), SaveOutcome.saved);
      expect(repository.saved.single.displayName, 'Fire Bolt');
      expect(repository.saved.single.abilityType, 'active');
      expect(state().draft.displayName, 'Fire Bolt');
      expect(state().isDirty, isFalse);
      expect(container.read(writeEpochProvider), 1);
    });

    test('a failed save keeps the draft and shows the message', () async {
      repository.saveError = DuplicateExportKey('slash');
      controller().setExportKey('slash');
      expect(await controller().save(), SaveOutcome.failed);
      expect(state().draft.exportKey, 'slash');
      expect(state().isDirty, isTrue);
      expect(
        state().saveError,
        'The export key "slash" is already used by another record.',
      );
    });

    test(
      'duplicate copies the saved ability and bumps the epoch once',
      () async {
        final copy = await controller().duplicate();
        expect(copy.displayName, 'Fireball (Copy)');
        expect(repository.calls, contains('duplicate $fireballId'));
        expect(container.read(writeEpochProvider), 1);
      },
    );
  });

  test(
    'a save over SQLite writes the ability and one save_history row',
    () async {
      final path = copyFixture();
      final support = Directory.systemTemp.createTempSync('anvil-support');
      addTearDown(() => support.deleteSync(recursive: true));
      final service = ProjectService(supportDirectory: support.path);
      final session = switch (await service.open(path)) {
        ProjectOpened(:final session) => session,
        final other => throw StateError('fixture did not open: $other'),
      };
      addTearDown(() async {
        if (session.isOpen) await service.close(session);
      });
      final container = ProviderContainer.test(retry: (_, _) => null);
      container.read(projectSessionProvider.notifier).set(session);

      final fireball = (await session.abilities.list()).firstWhere(
        (a) => a.exportKey == 'fireball',
      );
      final before = await session.saveHistory.recent(limit: 50);

      final provider = abilitiesEditorProvider(fireball.id);
      container.listen(provider, (_, _) {});
      await container.read(provider.future);
      final controller = container.read(provider.notifier);
      controller.setResourceType('focus');
      controller.setCooldown(3.5);
      controller.setStatModifier('stat-wisdom', 2);

      expect(await controller.save(), SaveOutcome.saved);

      final stored = await session.abilities.load(fireball.id);
      expect(stored.resourceType, 'focus');
      expect(stored.cooldown, 3.5);
      expect(stored.statModifiers['stat-wisdom'], 2);
      final after = await session.saveHistory.recent(limit: 50);
      expect(after.length, before.length + 1);
      final added = after
          .where((e) => !before.any((b) => b.id == e.id))
          .toList();
      expect(added, hasLength(1));
      expect(added.single.description, 'Fireball - Ability changed');
      expect(container.read(provider).requireValue.isDirty, isFalse);
      container.dispose();
    },
  );
}
