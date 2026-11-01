/// In-memory stand-ins for the recipe pages' repositories, and the
/// container and app every recipe widget test pumps.
library;

import 'dart:io';

import 'package:anvil/app/editor/widgets/record_validation.dart';
import 'package:anvil/app/providers.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil/app/theme/anvil_theme.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final linux = TargetPlatformVariant.only(TargetPlatform.linux);

const swordId = 'recipe-sword';
const potionId = 'recipe-potion';

const ingotId = 'item-ingot';
const stripId = 'item-strip';
const swordItemId = 'item-sword';
const potionItemId = 'item-potion';
const herbId = 'item-herb';
const cursedId = 'item-cursed';

ItemRecord item(String id, String name, {String? deletedAt}) => ItemRecord(
  id: id,
  displayName: name,
  exportKey: id,
  description: '',
  itemCategoryId: 'cat-weapon',
  rarityId: 'rarity-common',
  createdAt: '2026-10-30 10:00:00',
  updatedAt: '2026-10-30 10:00:00',
  deletedAt: deletedAt,
);

/// Five active items and one soft-deleted, by name.
List<ItemRecord> sampleItems() => [
  item(cursedId, 'Cursed Dagger', deletedAt: '2026-10-31 20:58:16'),
  item(potionItemId, 'Healing Potion'),
  item(ingotId, 'Iron Ingot'),
  item(swordItemId, 'Iron Sword'),
  item(stripId, 'Leather Strip'),
  item(herbId, 'Moonpetal Herb'),
];

RecipeDraft swordDraft() => RecipeDraft(
  displayName: 'Forge Iron Sword',
  exportKey: 'forge-iron-sword',
  outputItemId: swordItemId,
  craftingStationId: 'station-forge',
  craftingSpecializationId: 'spec-blacksmithing',
  ingredients: const [
    RecipeIngredient(itemId: ingotId, quantity: 2),
    RecipeIngredient(itemId: stripId, quantity: 1),
  ],
);

RecipeDraft potionDraft() => RecipeDraft(
  displayName: 'Brew Healing Potion',
  exportKey: 'brew-healing-potion',
  outputItemId: potionItemId,
  outputQuantity: 3,
  craftingStationId: 'station-alchemy',
  ingredients: const [RecipeIngredient(itemId: herbId, quantity: 2)],
);

/// The recipes table in memory: drafts and deletion stamps by id, the
/// calls it received and scripted failures by call name.
class FakeRecipeRepository implements RecipeRepository {
  FakeRecipeRepository()
    : drafts = {swordId: swordDraft(), potionId: potionDraft()};

  final Map<String, RecipeDraft> drafts;
  final deleted = <String, String>{};
  final calls = <String>[];

  /// Thrown by the next call of that name (`save`, `create`, ...).
  final failures = <String, Object>{};
  var _next = 0;

  void _maybeFail(String call) {
    if (failures.remove(call) case final error?) throw error;
  }

  RecipeDraft _draft(String id) =>
      drafts[id] ?? (throw RecordNotFound('recipes', id));

  RecipeRecord _record(String id) {
    final d = _draft(id);
    return RecipeRecord(
      id: id,
      displayName: d.displayName,
      exportKey: d.exportKey,
      description: d.description,
      outputItemId: d.outputItemId,
      outputQuantity: d.outputQuantity,
      craftingStationId: d.craftingStationId,
      craftingSpecializationId: d.craftingSpecializationId,
      createdAt: '2026-10-30 10:00:00',
      updatedAt: '2026-10-30 10:00:00',
      deletedAt: deleted[id],
    );
  }

  @override
  Future<List<RecipeRecord>> list({
    RecordListMode mode = RecordListMode.active,
  }) async {
    calls.add('list ${mode.name}');
    _maybeFail('list');
    final rows = [
      for (final id in drafts.keys)
        if (switch (mode) {
          RecordListMode.active => !deleted.containsKey(id),
          RecordListMode.deletedOnly => deleted.containsKey(id),
          RecordListMode.all => true,
        })
          _record(id),
    ];
    return rows..sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
  }

  @override
  Future<int> countActive() async =>
      drafts.keys.where((id) => !deleted.containsKey(id)).length;

  @override
  Future<RecipeRecord> get(String id) async => _record(id);

  @override
  Future<RecipeDraft> load(String id) async {
    calls.add('load $id');
    _maybeFail('load');
    return _draft(id);
  }

  @override
  Future<RecipeRecord> create(CreateRecipeInput input) async {
    calls.add('create ${input.displayName}');
    _maybeFail('create');
    final id = 'recipe-new-${++_next}';
    drafts[id] = RecipeDraft(
      displayName: input.displayName,
      exportKey: input.exportKey,
      description: input.description,
      outputItemId: input.outputItemId,
      outputQuantity: input.outputQuantity,
      craftingStationId: input.craftingStationId,
      craftingSpecializationId: input.craftingSpecializationId,
    );
    return _record(id);
  }

  @override
  Future<RecipeDraft> save(String id, RecipeDraft draft) async {
    calls.add('save $id');
    _maybeFail('save');
    _draft(id);
    final blockers = recipeSaveBlockers(draft);
    if (blockers.isNotEmpty) {
      throw SaveBlocked([for (final b in blockers) b.message]);
    }
    drafts[id] = draft;
    return draft.copyWith();
  }

  @override
  Future<RecipeRecord> duplicate(String id) async {
    calls.add('duplicate $id');
    _maybeFail('duplicate');
    final source = _draft(id);
    final copy = 'recipe-copy-${++_next}';
    drafts[copy] = source.copyWith(
      displayName: '${source.displayName} (Copy)',
      exportKey: '${source.exportKey}-copy$_next',
    );
    return _record(copy);
  }

  @override
  Future<void> softDelete(String id) async {
    calls.add('softDelete $id');
    _draft(id);
    deleted[id] ??= '2026-11-01 09:00:00';
  }

  @override
  Future<void> restore(String id) async {
    calls.add('restore $id');
    _draft(id);
    deleted.remove(id);
  }

  @override
  Future<void> hardDelete(String id) async {
    calls.add('hardDelete $id');
    _draft(id);
    drafts.remove(id);
    deleted.remove(id);
  }
}

/// The item list only; the recipe pages read nothing else.
class FakeItemRepository implements ItemRepository {
  FakeItemRepository([List<ItemRecord>? items])
    : items = items ?? sampleItems();

  final List<ItemRecord> items;

  @override
  Future<List<ItemRecord>> list({
    RecordListMode mode = RecordListMode.active,
  }) async => [
    for (final i in items)
      if (switch (mode) {
        RecordListMode.active => i.deletedAt == null,
        RecordListMode.deletedOnly => i.deletedAt != null,
        RecordListMode.all => true,
      })
        i,
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeItemRepository: ${invocation.memberName}');
}

/// The crafting stations and specializations only.
class FakeCraftingMetaRepository implements MetaRepository {
  final stations = const [
    MetaCraftingStation(
      id: 'station-forge',
      displayName: 'Forge',
      exportKey: 'forge',
      description: '',
      sortOrder: 0,
    ),
    MetaCraftingStation(
      id: 'station-alchemy',
      displayName: 'Alchemy Table',
      exportKey: 'alchemy_table',
      description: '',
      sortOrder: 1,
    ),
  ];

  final specializations = const [
    MetaCraftingSpecialization(
      id: 'spec-blacksmithing',
      displayName: 'Blacksmithing',
      exportKey: 'blacksmithing',
      description: '',
      sortOrder: 0,
    ),
    MetaCraftingSpecialization(
      id: 'spec-alchemy',
      displayName: 'Alchemy',
      exportKey: 'alchemy',
      description: '',
      sortOrder: 1,
    ),
  ];

  @override
  Future<List<MetaCraftingStation>> listCraftingStations() async => stations;

  @override
  Future<List<MetaCraftingSpecialization>>
  listCraftingSpecializations() async => specializations;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'FakeCraftingMetaRepository: ${invocation.memberName}',
  );
}

/// The bulk operations over [FakeRecipeRepository]; nothing else.
class FakeRecipeLifecycle implements LifecycleRepository {
  FakeRecipeLifecycle(this.recipes);

  final FakeRecipeRepository recipes;

  @override
  Future<DeleteImpact> computeDeleteImpact(
    LifecycleDomain domain,
    List<String> ids,
  ) async => DeleteImpact(recordCount: ids.length, references: const []);

  @override
  Future<int> bulkSoftDelete(LifecycleDomain domain, List<String> ids) async {
    recipes.calls.add('bulkSoftDelete ${ids.join(',')}');
    for (final id in ids) {
      await recipes.softDelete(id);
    }
    return ids.length;
  }

  @override
  Future<int> bulkRestore(LifecycleDomain domain, List<String> ids) async {
    for (final id in ids) {
      await recipes.restore(id);
    }
    return ids.length;
  }

  @override
  Future<int> bulkHardDelete(LifecycleDomain domain, List<String> ids) async {
    for (final id in ids) {
      await recipes.hardDelete(id);
    }
    return ids.length;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeRecipeLifecycle: ${invocation.memberName}');
}

/// The record validation pass without a session: [issues] is what every
/// refresh answers, [refreshes] counts them.
class FakeRecordValidation extends RecordValidationNotifier {
  FakeRecordValidation(super.key, this.script);

  final RecipeTestScript script;

  @override
  List<ValidationIssue> build() => const [];

  @override
  List<ValidationIssue> refresh() {
    script.refreshes++;
    return state = script.issues;
  }
}

/// What the fake validation pass answers and how often it ran.
class RecipeTestScript {
  List<ValidationIssue> issues = const [];
  var refreshes = 0;
}

/// A container over the fakes, with retries off.
class RecipeTestHarness {
  RecipeTestHarness({List<ItemRecord>? items})
    : items = FakeItemRepository(items);

  final recipes = FakeRecipeRepository();
  final FakeItemRepository items;
  final meta = FakeCraftingMetaRepository();
  final script = RecipeTestScript();
  late final ProviderContainer container;

  int get epoch => container.read(writeEpochProvider);

  ProviderContainer build({List overrides = const []}) {
    final logs = Directory.systemTemp.createTempSync('anvil-recipe-logs');
    addTearDown(() => logs.deleteSync(recursive: true));
    container = ProviderContainer(
      overrides: [
        recipeRepositoryProvider.overrideWithValue(recipes),
        itemRepositoryProvider.overrideWithValue(items),
        metaRepositoryProvider.overrideWithValue(meta),
        lifecycleRepositoryProvider.overrideWithValue(
          FakeRecipeLifecycle(recipes),
        ),
        initialAppSettingsProvider.overrideWithValue(const AppSettings()),
        appLoggerProvider.overrideWithValue(
          AppLogger(directory: logs.path, minimumLevel: LogLevel.debug),
        ),
        recordValidationProvider.overrideWith2(
          (key) => FakeRecordValidation(key, script),
        ),
        ...overrides.cast(),
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    return container;
  }

  /// [child] in an Anvil-themed app over [container], 2000 px wide
  /// because the test font's square glyphs make the six-column table wider
  /// than the real fonts do.
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(2000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    build();
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
