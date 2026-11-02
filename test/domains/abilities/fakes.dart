/// In-memory stand-ins for the ability pages' tests: the ability
/// repository, the meta repository's stats, the lifecycle repository and
/// the record validation pass, plus the app the pages are pumped in.
library;

import 'package:anvil/app/editor/widgets/record_validation.dart';
import 'package:anvil/app/providers.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil/app/theme/anvil_theme.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final linux = TargetPlatformVariant.only(TargetPlatform.linux);

const fireballId = 'ability-fireball';
const slashId = 'ability-slash';
const retiredId = 'ability-retired';

AbilityRecord ability(
  String id,
  String name,
  String key, {
  String type = '',
  String description = '',
  String resourceType = '',
  double resourceCost = 0,
  double cooldown = 0,
  Map<String, double> modifiers = const {},
  String updatedAt = '2026-10-30 10:00:00',
  String? deletedAt,
}) => AbilityRecord(
  id: id,
  displayName: name,
  exportKey: key,
  description: description,
  abilityType: type,
  resourceType: resourceType,
  resourceCost: resourceCost,
  cooldown: cooldown,
  statModifiers: modifiers,
  createdAt: '2026-10-30 10:00:00',
  updatedAt: updatedAt,
  deletedAt: deletedAt,
);

/// Two active abilities and one archived.
List<AbilityRecord> sampleAbilities() => [
  ability(
    fireballId,
    'Fireball',
    'fireball',
    type: 'active',
    description: 'Hurls a ball of fire.',
    resourceType: 'mana',
    resourceCost: 12,
    cooldown: 2.5,
    modifiers: {'stat-int': 3},
    updatedAt: '2026-10-29 09:00:00',
  ),
  ability(slashId, 'Slash', 'slash', updatedAt: '2026-10-31 09:00:00'),
  ability(
    retiredId,
    'Retired Move',
    'retired_move',
    type: 'passive',
    deletedAt: '2026-10-31 14:05:09',
  ),
];

AbilityDraft draftOf(AbilityRecord r) => AbilityDraft(
  displayName: r.displayName,
  exportKey: r.exportKey,
  description: r.description,
  abilityType: r.abilityType,
  resourceType: r.resourceType,
  resourceCost: r.resourceCost,
  cooldown: r.cooldown,
  statModifiers: r.statModifiers,
);

AbilityRecord _withDraft(
  AbilityRecord r,
  AbilityDraft d, {
  String? deletedAt,
}) => ability(
  r.id,
  d.displayName,
  d.exportKey,
  type: d.abilityType,
  description: d.description,
  resourceType: d.resourceType,
  resourceCost: d.resourceCost,
  cooldown: d.cooldown,
  modifiers: d.statModifiers,
  updatedAt: r.updatedAt,
  deletedAt: deletedAt,
);

/// `AbilityRepository` over a list, recording its calls. [usedByOf] is what
/// [usedBy] answers per id; [saveError] is thrown by the next save.
class FakeAbilityRepository implements AbilityRepository {
  FakeAbilityRepository([List<AbilityRecord>? rows])
    : rows = rows ?? sampleAbilities();

  final List<AbilityRecord> rows;
  final calls = <String>[];
  final saved = <AbilityDraft>[];
  final usedByOf = <String, AbilityUsedBy>{};
  Object? saveError;
  var _next = 0;

  int _index(String id) {
    final i = rows.indexWhere((r) => r.id == id);
    if (i < 0) throw RecordNotFound('abilities', id);
    return i;
  }

  AbilityRecord byId(String id) => rows[_index(id)];

  @override
  Future<List<AbilityRecord>> list({
    RecordListMode mode = RecordListMode.active,
  }) async {
    calls.add('list ${mode.name}');
    return rows
        .where(
          (r) => switch (mode) {
            RecordListMode.active => r.deletedAt == null,
            RecordListMode.deletedOnly => r.deletedAt != null,
            RecordListMode.all => true,
          },
        )
        .toList()
      ..sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
  }

  @override
  Future<int> countActive() async =>
      rows.where((r) => r.deletedAt == null).length;

  @override
  Future<AbilityRecord> get(String id) async => byId(id);

  @override
  Future<AbilityDraft> load(String id) async {
    calls.add('load $id');
    return draftOf(byId(id));
  }

  @override
  Future<AbilityRecord> create(CreateAbilityInput input) async {
    calls.add('create ${input.displayName} ${input.exportKey}');
    if (rows.any((r) => r.exportKey == input.exportKey)) {
      throw DuplicateExportKey(input.exportKey);
    }
    final record = ability(
      'ability-new-${++_next}',
      input.displayName,
      input.exportKey,
    );
    rows.add(record);
    return record;
  }

  @override
  Future<AbilityDraft> save(String id, AbilityDraft draft) async {
    calls.add('save $id');
    if (saveError case final error?) {
      saveError = null;
      throw error;
    }
    final i = _index(id);
    rows[i] = _withDraft(rows[i], draft);
    saved.add(draft);
    return draftOf(rows[i]);
  }

  @override
  Future<AbilityRecord> duplicate(String id) async {
    calls.add('duplicate $id');
    final source = byId(id);
    final copy = ability(
      '$id-copy${++_next}',
      '${source.displayName} (Copy)',
      '${source.exportKey}-copy$_next',
      type: source.abilityType,
      description: source.description,
      modifiers: source.statModifiers,
    );
    rows.add(copy);
    return copy;
  }

  @override
  Future<void> softDelete(String id) async {
    calls.add('softDelete $id');
    final i = _index(id);
    rows[i] = _withDraft(
      rows[i],
      draftOf(rows[i]),
      deletedAt: rows[i].deletedAt ?? '2026-11-01 09:00:00',
    );
  }

  @override
  Future<void> restore(String id) async {
    calls.add('restore $id');
    final i = _index(id);
    rows[i] = _withDraft(rows[i], draftOf(rows[i]));
  }

  @override
  Future<void> hardDelete(String id) async {
    calls.add('hardDelete $id');
    rows.removeAt(_index(id));
  }

  @override
  Future<AbilityUsedBy> usedBy(String id) async {
    calls.add('usedBy $id');
    return usedByOf[id] ?? AbilityUsedBy(classes: [], npcs: []);
  }
}

/// The bulk operations over a [FakeAbilityRepository].
class FakeAbilityLifecycle implements LifecycleRepository {
  FakeAbilityLifecycle(this.abilities);

  final FakeAbilityRepository abilities;

  @override
  Future<DeleteImpact> computeDeleteImpact(
    LifecycleDomain domain,
    List<String> ids,
  ) async => DeleteImpact(recordCount: ids.length, references: []);

  @override
  Future<int> bulkSoftDelete(LifecycleDomain domain, List<String> ids) async {
    abilities.calls.add('bulkSoftDelete ${domain.value} ${ids.join(',')}');
    for (final id in ids) {
      await abilities.softDelete(id);
    }
    return ids.length;
  }

  @override
  Future<int> bulkRestore(LifecycleDomain domain, List<String> ids) async {
    abilities.calls.add('bulkRestore ${domain.value} ${ids.join(',')}');
    for (final id in ids) {
      await abilities.restore(id);
    }
    return ids.length;
  }

  @override
  Future<int> bulkHardDelete(LifecycleDomain domain, List<String> ids) async {
    abilities.calls.add('bulkHardDelete ${domain.value} ${ids.join(',')}');
    for (final id in ids) {
      await abilities.hardDelete(id);
    }
    return ids.length;
  }

  @override
  Future<RecordCounts> countDeleted() => throw UnimplementedError();

  @override
  Future<int> emptyTrash() => throw UnimplementedError();

  @override
  Future<RecordCounts> weeklyDeltas() => throw UnimplementedError();
}

const sampleStats = [
  MetaStat(
    id: 'stat-str',
    displayName: 'Strength',
    exportKey: 'strength',
    sortOrder: 1,
  ),
  MetaStat(
    id: 'stat-int',
    displayName: 'Intelligence',
    exportKey: 'intelligence',
    sortOrder: 2,
  ),
];

/// A `MetaRepository` that answers only [listStats].
class FakeStatsRepository implements MetaRepository {
  FakeStatsRepository([this.stats = sampleStats]);

  List<MetaStat> stats;

  @override
  Future<List<MetaStat>> listStats() async => stats;

  /// No NPC types: an editor opened by click-through from a rail renders
  /// over this fake too.
  @override
  Future<List<MetaNpcType>> listNpcTypes() async => const [];

  @override
  Future<ProjectSettingsDraft> loadProjectSettings() async =>
      ProjectSettingsDraft(
        gameTitle: 'Test',
        maxLevel: 20,
        softDeleteReferenceSeverity: SoftDeleteReferenceSeverity.warning,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeStatsRepository: ${invocation.memberName}');
}

/// The record pass replaced by [issues], which [refresh] publishes; counts
/// its calls.
class FakeRecordValidation extends RecordValidationNotifier {
  FakeRecordValidation(super.key, this.script);

  final ValidationScript script;

  @override
  List<ValidationIssue> build() => const [];

  @override
  List<ValidationIssue> refresh() {
    script.refreshes++;
    return state = script.issues;
  }
}

class ValidationScript {
  List<ValidationIssue> issues = const [];
  var refreshes = 0;
}

/// The editor or list over the fakes, in the app theme at 1400×1000.
class AbilityHarness {
  AbilityHarness({List<AbilityRecord>? rows, List<MetaStat>? stats})
    : repository = FakeAbilityRepository(rows),
      meta = FakeStatsRepository(stats ?? sampleStats);

  final FakeAbilityRepository repository;
  final FakeStatsRepository meta;
  final validation = ValidationScript();
  late final lifecycle = FakeAbilityLifecycle(repository);
  late ProviderContainer container;

  int get epoch => container.read(writeEpochProvider);

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    EditingMode editingMode = EditingMode.modal,
    List overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: [
        abilityRepositoryProvider.overrideWithValue(repository),
        metaRepositoryProvider.overrideWithValue(meta),
        lifecycleRepositoryProvider.overrideWithValue(lifecycle),
        initialAppSettingsProvider.overrideWithValue(
          AppSettings(editingMode: editingMode),
        ),
        recordValidationProvider.overrideWith2(
          (key) => FakeRecordValidation(key, validation),
        ),
        ...overrides.cast(),
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: anvilTheme(AnvilThemeSpec.dark),
          home: Scaffold(
            body: Padding(padding: const EdgeInsets.all(24), child: child),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}
