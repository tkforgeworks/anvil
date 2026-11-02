/// In-memory stand-ins for the class pages' tests: the class repository,
/// the lifecycle repository over it and the app the pages are pumped in.
/// The ability repository, the stats and the validation fake are the
/// abilities tests' own.
library;

import 'package:anvil/app/editor/widgets/record_validation.dart';
import 'package:anvil/app/providers.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil/app/theme/anvil_theme.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../abilities/fakes.dart';

export '../abilities/fakes.dart'
    show
        FakeAbilityRepository,
        ValidationScript,
        fireballId,
        linux,
        retiredId,
        slashId;

const warriorId = 'class-warrior';
const mageId = 'class-mage';
const retiredClassId = 'class-retired';

ClassRecord classRecord(
  String id,
  String name,
  String key, {
  String description = '',
  double resourceMultiplier = 1,
  String updatedAt = '2026-10-30 10:00:00',
  String? deletedAt,
}) => ClassRecord(
  id: id,
  displayName: name,
  exportKey: key,
  description: description,
  resourceMultiplier: resourceMultiplier,
  createdAt: '2026-10-30 10:00:00',
  updatedAt: updatedAt,
  deletedAt: deletedAt,
);

/// Warrior (two abilities, one metadata field, stat growth for ANVL-196),
/// Mage (no junction data) and one archived class.
List<ClassRecord> sampleClasses() => [
  classRecord(
    warriorId,
    'Warrior',
    'warrior',
    description: 'A sturdy fighter.',
    resourceMultiplier: 1.25,
    updatedAt: '2026-10-29 09:00:00',
  ),
  classRecord(mageId, 'Mage', 'mage', updatedAt: '2026-10-31 09:00:00'),
  classRecord(
    retiredClassId,
    'Retired Class',
    'retired_class',
    deletedAt: '2026-10-31 14:05:09',
  ),
];

ClassDraft warriorDraft() => ClassDraft(
  displayName: 'Warrior',
  exportKey: 'warrior',
  description: 'A sturdy fighter.',
  resourceMultiplier: 1.25,
  statGrowth: {const StatGrowthKey('stat-str', 1): 10},
  statGrowthFormulas: const {'stat-int': 'level * 2'},
  derivedStatOverrides: const {'derived-hp': 'level * 12'},
  abilityIds: const [slashId, fireballId],
  metadataFields: const [ClassMetadataField(fieldKey: 'base_speed', value: 4)],
);

/// `ClassRepository` over lists, recording its calls. [usedByOf] is what
/// [usedBy] answers per id; [saveError] is thrown by the next save.
class FakeClassRepository implements ClassRepository {
  FakeClassRepository()
    : rows = sampleClasses(),
      drafts = {
        warriorId: warriorDraft(),
        mageId: ClassDraft(displayName: 'Mage', exportKey: 'mage'),
        retiredClassId: ClassDraft(
          displayName: 'Retired Class',
          exportKey: 'retired_class',
        ),
      };

  final List<ClassRecord> rows;
  final Map<String, ClassDraft> drafts;
  final calls = <String>[];
  final saved = <ClassDraft>[];
  final usedByOf = <String, List<UsedByRef>>{};
  Object? saveError;
  var _next = 0;

  int _index(String id) {
    final i = rows.indexWhere((r) => r.id == id);
    if (i < 0) throw RecordNotFound('classes', id);
    return i;
  }

  ClassRecord _with(ClassRecord r, ClassDraft d, {String? deletedAt}) =>
      classRecord(
        r.id,
        d.displayName,
        d.exportKey,
        description: d.description,
        resourceMultiplier: d.resourceMultiplier,
        updatedAt: r.updatedAt,
        deletedAt: deletedAt,
      );

  @override
  Future<List<ClassRecord>> list({
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
  Future<ClassRecord> get(String id) async => rows[_index(id)];

  @override
  Future<ClassDraft> load(String id) async {
    calls.add('load $id');
    _index(id);
    return drafts[id]!;
  }

  @override
  Future<ClassRecord> create(CreateClassInput input) async {
    calls.add(
      'create ${input.displayName} ${input.exportKey} '
      '${input.resourceMultiplier}',
    );
    if (rows.any((r) => r.exportKey == input.exportKey)) {
      throw DuplicateExportKey(input.exportKey);
    }
    final record = classRecord(
      'class-new-${++_next}',
      input.displayName,
      input.exportKey,
      resourceMultiplier: input.resourceMultiplier,
    );
    rows.add(record);
    drafts[record.id] = ClassDraft(
      displayName: input.displayName,
      exportKey: input.exportKey,
      resourceMultiplier: input.resourceMultiplier,
    );
    return record;
  }

  @override
  Future<ClassDraft> save(String id, ClassDraft draft) async {
    calls.add('save $id');
    if (saveError case final error?) {
      saveError = null;
      throw error;
    }
    final i = _index(id);
    // The repository reads metadata back ordered by key.
    final stored = draft.copyWith(
      metadataFields: [...draft.metadataFields]
        ..sort((a, b) => a.fieldKey.compareTo(b.fieldKey)),
    );
    rows[i] = _with(rows[i], stored);
    drafts[id] = stored;
    saved.add(draft);
    return stored;
  }

  @override
  Future<ClassRecord> duplicate(String id) async {
    calls.add('duplicate $id');
    final source = rows[_index(id)];
    final copy = classRecord(
      '$id-copy${++_next}',
      '${source.displayName} (Copy)',
      '${source.exportKey}-copy$_next',
      description: source.description,
      resourceMultiplier: source.resourceMultiplier,
    );
    rows.add(copy);
    drafts[copy.id] = drafts[id]!.copyWith(
      displayName: copy.displayName,
      exportKey: copy.exportKey,
    );
    return copy;
  }

  @override
  Future<void> softDelete(String id) async {
    calls.add('softDelete $id');
    final i = _index(id);
    rows[i] = _with(
      rows[i],
      drafts[id]!,
      deletedAt: rows[i].deletedAt ?? '2026-11-01 09:00:00',
    );
  }

  @override
  Future<void> restore(String id) async {
    calls.add('restore $id');
    final i = _index(id);
    rows[i] = _with(rows[i], drafts[id]!);
  }

  @override
  Future<void> hardDelete(String id) async {
    calls.add('hardDelete $id');
    rows.removeAt(_index(id));
    drafts.remove(id);
  }

  @override
  Future<List<UsedByRef>> usedBy(String id) async {
    calls.add('usedBy $id');
    return usedByOf[id] ?? const [];
  }

  @override
  Future<Map<StatGrowthKey, double>> resolvedStatGrowth(String id) =>
      throw UnimplementedError();
}

/// The bulk operations over a [FakeClassRepository].
class FakeClassLifecycle implements LifecycleRepository {
  FakeClassLifecycle(this.classes);

  final FakeClassRepository classes;

  @override
  Future<DeleteImpact> computeDeleteImpact(
    LifecycleDomain domain,
    List<String> ids,
  ) async => DeleteImpact(recordCount: ids.length, references: []);

  @override
  Future<int> bulkSoftDelete(LifecycleDomain domain, List<String> ids) async {
    classes.calls.add('bulkSoftDelete ${domain.value} ${ids.join(',')}');
    for (final id in ids) {
      await classes.softDelete(id);
    }
    return ids.length;
  }

  @override
  Future<int> bulkRestore(LifecycleDomain domain, List<String> ids) async {
    for (final id in ids) {
      await classes.restore(id);
    }
    return ids.length;
  }

  @override
  Future<int> bulkHardDelete(LifecycleDomain domain, List<String> ids) async {
    for (final id in ids) {
      await classes.hardDelete(id);
    }
    return ids.length;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeClassLifecycle: ${invocation.memberName}');
}

/// The class pages or controller over the fakes. [pump] lays the page out
/// at the app's minimum width less the open sidebar (1400 − 220 = 1180,
/// less the 24 px padding on each side), as the ANVL-193 layout rule asks.
class ClassHarness {
  final classes = FakeClassRepository();
  final abilities = FakeAbilityRepository();
  final meta = FakeStatsRepository();
  final validation = ValidationScript();
  late final lifecycle = FakeClassLifecycle(classes);
  late ProviderContainer container;

  int get epoch => container.read(writeEpochProvider);

  ProviderContainer build({
    EditingMode editingMode = EditingMode.modal,
    List overrides = const [],
  }) {
    container = ProviderContainer(
      overrides: [
        classRepositoryProvider.overrideWithValue(classes),
        abilityRepositoryProvider.overrideWithValue(abilities),
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
    return container;
  }

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    EditingMode editingMode = EditingMode.modal,
    List overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(1180, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    build(editingMode: editingMode, overrides: overrides);
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
