/// An in-memory recipe list for the list scaffold's widget tests: the
/// store, a [ListDomainAdapter] over it and a [LifecycleRepository] over
/// it, with scripted failures and a recorded call log. No SQLite.
library;

import 'dart:async';

import 'package:anvil/app/lists/list_domain_adapter.dart';
import 'package:anvil/app/shell/shell_domain.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/widgets.dart';

RecipeRecord recipe(
  String id,
  String name,
  String key, {
  String output = 'item-sword',
  String? deletedAt,
}) => RecipeRecord(
  id: id,
  displayName: name,
  exportKey: key,
  description: '',
  outputItemId: output,
  outputQuantity: 1,
  craftingStationId: null,
  craftingSpecializationId: null,
  createdAt: '2026-10-30 10:00:00',
  updatedAt: '2026-10-30 10:00:00',
  deletedAt: deletedAt,
);

/// Three active recipes and one archived.
List<RecipeRecord> sampleRecipes() => [
  recipe('r-sword', 'Forge Iron Sword', 'forge_iron_sword'),
  recipe('r-potion', 'Brew Potion', 'brew_potion', output: 'item-potion'),
  recipe('r-leather', 'Tan Leather', 'leather_tanning', output: 'item-hide'),
  recipe('r-old', 'Old Recipe', 'old_recipe', deletedAt: '2026-10-31 14:05:09'),
];

class FakeRecipeListStore {
  FakeRecipeListStore([List<RecipeRecord>? rows])
    : rows = rows ?? sampleRecipes();

  final List<RecipeRecord> rows;
  final calls = <String>[];

  /// Thrown by the next call of that name (`list`, `softDelete`, ...).
  final failures = <String, Object>{};

  var _copies = 0;

  void _maybeFail(String call) {
    if (failures.remove(call) case final error?) throw error;
  }

  int _index(String id) {
    final i = rows.indexWhere((r) => r.id == id);
    if (i < 0) throw RecordNotFound('recipes', id);
    return i;
  }

  RecipeRecord _withDeleted(RecipeRecord r, String? deletedAt) => recipe(
    r.id,
    r.displayName,
    r.exportKey,
    output: r.outputItemId,
    deletedAt: deletedAt,
  );

  void softDelete(String id) {
    final i = _index(id);
    rows[i] = _withDeleted(rows[i], rows[i].deletedAt ?? '2026-11-01 09:00:00');
  }

  void restore(String id) {
    final i = _index(id);
    rows[i] = _withDeleted(rows[i], null);
  }

  void hardDelete(String id) => rows.removeAt(_index(id));
}

class FakeRecipeListAdapter
    with ListAdapterDefaults<RecipeRecord>
    implements ListDomainAdapter<RecipeRecord> {
  FakeRecipeListAdapter(this.store);

  final FakeRecipeListStore store;

  @override
  ShellDomain get domain => ShellDomain.recipes;

  @override
  Future<List<RecipeRecord>> list(RecordListMode mode) async {
    store.calls.add('list ${mode.name}');
    store._maybeFail('list');
    final rows = store.rows.where(
      (r) => switch (mode) {
        RecordListMode.active => r.deletedAt == null,
        RecordListMode.deletedOnly => r.deletedAt != null,
        RecordListMode.all => true,
      },
    );
    return rows.toList()
      ..sort((a, b) => compareIgnoringCase(a.displayName, b.displayName));
  }

  @override
  String idOf(RecipeRecord row) => row.id;

  @override
  String displayNameOf(RecipeRecord row) => row.displayName;

  @override
  String exportKeyOf(RecipeRecord row) => row.exportKey;

  @override
  String? deletedAtOf(RecipeRecord row) => row.deletedAt;

  @override
  List<ListColumn<RecipeRecord>> get columns => [
    ListColumn(
      label: 'Output',
      cell: (context, row) => Text(row.outputItemId),
      compare: (a, b) => a.outputItemId.compareTo(b.outputItemId),
    ),
  ];

  @override
  Future<void> softDelete(String id) async {
    store.calls.add('softDelete $id');
    store._maybeFail('softDelete');
    store.softDelete(id);
  }

  @override
  Future<void> restore(String id) async {
    store.calls.add('restore $id');
    store._maybeFail('restore');
    store.restore(id);
  }

  @override
  Future<void> hardDelete(String id) async {
    store.calls.add('hardDelete $id');
    store._maybeFail('hardDelete');
    store.hardDelete(id);
  }

  @override
  Future<RecipeRecord?> duplicate(String id) async {
    store.calls.add('duplicate $id');
    store._maybeFail('duplicate');
    final source = store.rows[store._index(id)];
    final copy = recipe(
      '${source.id}-copy${++store._copies}',
      '${source.displayName} (Copy)',
      '${source.exportKey}-copy${store._copies}',
      output: source.outputItemId,
    );
    store.rows.add(copy);
    return copy;
  }
}

/// The bulk operations over the same store; [impact] is what
/// [computeDeleteImpact] answers, after [impactGate] completes when set.
class FakeLifecycleRepository implements LifecycleRepository {
  FakeLifecycleRepository(this.store);

  final FakeRecipeListStore store;
  DeleteImpact? impact;
  Completer<void>? impactGate;

  @override
  Future<DeleteImpact> computeDeleteImpact(
    LifecycleDomain domain,
    List<String> ids,
  ) async {
    store.calls.add('impact ${domain.value} ${ids.join(',')}');
    await impactGate?.future;
    store._maybeFail('impact');
    return impact ?? DeleteImpact(recordCount: ids.length, references: []);
  }

  @override
  Future<int> bulkSoftDelete(LifecycleDomain domain, List<String> ids) async {
    store.calls.add('bulkSoftDelete ${domain.value} ${ids.join(',')}');
    store._maybeFail('bulkSoftDelete');
    ids.forEach(store.softDelete);
    return ids.length;
  }

  @override
  Future<int> bulkRestore(LifecycleDomain domain, List<String> ids) async {
    store.calls.add('bulkRestore ${domain.value} ${ids.join(',')}');
    store._maybeFail('bulkRestore');
    ids.forEach(store.restore);
    return ids.length;
  }

  @override
  Future<int> bulkHardDelete(LifecycleDomain domain, List<String> ids) async {
    store.calls.add('bulkHardDelete ${domain.value} ${ids.join(',')}');
    store._maybeFail('bulkHardDelete');
    ids.forEach(store.hardDelete);
    return ids.length;
  }

  @override
  Future<RecordCounts> countDeleted() => throw UnimplementedError();

  @override
  Future<int> emptyTrash() => throw UnimplementedError();

  @override
  Future<RecordCounts> weeklyDeltas() => throw UnimplementedError();
}
