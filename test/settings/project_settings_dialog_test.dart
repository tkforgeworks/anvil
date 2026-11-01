import 'package:anvil/app/settings/project/project_settings_controller.dart';
import 'package:anvil/app/settings/project/project_settings_dialog.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../dialogs/fakes.dart' show copyFixture;
import 'fakes.dart';

final linux = TargetPlatformVariant.only(TargetPlatform.linux);

void main() {
  late FakeMetaRepository meta;
  late FakeCustomFieldRepository fields;
  late ProviderContainer container;
  late EpochCounter epoch;

  setUp(() {
    meta = FakeMetaRepository();
    fields = FakeCustomFieldRepository();
    container = ProviderContainer.test(
      overrides: settingsOverrides(meta, fields),
      retry: (_, _) => null,
    );
    epoch = EpochCounter(container);
  });

  final dialog = find.byType(ProjectSettingsDialog);
  Finder key(String k) => find.byKey(ValueKey(k));

  bool saveEnabled(WidgetTester tester) =>
      tester.widget<ButtonStyleButton>(key('project-settings-save')).enabled;

  /// Pumps a page with an Open button that shows the dialog, and opens it.
  Future<void> open(
    WidgetTester tester, {
    ProjectSettingsTab initialTab = ProjectSettingsTab.general,
  }) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      settingsTestApp(
        container,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => ProjectSettingsDialog(initialTab: initialTab),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> tab(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(Tab, label));
    await tester.pumpAndSettle();
  }

  /// The row action [tooltip] of the table row for [id].
  Finder action(String id, String tooltip) => find.descendant(
    of: key('meta-row-$id'),
    matching: find.byTooltip(tooltip),
  );

  /// Scrolls the row action into view and taps it.
  Future<void> tapAction(WidgetTester tester, String id, String tooltip) async {
    final target = action(id, tooltip);
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  /// Scrolls [target] into view and taps it.
  Future<void> tapVisible(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> fillRowDialog(
    WidgetTester tester, {
    String? name,
    String? exportKey,
  }) async {
    if (name != null) {
      await tester.enterText(key('meta-row-name'), name);
    }
    if (exportKey != null) {
      await tester.enterText(key('meta-row-key'), exportKey);
    }
    await tester.pump();
    await tester.tap(key('meta-row-dialog-submit'));
    await tester.pumpAndSettle();
  }

  testWidgets('load shows the scalars and the buffered lists', (tester) async {
    await open(tester);
    expect(dialog, findsOneWidget);
    expect(find.text('Project Settings'), findsOneWidget);
    expect(find.text('Spike Fixture'), findsOneWidget);
    expect(find.text('/projects/Spike Fixture'), findsOneWidget);
    expect(
      find.descendant(
        of: key('settings-game-title'),
        matching: find.text('Forge & Fable'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: key('settings-max-level'), matching: find.text('20')),
      findsOneWidget,
    );
    final group = tester.widget<RadioGroup<SoftDeleteReferenceSeverity>>(
      find.byType(RadioGroup<SoftDeleteReferenceSeverity>),
    );
    expect(group.groupValue, SoftDeleteReferenceSeverity.warning);
    expect(find.text('Rarities'), findsOneWidget);
    expect(find.text('Common'), findsOneWidget);
    expect(find.text('Rare'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);

    await tab(tester, 'Stats & Formulas');
    expect(find.text('Primary Stats'), findsOneWidget);
    expect(find.text('Strength'), findsOneWidget);
    expect(find.text('Constitution'), findsOneWidget);
    expect(find.text('Max HP'), findsOneWidget);
    expect(find.text('con * 10'), findsOneWidget);

    await tab(tester, 'Crafting');
    expect(find.text('Forge'), findsOneWidget);
    expect(find.text('Blacksmithing'), findsOneWidget);
    expect(meta.calls, ['loadProjectSettings']);
  }, variant: linux);

  testWidgets('edits across the buffered tabs land in one save, which bumps '
      'the epoch once and closes the dialog', (tester) async {
    await open(tester);

    // General: the title and a rarity move.
    await tester.enterText(key('settings-game-title'), 'Forge & Fable II');
    await tapAction(tester, 'rarity-rare', 'Move up');

    // Stats & Formulas: add, edit, delete.
    await tab(tester, 'Stats & Formulas');
    await tester.tap(
      find.descendant(
        of: key('section-stats'),
        matching: find.widgetWithText(OutlinedButton, 'Add'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Add Stat'), findsOneWidget);
    await fillRowDialog(tester, name: 'Dexterity');
    expect(find.text('Dexterity'), findsOneWidget);
    expect(find.text('dexterity'), findsOneWidget, reason: 'auto key');

    await tapAction(tester, 'stat-con', 'Edit');
    expect(find.text('Edit Stat'), findsOneWidget);
    await fillRowDialog(tester, name: 'Vitality');
    expect(find.text('Vitality'), findsOneWidget);

    await tapAction(tester, 'stat-str', 'Delete');
    expect(find.text('Strength'), findsNothing);

    // Crafting: a new station.
    await tab(tester, 'Crafting');
    await tester.tap(
      find.descendant(
        of: key('section-craftingStations'),
        matching: find.widgetWithText(OutlinedButton, 'Add'),
      ),
    );
    await tester.pumpAndSettle();
    await fillRowDialog(tester, name: 'Loom', exportKey: 'loom');

    expect(saveEnabled(tester), isTrue);
    expect(meta.saved, isEmpty, reason: 'nothing is written before Save');
    expect(epoch.bumps, 0);

    await tester.tap(key('project-settings-save'));
    await tester.pumpAndSettle();

    expect(meta.calls.where((c) => c == 'saveProjectSettings'), hasLength(1));
    final draft = meta.saved.single;
    expect(draft.gameTitle, 'Forge & Fable II');
    expect(draft.maxLevel, 20);
    expect(
      [for (final r in draft.rarities) r.id],
      ['rarity-rare', 'rarity-common'],
    );
    expect(
      [for (final r in draft.stats) r.displayName],
      ['Vitality', 'Dexterity'],
    );
    expect(draft.stats[0].id, 'stat-con');
    expect(draft.stats[0].exportKey, 'con', reason: 'a touched key stays');
    expect(isNewMetaId(draft.stats[1].id), isTrue);
    expect(draft.stats[1].exportKey, 'dexterity');
    expect(
      [for (final r in draft.craftingStations) r.exportKey],
      ['forge', 'loom'],
    );
    expect(draft.derivedStats, sampleSettings().derivedStats);
    expect(epoch.bumps, 1);
    expect(dialog, findsNothing);
    expect(meta.calls, contains('checkInUse stat stat-str'));
  }, variant: linux);

  testWidgets('Cancel after edits writes nothing, and reopening shows the '
      'stored values', (tester) async {
    await open(tester);
    await tester.enterText(key('settings-game-title'), 'Changed');
    await tapVisible(tester, find.text('Error'));
    await tapAction(tester, 'rarity-rare', 'Move up');
    expect(saveEnabled(tester), isTrue);

    await tester.tap(key('project-settings-cancel'));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    expect(meta.saved, isEmpty);
    expect(meta.calls, ['loadProjectSettings']);
    expect(epoch.bumps, 0);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: key('settings-game-title'),
        matching: find.text('Forge & Fable'),
      ),
      findsOneWidget,
    );
    expect(saveEnabled(tester), isFalse);
  }, variant: linux);

  testWidgets('initialTab opens the dialog on that tab', (tester) async {
    await open(tester, initialTab: ProjectSettingsTab.statsAndFormulas);
    expect(find.text('Primary Stats'), findsOneWidget);
    expect(find.text('Game Title'), findsNothing);
  }, variant: linux);

  testWidgets('initialTab can open on Custom Fields', (tester) async {
    await open(tester, initialTab: ProjectSettingsTab.customFields);
    expect(find.text('Item Categories'), findsOneWidget);
    expect(find.text('NPC Types'), findsOneWidget);
    expect(
      find.descendant(
        of: key('custom-fields-scope'),
        matchRoot: true,
        matching: find.text('Weapon'),
      ),
      findsOneWidget,
      reason: 'the first item category is selected, as 0.1.6',
    );
    expect(find.text('damage'), findsOneWidget);
    expect(find.text('handedness'), findsOneWidget);
  }, variant: linux);

  testWidgets('deleting an in-use row shows the refusal and keeps the row', (
    tester,
  ) async {
    meta.inUse['rarity-rare'] = 'Rarity is used by 2 item(s).';
    await open(tester);
    await tapAction(tester, 'rarity-rare', 'Delete');
    expect(find.text('Rarity is used by 2 item(s).'), findsOneWidget);
    expect(find.text('Rare'), findsOneWidget);
    expect(meta.calls, contains('checkInUse rarity rarity-rare'));
    expect(saveEnabled(tester), isFalse, reason: 'the buffer is unchanged');

    await tester.tap(find.text('Dismiss'));
    await tester.pump();
    expect(find.text('Rarity is used by 2 item(s).'), findsNothing);
  }, variant: linux);

  testWidgets('a row added in this session is deleted without a check', (
    tester,
  ) async {
    await open(tester, initialTab: ProjectSettingsTab.crafting);
    await tester.tap(
      find.descendant(
        of: key('section-craftingSpecializations'),
        matching: find.widgetWithText(OutlinedButton, 'Add'),
      ),
    );
    await tester.pumpAndSettle();
    await fillRowDialog(tester, name: 'Weaving');
    final id = container
        .read(projectSettingsProvider)
        .requireValue
        .craftingSpecializations[1]
        .id;
    await tapAction(tester, id, 'Delete');
    expect(find.text('Weaving'), findsNothing);
    expect(meta.calls.where((c) => c.startsWith('checkInUse')), isEmpty);
    expect(saveEnabled(tester), isFalse);
  }, variant: linux);

  testWidgets('a duplicate export key is refused in the row dialog', (
    tester,
  ) async {
    await open(tester, initialTab: ProjectSettingsTab.statsAndFormulas);
    await tester.tap(
      find.descendant(
        of: key('section-stats'),
        matching: find.widgetWithText(OutlinedButton, 'Add'),
      ),
    );
    await tester.pumpAndSettle();
    await fillRowDialog(tester, name: 'Strong', exportKey: 'str');
    expect(
      find.text('Export key "str" is already used by "Strength".'),
      findsOneWidget,
    );
    expect(find.text('Add Stat'), findsOneWidget, reason: 'dialog stays');

    await tester.enterText(key('meta-row-key'), 'Bad Key');
    await tester.pump();
    expect(
      find.text(
        'Export key may only contain lowercase letters, digits, "_" and "-".',
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<ButtonStyleButton>(key('meta-row-dialog-submit')).enabled,
      isFalse,
    );
  }, variant: linux);

  testWidgets('a failed save shows the error and keeps the dialog and the '
      'edits', (tester) async {
    meta.saveError = SaveFailed('disk I/O error', Exception('io'));
    await open(tester);
    await tester.enterText(key('settings-game-title'), 'Retitled');
    await tester.pump();
    await tester.tap(key('project-settings-save'));
    await tester.pumpAndSettle();

    expect(dialog, findsOneWidget);
    expect(
      find.descendant(
        of: key('project-settings-error'),
        matching: find.text('disk I/O error'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: key('settings-game-title'),
        matching: find.text('Retitled'),
      ),
      findsOneWidget,
    );
    expect(epoch.bumps, 0);
    expect(saveEnabled(tester), isTrue, reason: 'a retry is possible');

    await tester.tap(key('project-settings-save'));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    expect(meta.saved, hasLength(2));
    expect(epoch.bumps, 1);
  }, variant: linux);

  testWidgets('an empty game title blocks Save with a message', (tester) async {
    await open(tester);
    await tester.enterText(key('settings-game-title'), '   ');
    await tester.pump();
    expect(saveEnabled(tester), isFalse);
    expect(
      find.descendant(
        of: key('project-settings-blocker'),
        matchRoot: true,
        matching: find.text('Game title is required.'),
      ),
      findsOneWidget,
    );
    expect(find.text('Game title is required.'), findsNWidgets(2));
    expect(
      await container.read(projectSettingsProvider.notifier).save(),
      isFalse,
    );
    expect(meta.saved, isEmpty);
  }, variant: linux);

  group('Custom Fields tab', () {
    testWidgets('creating a definition writes at once and lists it', (
      tester,
    ) async {
      await open(tester, initialTab: ProjectSettingsTab.customFields);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Add Field'));
      await tester.pumpAndSettle();
      expect(find.text('Add Custom Field'), findsOneWidget);
      await tester.enterText(key('field-name'), 'weight');
      await tester.enterText(key('field-default'), '1.5');
      await tester.tap(find.text('Searchable / Filterable'));
      await tester.pump();
      await tester.tap(key('field-dialog-submit'));
      await tester.pumpAndSettle();

      expect(fields.calls, ['createDefinition weight']);
      final input = fields.created.single;
      expect(input.scopeType, CustomFieldScope.itemCategory);
      expect(input.scopeId, 'cat-weapon');
      expect(input.fieldType, CustomFieldType.text);
      expect(input.defaultValue, '1.5');
      expect(input.isSearchable, isTrue);
      expect(input.isRequired, isFalse);
      expect(epoch.bumps, 1);
      expect(find.text('weight'), findsOneWidget);
      expect(meta.saved, isEmpty, reason: 'Save is not involved');
    }, variant: linux);

    testWidgets('the field type is fixed when editing', (tester) async {
      await open(tester, initialTab: ProjectSettingsTab.customFields);
      await tester.tap(
        find.descendant(
          of: key('field-row-field-damage'),
          matching: find.byTooltip('Edit'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Edit Field: damage'), findsOneWidget);
      expect(
        find.text('Field type cannot be changed after creation.'),
        findsOneWidget,
      );
      final picker = tester.widget<DropdownButton<CustomFieldType>>(
        find.byType(DropdownButton<CustomFieldType>),
      );
      expect(picker.onChanged, isNull);
      expect(picker.value, CustomFieldType.integer);

      await tester.enterText(key('field-name'), 'base damage');
      await tester.pump();
      await tester.tap(key('field-dialog-submit'));
      await tester.pumpAndSettle();
      expect(fields.calls, ['updateDefinition field-damage']);
      expect(fields.updated.single.fieldName, 'base damage');
      expect(fields.updated.single.enumOptions, isNull);
      expect(find.text('base damage'), findsOneWidget);
    }, variant: linux);

    testWidgets('a refused delete shows the repository message inline', (
      tester,
    ) async {
      const message =
          'Cannot delete "damage": 2 record(s) currently have values for '
          'this field. Clear those values first.';
      fields.deleteErrors['field-damage'] = const SaveBlocked([message]);
      await open(tester, initialTab: ProjectSettingsTab.customFields);
      await tester.tap(
        find.descendant(
          of: key('field-row-field-damage'),
          matching: find.byTooltip('Delete'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);
      expect(find.text('damage'), findsOneWidget);
      expect(epoch.bumps, 0);
    }, variant: linux);

    testWidgets('an enum option in use is refused inside the field dialog', (
      tester,
    ) async {
      const message =
          'Cannot remove enum option(s) that are in use: two-handed';
      fields.updateErrors['field-handedness'] = const SaveBlocked([message]);
      await open(tester, initialTab: ProjectSettingsTab.customFields);
      await tester.tap(
        find.descendant(
          of: key('field-row-field-handedness'),
          matching: find.byTooltip('Edit'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(InputChip), findsNWidgets(2));
      await tester.tap(
        find.descendant(
          of: key('field-option-two-handed'),
          matching: find.byIcon(Icons.clear),
        ),
      );
      await tester.pump();
      expect(find.byType(InputChip), findsOneWidget);
      await tester.tap(key('field-dialog-submit'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: key('field-dialog-error'),
          matching: find.text(message),
        ),
        findsOneWidget,
      );
      expect(find.text('Edit Field: handedness'), findsOneWidget);
      expect(fields.updated.single.enumOptions, ['one-handed']);
      expect(epoch.bumps, 0);
    }, variant: linux);

    testWidgets('the rail adds, refuses an in-use delete and reorders item '
        'categories through the repository', (tester) async {
      meta.inUse['cat-weapon'] = 'Item category is used by 4 item(s).';
      await open(tester, initialTab: ProjectSettingsTab.customFields);
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Add Item Category'),
      );
      await tester.pumpAndSettle();
      await fillRowDialog(tester, name: 'Trinket');
      expect(meta.calls, contains('addItemCategory Trinket trinket'));
      expect(find.text('Trinket'), findsOneWidget);
      expect(epoch.bumps, 1);

      await tapAction(tester, 'cat-weapon', 'Delete');
      expect(find.text('Item category is used by 4 item(s).'), findsOneWidget);
      expect(meta.calls, isNot(contains('deleteItemCategory cat-weapon')));

      await tapAction(tester, 'cat-armor', 'Move up');
      expect(
        meta.calls,
        contains(startsWith('reorderItemCategories cat-armor,cat-weapon')),
      );
      expect(epoch.bumps, 2);

      await tapVisible(tester, find.text('Enemy'));
      expect(
        find.descendant(
          of: key('custom-fields-scope'),
          matchRoot: true,
          matching: find.text('Enemy'),
        ),
        findsOneWidget,
      );
      expect(find.text('No custom fields defined.'), findsOneWidget);
    }, variant: linux);
  });

  testWidgets('showProjectSettingsDialog does nothing without a project', (
    tester,
  ) async {
    await tester.pumpWidget(
      settingsTestApp(
        container,
        Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => showProjectSettingsDialog(context, ref),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
  }, variant: linux);

  test('over the real repository the combined commit is one save_history '
      'row', () async {
    final path = copyFixture();
    final db = ProjectDatabase.open(path);
    addTearDown(db.close);
    final real = ProviderContainer.test(
      overrides: [
        metaRepositoryProvider.overrideWithValue(SqliteMetaRepository(db)),
      ],
    );
    final bumps = EpochCounter(real);
    final sub = real.listen(projectSettingsProvider, (_, _) {});
    addTearDown(sub.close);
    final before = readRecentSaves(db).length;
    final controller = real.read(projectSettingsProvider.notifier);
    await real.read(projectSettingsProvider.future);

    expect(
      await controller.tryDelete(ProjectSettingsList.rarities, 'rarity-common'),
      'Rarity is used by 3 item(s).',
    );
    controller.setGameTitle('Forge & Fable II');
    controller.setMaxLevelText('30');
    controller.setSeverity(SoftDeleteReferenceSeverity.error);
    expect(
      controller.addMetaRow(
        ProjectSettingsList.stats,
        const MetaItemInput(displayName: 'Luck', exportKey: 'luck'),
      ),
      isNull,
    );
    expect(
      controller.addRarity(
        const MetaRarityInput(
          displayName: 'Mythic',
          exportKey: 'mythic',
          colorHex: '#FF8800',
        ),
      ),
      isNull,
    );
    controller.moveRow(ProjectSettingsList.craftingStations, 1, 0);
    expect(
      controller.updateDerivedStat(
        'derived-stat-max-hp',
        const DerivedStatInput(
          displayName: 'Max HP',
          exportKey: 'max_hp',
          formula: 'con * 12',
          outputType: DerivedStatOutputType.integer,
          roundingMode: RoundingMode.round,
        ),
      ),
      isNull,
    );

    expect(await controller.save(), isTrue);
    expect(bumps.bumps, 1);

    final saves = readRecentSaves(db);
    expect(saves.length, before + 1);
    expect(saves.first.description, 'Project settings changed');

    final stored = await SqliteMetaRepository(db).loadProjectSettings();
    expect(stored.gameTitle, 'Forge & Fable II');
    expect(stored.maxLevel, 30);
    expect(
      stored.softDeleteReferenceSeverity,
      SoftDeleteReferenceSeverity.error,
    );
    expect(stored.stats.last.exportKey, 'luck');
    expect(isNewMetaId(stored.stats.last.id), isFalse);
    expect(stored.rarities.last.exportKey, 'mythic');
    expect(stored.craftingStations.first.exportKey, 'workbench');
    expect(stored.derivedStats.first.formula, 'con * 12');

    final state = real.read(projectSettingsProvider).requireValue;
    expect(state.baseline, stored);
    expect(state.isDirty, isFalse);
  });

  test('coerceMaxLevel follows 0.1.6 parseInt || 100, at least 1', () {
    expect(coerceMaxLevel('20'), 20);
    expect(coerceMaxLevel(''), 100);
    expect(coerceMaxLevel('0'), 100);
    expect(coerceMaxLevel('abc'), 100);
    expect(coerceMaxLevel('-5'), 1);
    expect(coerceMaxLevel('12abc'), 12);
    expect(coerceMaxLevel(' 7'), 7);
  });

  test('stored keys outside the pattern do not block, new ones do', () {
    final s = ProjectSettingsState.loaded(
      sampleSettings().copyWith(
        stats: const [
          MetaRowDraft(id: 'legacy', displayName: 'Legacy', exportKey: 'STR'),
        ],
      ),
    );
    expect(s.copyWith(gameTitle: 'X').blockers, isEmpty);
    final bad = s.copyWith(
      stats: s.stats.update(
        'legacy',
        (r) => r.copyWith(exportKey: 'Has Space'),
      ),
    );
    expect(bad.blockers, [
      'Stat "Legacy": Export key may only contain lowercase letters, digits, '
          '"_" and "-".',
    ]);
    expect(bad.canSave, isFalse);
  });
}
