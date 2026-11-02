/// An in-memory trash for the recycle bin tests: the six domain
/// repositories (only `list`) and a `LifecycleRepository` over one store,
/// with scripted failures and a recorded call log. No SQLite.
library;

import 'package:anvil/app/shell/shell_domain.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

/// One record of any domain.
class FakeEntry {
  FakeEntry(this.id, this.name, this.key, {this.deletedAt});

  final String id;
  final String name;
  final String key;
  String? deletedAt;
}

/// When the fakes soft-delete a record.
const fakeDeletedAt = '2026-11-01 09:00:00';

class FakeTrashStore {
  FakeTrashStore([Map<ShellDomain, List<FakeEntry>>? entries])
    : entries = {
        for (final d in ShellDomain.values) d: [...?entries?[d]],
      };

  final Map<ShellDomain, List<FakeEntry>> entries;
  final calls = <String>[];

  /// Thrown by the next call of that name (`list`, `bulkRestore`, ...), or
  /// of that name for one domain (`bulkRestore items`).
  final failures = <String, Object>{};

  void maybeFail(String call) {
    if (failures.remove(call) case final error?) throw error;
  }

  /// The soft-deleted entries of [domain], ordered by name ignoring case.
  List<FakeEntry> deleted(ShellDomain domain) {
    calls.add('list ${domain.name}');
    maybeFail('list');
    return entries[domain]!.where((e) => e.deletedAt != null).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// The names of [domain]'s soft-deleted entries.
  List<String> trashNames(ShellDomain domain) => [
    for (final e in entries[domain]!)
      if (e.deletedAt != null) e.name,
  ]..sort();

  /// The overrides wiring every repository provider to this store.
  List<Override> overrides(FakeTrashLifecycle lifecycle) => [
    classRepositoryProvider.overrideWithValue(_FakeClasses(this)),
    abilityRepositoryProvider.overrideWithValue(_FakeAbilities(this)),
    itemRepositoryProvider.overrideWithValue(_FakeItems(this)),
    recipeRepositoryProvider.overrideWithValue(_FakeRecipes(this)),
    npcRepositoryProvider.overrideWithValue(_FakeNpcs(this)),
    lootTableRepositoryProvider.overrideWithValue(_FakeLootTables(this)),
    lifecycleRepositoryProvider.overrideWithValue(lifecycle),
  ];
}

ShellDomain _shell(LifecycleDomain d) =>
    ShellDomain.values.firstWhere((s) => s.name == d.name);

/// `LifecycleRepository` over a [FakeTrashStore]: the calls the recycle
/// bin makes, logged as `bulkRestore items i-1,i-2` and `emptyTrash`.
class FakeTrashLifecycle extends Fake implements LifecycleRepository {
  FakeTrashLifecycle(this.store);

  final FakeTrashStore store;

  int _bulk(
    String name,
    LifecycleDomain domain,
    List<String> ids,
    bool Function(FakeEntry e) applies,
    void Function(List<FakeEntry> list, FakeEntry e) apply,
  ) {
    store.calls.add('$name ${domain.name} ${ids.join(',')}');
    store.maybeFail(name);
    store.maybeFail('$name ${domain.name}');
    final list = store.entries[_shell(domain)]!;
    var changed = 0;
    for (final id in ids) {
      final matches = list.where((e) => e.id == id && applies(e)).toList();
      for (final e in matches) {
        apply(list, e);
        changed++;
      }
    }
    return changed;
  }

  @override
  Future<RecordCounts> countDeleted() async => RecordCounts(
    classes: store.trashNames(ShellDomain.classes).length,
    abilities: store.trashNames(ShellDomain.abilities).length,
    items: store.trashNames(ShellDomain.items).length,
    recipes: store.trashNames(ShellDomain.recipes).length,
    npcs: store.trashNames(ShellDomain.npcs).length,
    lootTables: store.trashNames(ShellDomain.lootTables).length,
  );

  @override
  Future<int> bulkSoftDelete(LifecycleDomain domain, List<String> ids) async =>
      _bulk(
        'bulkSoftDelete',
        domain,
        ids,
        (e) => e.deletedAt == null,
        (_, e) => e.deletedAt = fakeDeletedAt,
      );

  @override
  Future<int> bulkRestore(LifecycleDomain domain, List<String> ids) async =>
      _bulk(
        'bulkRestore',
        domain,
        ids,
        (e) => e.deletedAt != null,
        (_, e) => e.deletedAt = null,
      );

  @override
  Future<int> bulkHardDelete(LifecycleDomain domain, List<String> ids) async =>
      _bulk('bulkHardDelete', domain, ids, (_) => true, (l, e) => l.remove(e));

  @override
  Future<int> emptyTrash() async {
    store.calls.add('emptyTrash');
    store.maybeFail('emptyTrash');
    var changed = 0;
    for (final list in store.entries.values) {
      final before = list.length;
      list.removeWhere((e) => e.deletedAt != null);
      changed += before - list.length;
    }
    return changed;
  }
}

const _ts = '2026-10-30 10:00:00';

class _FakeClasses extends Fake implements ClassRepository {
  _FakeClasses(this.store);
  final FakeTrashStore store;

  @override
  Future<List<ClassRecord>> list({
    RecordListMode mode = RecordListMode.active,
  }) async {
    expect(mode, RecordListMode.deletedOnly);
    return [
      for (final e in store.deleted(ShellDomain.classes))
        ClassRecord(
          id: e.id,
          displayName: e.name,
          exportKey: e.key,
          description: '',
          resourceMultiplier: 1,
          createdAt: _ts,
          updatedAt: _ts,
          deletedAt: e.deletedAt,
        ),
    ];
  }
}

class _FakeAbilities extends Fake implements AbilityRepository {
  _FakeAbilities(this.store);
  final FakeTrashStore store;

  @override
  Future<List<AbilityRecord>> list({
    RecordListMode mode = RecordListMode.active,
  }) async {
    expect(mode, RecordListMode.deletedOnly);
    return [
      for (final e in store.deleted(ShellDomain.abilities))
        AbilityRecord(
          id: e.id,
          displayName: e.name,
          exportKey: e.key,
          description: '',
          abilityType: '',
          resourceType: '',
          resourceCost: 0,
          cooldown: 0,
          statModifiers: const {},
          createdAt: _ts,
          updatedAt: _ts,
          deletedAt: e.deletedAt,
        ),
    ];
  }
}

class _FakeItems extends Fake implements ItemRepository {
  _FakeItems(this.store);
  final FakeTrashStore store;

  @override
  Future<List<ItemRecord>> list({
    RecordListMode mode = RecordListMode.active,
  }) async {
    expect(mode, RecordListMode.deletedOnly);
    return [
      for (final e in store.deleted(ShellDomain.items))
        ItemRecord(
          id: e.id,
          displayName: e.name,
          exportKey: e.key,
          description: '',
          itemCategoryId: 'cat',
          rarityId: 'rar',
          createdAt: _ts,
          updatedAt: _ts,
          deletedAt: e.deletedAt,
        ),
    ];
  }
}

class _FakeRecipes extends Fake implements RecipeRepository {
  _FakeRecipes(this.store);
  final FakeTrashStore store;

  @override
  Future<List<RecipeRecord>> list({
    RecordListMode mode = RecordListMode.active,
  }) async {
    expect(mode, RecordListMode.deletedOnly);
    return [
      for (final e in store.deleted(ShellDomain.recipes))
        RecipeRecord(
          id: e.id,
          displayName: e.name,
          exportKey: e.key,
          description: '',
          outputItemId: 'item',
          outputQuantity: 1,
          craftingStationId: null,
          craftingSpecializationId: null,
          createdAt: _ts,
          updatedAt: _ts,
          deletedAt: e.deletedAt,
        ),
    ];
  }
}

class _FakeNpcs extends Fake implements NpcRepository {
  _FakeNpcs(this.store);
  final FakeTrashStore store;

  @override
  Future<List<NpcRecord>> list({
    RecordListMode mode = RecordListMode.active,
  }) async {
    expect(mode, RecordListMode.deletedOnly);
    return [
      for (final e in store.deleted(ShellDomain.npcs))
        NpcRecord(
          id: e.id,
          displayName: e.name,
          exportKey: e.key,
          description: '',
          npcTypeId: 'type',
          lootTableId: null,
          combatStats: const {},
          createdAt: _ts,
          updatedAt: _ts,
          deletedAt: e.deletedAt,
        ),
    ];
  }
}

class _FakeLootTables extends Fake implements LootTableRepository {
  _FakeLootTables(this.store);
  final FakeTrashStore store;

  @override
  Future<List<LootTableRecord>> list({
    RecordListMode mode = RecordListMode.active,
  }) async {
    expect(mode, RecordListMode.deletedOnly);
    return [
      for (final e in store.deleted(ShellDomain.lootTables))
        LootTableRecord(
          id: e.id,
          displayName: e.name,
          exportKey: e.key,
          description: '',
          createdAt: _ts,
          updatedAt: _ts,
          deletedAt: e.deletedAt,
        ),
    ];
  }
}

/// The trash the page tests start from: one class, two items and one
/// recipe soft-deleted, an active item and ability, and nothing in the
/// other domains. The class and one item share the id `dup`, since ids are
/// unique only per table.
FakeTrashStore sampleTrash() => FakeTrashStore({
  ShellDomain.classes: [
    FakeEntry(
      'dup',
      'Old Warrior',
      'old_warrior',
      deletedAt: '2026-10-31 14:05:09',
    ),
  ],
  ShellDomain.abilities: [FakeEntry('a-1', 'Fireball', 'fireball')],
  ShellDomain.items: [
    FakeEntry(
      'i-1',
      'Iron Sword',
      'iron_sword',
      deletedAt: '2026-10-31 14:05:09',
    ),
    FakeEntry(
      'dup',
      'Bronze Axe',
      'bronze_axe',
      deletedAt: '2026-10-31 15:00:00',
    ),
    FakeEntry('i-3', 'Leather Cap', 'leather_cap'),
  ],
  ShellDomain.recipes: [
    FakeEntry(
      'r-1',
      'Brew Potion',
      'brew_potion',
      deletedAt: '2026-10-29 08:00:00',
    ),
  ],
});
