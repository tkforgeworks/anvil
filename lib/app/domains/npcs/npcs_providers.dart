/// What the NPC list and editor read besides the draft: NPC types, loot
/// tables, classes, abilities, items (for the loot table's entries), the
/// project's stats and max level, one type's custom field definitions, one
/// class's resolved stat growth and one loot table's entries. Each is
/// re-read on every `writeEpochProvider` bump, so a write anywhere
/// refreshes it, and keeps its previous value readable while it reloads.
///
/// Only these providers watch the repository providers; the widgets watch
/// these (the ANVL-185 rule).
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shell/shell_providers.dart';

/// 0.1.6's `DEFAULT_MAX_LEVEL`, the clamp until the project's max level
/// has loaded.
const defaultNpcMaxLevel = 20;

/// The project's NPC types in their settings order.
final npcTypesProvider = FutureProvider.autoDispose<List<MetaNpcType>>((ref) {
  ref.watch(writeEpochProvider);
  return ref.watch(metaRepositoryProvider).listNpcTypes();
});

/// Every loot table, soft-deleted ones included so an assigned deleted
/// table still shows its name.
final npcLootTablesProvider = FutureProvider.autoDispose<List<LootTableRecord>>(
  (ref) {
    ref.watch(writeEpochProvider);
    return ref
        .watch(lootTableRepositoryProvider)
        .list(mode: RecordListMode.all);
  },
);

/// Every class, soft-deleted ones included (0.1.6 `classesApi.list(true)`).
final npcClassesProvider = FutureProvider.autoDispose<List<ClassRecord>>((ref) {
  ref.watch(writeEpochProvider);
  return ref.watch(classRepositoryProvider).list(mode: RecordListMode.all);
});

/// Every ability, soft-deleted ones included.
final npcAbilitiesProvider = FutureProvider.autoDispose<List<AbilityRecord>>((
  ref,
) {
  ref.watch(writeEpochProvider);
  return ref.watch(abilityRepositoryProvider).list(mode: RecordListMode.all);
});

/// Every item, soft-deleted ones included, for the loot table's entries.
final npcItemsProvider = FutureProvider.autoDispose<List<ItemRecord>>((ref) {
  ref.watch(writeEpochProvider);
  return ref.watch(itemRepositoryProvider).list(mode: RecordListMode.all);
});

/// The project's stats; the stat block orders them by `sortOrder`.
final npcStatsProvider = FutureProvider.autoDispose<List<MetaStat>>((ref) {
  ref.watch(writeEpochProvider);
  return ref.watch(metaRepositoryProvider).listStats();
});

/// The project's max level (`project_info.max_level`), the upper clamp of
/// a class assignment's level.
final npcMaxLevelProvider = FutureProvider.autoDispose<int>((ref) async {
  ref.watch(writeEpochProvider);
  final settings = await ref
      .watch(metaRepositoryProvider)
      .loadProjectSettings();
  return settings.maxLevel;
});

/// The custom field definitions scoped to one NPC type, in `sort_order`.
final npcCustomFieldDefinitionsProvider = FutureProvider.autoDispose
    .family<List<CustomFieldDefinition>, String>((ref, typeId) {
      ref.watch(writeEpochProvider);
      return ref
          .watch(customFieldRepositoryProvider)
          .listDefinitions(CustomFieldScope.npcType, typeId);
    });

/// Class [classId]'s resolved stat growth (formulas evaluated up to the
/// max level), the per-class input of `computeNpcStatBlock`.
final classGrowthProvider = FutureProvider.autoDispose
    .family<Map<StatGrowthKey, double>, String>((ref, classId) {
      ref.watch(writeEpochProvider);
      return ref.watch(classRepositoryProvider).resolvedStatGrowth(classId);
    });

/// The entries of loot table [id], shown read-only under the picker as
/// 0.1.6's `LootTableAssignmentPanel` did.
final npcLootTableEntriesProvider = FutureProvider.autoDispose
    .family<List<LootTableEntryDraft>, String>((ref, id) async {
      ref.watch(writeEpochProvider);
      final draft = await ref.watch(lootTableRepositoryProvider).load(id);
      return draft.entries;
    });
