import 'package:anvil/app/settings/project/project_settings_controller.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil/app/theme/anvil_theme.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// The settings the fake starts with: a small project in the fixture's
/// shape.
ProjectSettingsDraft sampleSettings() => ProjectSettingsDraft(
  gameTitle: 'Forge & Fable',
  maxLevel: 20,
  softDeleteReferenceSeverity: SoftDeleteReferenceSeverity.warning,
  stats: const [
    MetaRowDraft(id: 'stat-str', displayName: 'Strength', exportKey: 'str'),
    MetaRowDraft(id: 'stat-con', displayName: 'Constitution', exportKey: 'con'),
  ],
  rarities: const [
    RarityRowDraft(
      id: 'rarity-common',
      displayName: 'Common',
      exportKey: 'common',
      colorHex: '#D8DEE9',
    ),
    RarityRowDraft(
      id: 'rarity-rare',
      displayName: 'Rare',
      exportKey: 'rare',
      colorHex: '#5E81AC',
    ),
  ],
  craftingStations: const [
    MetaRowDraft(id: 'station-forge', displayName: 'Forge', exportKey: 'forge'),
  ],
  craftingSpecializations: const [
    MetaRowDraft(
      id: 'spec-smithing',
      displayName: 'Blacksmithing',
      exportKey: 'blacksmithing',
    ),
  ],
  derivedStats: const [
    DerivedStatRowDraft(
      id: 'derived-hp',
      displayName: 'Max HP',
      exportKey: 'max_hp',
      formula: 'con * 10',
      outputType: DerivedStatOutputType.integer,
      roundingMode: RoundingMode.round,
    ),
  ],
);

/// A [MetaRepository] over memory that records the calls the dialog makes.
/// Methods the dialog never calls throw.
class FakeMetaRepository implements MetaRepository {
  FakeMetaRepository({ProjectSettingsDraft? settings})
    : settings = settings ?? sampleSettings();

  ProjectSettingsDraft settings;
  final calls = <String>[];

  /// Every draft passed to [saveProjectSettings].
  final saved = <ProjectSettingsDraft>[];

  /// Thrown by the next [saveProjectSettings] instead of saving.
  Object? saveError;

  /// id → the `checkInUse` reason for rows records still use.
  final inUse = <String, String>{};

  var _nextId = 0;

  final itemCategories = <MetaItemCategory>[
    const MetaItemCategory(
      id: 'cat-weapon',
      displayName: 'Weapon',
      exportKey: 'weapon',
      description: '',
      sortOrder: 0,
    ),
    const MetaItemCategory(
      id: 'cat-armor',
      displayName: 'Armor',
      exportKey: 'armor',
      description: '',
      sortOrder: 1,
    ),
  ];

  final npcTypes = <MetaNpcType>[
    const MetaNpcType(
      id: 'npc-enemy',
      displayName: 'Enemy',
      exportKey: 'enemy',
      description: '',
      sortOrder: 0,
    ),
  ];

  @override
  Future<ProjectSettingsDraft> loadProjectSettings() async {
    calls.add('loadProjectSettings');
    return settings;
  }

  @override
  Future<ProjectSettingsDraft> saveProjectSettings(
    ProjectSettingsDraft draft,
  ) async {
    calls.add('saveProjectSettings');
    saved.add(draft);
    if (saveError case final error?) {
      saveError = null;
      throw error;
    }
    String real(String id) => isNewMetaId(id) ? 'srv-${++_nextId}' : id;
    settings = draft.copyWith(
      stats: [for (final r in draft.stats) r.copyWith(id: real(r.id))],
      rarities: [for (final r in draft.rarities) r.copyWith(id: real(r.id))],
      craftingStations: [
        for (final r in draft.craftingStations) r.copyWith(id: real(r.id)),
      ],
      craftingSpecializations: [
        for (final r in draft.craftingSpecializations)
          r.copyWith(id: real(r.id)),
      ],
      derivedStats: [
        for (final r in draft.derivedStats) r.copyWith(id: real(r.id)),
      ],
    );
    return settings;
  }

  @override
  Future<MetaInUseResult> checkInUse(MetaInUseKind kind, String id) async {
    calls.add('checkInUse ${kind.value} $id');
    final reason = inUse[id];
    return reason == null
        ? const MetaInUseResult.free()
        : MetaInUseResult.used(reason);
  }

  @override
  Future<List<MetaItemCategory>> listItemCategories() async =>
      List.of(itemCategories);

  @override
  Future<List<MetaNpcType>> listNpcTypes() async => List.of(npcTypes);

  @override
  Future<MetaItemCategory> addItemCategory(MetaItemInput input) async {
    calls.add('addItemCategory ${input.displayName} ${input.exportKey}');
    final c = MetaItemCategory(
      id: 'cat-${++_nextId}',
      displayName: input.displayName,
      exportKey: input.exportKey,
      description: '',
      sortOrder: itemCategories.length,
    );
    itemCategories.add(c);
    return c;
  }

  @override
  Future<void> deleteItemCategory(String id) async {
    calls.add('deleteItemCategory $id');
    itemCategories.removeWhere((c) => c.id == id);
  }

  @override
  Future<void> reorderItemCategories(List<String> ids) async {
    calls.add('reorderItemCategories ${ids.join(',')}');
    itemCategories.sort((a, b) => ids.indexOf(a.id) - ids.indexOf(b.id));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeMetaRepository.${invocation.memberName}');
}

/// A [CustomFieldRepository] over memory that records writes.
class FakeCustomFieldRepository implements CustomFieldRepository {
  final definitions = <CustomFieldDefinition>[
    CustomFieldDefinition(
      id: 'field-damage',
      scopeType: CustomFieldScope.itemCategory,
      scopeId: 'cat-weapon',
      fieldName: 'damage',
      fieldType: CustomFieldType.integer,
      defaultValue: null,
      enumOptions: const [],
      isRequired: true,
      isSearchable: false,
      sortOrder: 0,
      createdAt: '2026-10-31 20:58:16',
      updatedAt: '2026-10-31 20:58:16',
    ),
    CustomFieldDefinition(
      id: 'field-handedness',
      scopeType: CustomFieldScope.itemCategory,
      scopeId: 'cat-weapon',
      fieldName: 'handedness',
      fieldType: CustomFieldType.enumeration,
      defaultValue: 'one-handed',
      enumOptions: const ['one-handed', 'two-handed'],
      isRequired: false,
      isSearchable: true,
      sortOrder: 0,
      createdAt: '2026-10-31 20:58:16',
      updatedAt: '2026-10-31 20:58:16',
    ),
  ];

  final calls = <String>[];
  final created = <CreateCustomFieldDefinitionInput>[];
  final updated = <UpdateCustomFieldDefinitionInput>[];

  /// id → what [deleteDefinition] throws for it.
  final deleteErrors = <String, Object>{};

  /// id → what [updateDefinition] throws for it (after recording the
  /// input).
  final updateErrors = <String, Object>{};
  var _nextId = 0;

  @override
  Future<List<CustomFieldDefinition>> listDefinitions(
    CustomFieldScope scopeType,
    String scopeId,
  ) async => [
    for (final d in definitions)
      if (d.scopeType == scopeType && d.scopeId == scopeId) d,
  ];

  @override
  Future<CustomFieldDefinition> createDefinition(
    CreateCustomFieldDefinitionInput input,
  ) async {
    calls.add('createDefinition ${input.fieldName}');
    created.add(input);
    final d = CustomFieldDefinition(
      id: 'field-${++_nextId}',
      scopeType: input.scopeType,
      scopeId: input.scopeId,
      fieldName: input.fieldName,
      fieldType: input.fieldType,
      defaultValue: input.defaultValue,
      enumOptions: input.enumOptions,
      isRequired: input.isRequired,
      isSearchable: input.isSearchable,
      sortOrder: input.sortOrder,
      createdAt: '2026-11-01 12:00:00',
      updatedAt: '2026-11-01 12:00:00',
    );
    definitions.add(d);
    return d;
  }

  @override
  Future<CustomFieldDefinition> updateDefinition(
    String id,
    UpdateCustomFieldDefinitionInput input,
  ) async {
    calls.add('updateDefinition $id');
    updated.add(input);
    if (updateErrors[id] case final error?) throw error;
    final i = definitions.indexWhere((d) => d.id == id);
    final d = definitions[i];
    final next = CustomFieldDefinition(
      id: d.id,
      scopeType: d.scopeType,
      scopeId: d.scopeId,
      fieldName: input.fieldName ?? d.fieldName,
      fieldType: d.fieldType,
      defaultValue: input.setsDefaultValue
          ? input.defaultValue
          : d.defaultValue,
      enumOptions: input.enumOptions ?? d.enumOptions,
      isRequired: input.isRequired ?? d.isRequired,
      isSearchable: input.isSearchable ?? d.isSearchable,
      sortOrder: d.sortOrder,
      createdAt: d.createdAt,
      updatedAt: d.updatedAt,
    );
    definitions[i] = next;
    return next;
  }

  @override
  Future<void> deleteDefinition(String id) async {
    calls.add('deleteDefinition $id');
    if (deleteErrors[id] case final error?) throw error;
    definitions.removeWhere((d) => d.id == id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'FakeCustomFieldRepository.${invocation.memberName}',
  );
}

/// Counts write epoch bumps.
class EpochCounter {
  EpochCounter(ProviderContainer container) {
    container.listen(writeEpochProvider, (_, _) => bumps++);
  }

  var bumps = 0;
}

/// The overrides that let the dialog run without a project session.
List<Override> settingsOverrides(
  FakeMetaRepository meta,
  FakeCustomFieldRepository fields,
) => [
  metaRepositoryProvider.overrideWithValue(meta),
  customFieldRepositoryProvider.overrideWithValue(fields),
  projectSettingsHeaderProvider.overrideWithValue(
    const ProjectSettingsHeader(
      projectName: 'Spike Fixture',
      location: '/projects/Spike Fixture',
    ),
  ),
];

/// A test app with [home] in a scaffold, on the dark theme.
Widget settingsTestApp(ProviderContainer container, Widget home) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: anvilTheme(AnvilThemeSpec.dark),
        home: Scaffold(body: home),
      ),
    );
