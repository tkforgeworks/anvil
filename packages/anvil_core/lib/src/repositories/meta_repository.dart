import '../domain/meta.dart';

/// The answer to "can this meta row be deleted?"; 0.1.6 `MetaInUseResult`.
class MetaInUseResult {
  const MetaInUseResult.free() : inUse = false, reason = null;
  const MetaInUseResult.used(String this.reason) : inUse = true;

  final bool inUse;

  /// The 0.1.6 message, such as `Rarity is used by 2 item(s).`; null when
  /// the row is free.
  final String? reason;

  @override
  bool operator ==(Object other) =>
      other is MetaInUseResult &&
      other.inUse == inUse &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(inUse, reason);

  @override
  String toString() => 'MetaInUseResult($inUse, $reason)';
}

/// The meta layer and the project settings: replaces 0.1.6's `meta:*`
/// channels (`meta.handlers.ts`).
///
/// Every mutation is one save transaction recorded in the save history as
/// `Project settings changed`, the description 0.1.6 gave any meta change.
///
/// Errors: `updateX`, `deleteX` and [saveProjectSettings] throw
/// `RecordNotFound(table, id)` for an id that is not in the table; `deleteX`
/// and [saveProjectSettings] throw `MetaInUse(kind, counts)` for a row that
/// records still use (see [checkInUse]); a clashing export key throws
/// `DuplicateExportKey`.
abstract interface class MetaRepository {
  /// Ordered by `sort_order` only, as 0.1.6.
  Future<List<MetaStat>> listStats();

  /// Ordered by `sort_order`, then display name ignoring case.
  Future<List<MetaRarity>> listRarities();

  /// Ordered by `sort_order`, then display name ignoring case.
  Future<List<MetaItemCategory>> listItemCategories();

  /// Ordered by `sort_order`, then display name ignoring case.
  Future<List<MetaNpcType>> listNpcTypes();

  /// Ordered by `sort_order`, then display name ignoring case.
  Future<List<MetaCraftingStation>> listCraftingStations();

  /// Ordered by `sort_order`, then display name ignoring case.
  Future<List<MetaCraftingSpecialization>> listCraftingSpecializations();

  /// Ordered by `sort_order` only, as 0.1.6.
  Future<List<DerivedStatDefinition>> listDerivedStats();

  /// Appends with `sort_order = MAX(sort_order) + 1` (1 for an empty list).
  Future<MetaStat> addStat(MetaItemInput input);
  Future<MetaStat> updateStat(String id, MetaItemInput input);
  Future<void> deleteStat(String id);

  /// Sets `sort_order` to each id's index in [ids]; unknown ids are skipped.
  Future<void> reorderStats(List<String> ids);

  Future<MetaRarity> addRarity(MetaRarityInput input);
  Future<MetaRarity> updateRarity(String id, MetaRarityInput input);
  Future<void> deleteRarity(String id);
  Future<void> reorderRarities(List<String> ids);

  Future<MetaItemCategory> addItemCategory(MetaItemInput input);
  Future<MetaItemCategory> updateItemCategory(String id, MetaItemInput input);
  Future<void> deleteItemCategory(String id);
  Future<void> reorderItemCategories(List<String> ids);

  Future<MetaNpcType> addNpcType(MetaItemInput input);
  Future<MetaNpcType> updateNpcType(String id, MetaItemInput input);
  Future<void> deleteNpcType(String id);
  Future<void> reorderNpcTypes(List<String> ids);

  Future<MetaCraftingStation> addCraftingStation(MetaItemInput input);
  Future<MetaCraftingStation> updateCraftingStation(
    String id,
    MetaItemInput input,
  );
  Future<void> deleteCraftingStation(String id);
  Future<void> reorderCraftingStations(List<String> ids);

  Future<MetaCraftingSpecialization> addCraftingSpecialization(
    MetaItemInput input,
  );
  Future<MetaCraftingSpecialization> updateCraftingSpecialization(
    String id,
    MetaItemInput input,
  );
  Future<void> deleteCraftingSpecialization(String id);
  Future<void> reorderCraftingSpecializations(List<String> ids);

  Future<DerivedStatDefinition> addDerivedStat(DerivedStatInput input);
  Future<DerivedStatDefinition> updateDerivedStat(
    String id,
    DerivedStatInput input,
  );
  Future<void> deleteDerivedStat(String id);
  Future<void> reorderDerivedStats(List<String> ids);

  /// Whether active records still reference the row; never mutates.
  Future<MetaInUseResult> checkInUse(MetaInUseKind kind, String id);

  /// The three `project_info` scalars and the five buffered lists in order.
  Future<ProjectSettingsDraft> loadProjectSettings();

  /// Commits [draft] in one transaction: the scalars, then for stats,
  /// rarities, crafting stations, crafting specializations and derived
  /// stats in turn, deletes rows absent from the draft (refused while in
  /// use), updates changed rows, inserts `new:` rows with fresh ids and
  /// fixes the order. Any refusal rolls the whole save back. Returns the
  /// settings as read back.
  Future<ProjectSettingsDraft> saveProjectSettings(ProjectSettingsDraft draft);
}
