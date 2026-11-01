/// Loot table record, create input and draft.
///
/// Ported from the "Loot Tables" section of 0.1.6's
/// `src/shared/domain-types.ts`.
library;

import 'equality.dart';

/// A list row of the loot tables table; ports 0.1.6 `LootTableRecord`
/// (`BaseRecord`: the domain data lives in `loot_table_entries`).
class LootTableRecord {
  const LootTableRecord({
    required this.id,
    required this.displayName,
    required this.exportKey,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  final String id;
  final String displayName;
  final String exportKey;
  final String description;

  /// SQLite `datetime('now')` text, as 0.1.6 passes it through.
  final String createdAt;
  final String updatedAt;

  /// Set when the loot table is soft-deleted.
  final String? deletedAt;
}

/// Ports 0.1.6 `CreateLootTableInput`.
class CreateLootTableInput {
  const CreateLootTableInput({
    required this.displayName,
    required this.exportKey,
    this.description = '',
  });

  final String displayName;
  final String exportKey;
  final String description;
}

/// One drop entry; ports 0.1.6 `LootTableEntry` without `id`,
/// `lootTableId` and `sortOrder`. Entry rows get new ids on every save, the
/// owner is the draft's record, and the index in
/// [LootTableDraft.entries] is the `sort_order`.
class LootTableEntryDraft {
  LootTableEntryDraft({
    required this.itemId,
    required this.weight,
    this.quantityMin = 1,
    this.quantityMax = 1,
    Map<String, Object?> conditionalFlags = const {},
  }) : conditionalFlags = freezeJsonObject(conditionalFlags);

  final String itemId;

  /// Integer weight of at least 1 (`CHECK (weight > 0)`).
  final int weight;

  /// `CHECK (quantity_min > 0)`.
  final int quantityMin;

  /// `CHECK (quantity_max >= quantity_min)`.
  final int quantityMax;

  /// The `conditional_flags` JSON object decoded, deeply unmodifiable and
  /// compared by content.
  final Map<String, Object?> conditionalFlags;

  LootTableEntryDraft copyWith({
    String? itemId,
    int? weight,
    int? quantityMin,
    int? quantityMax,
    Map<String, Object?>? conditionalFlags,
  }) => LootTableEntryDraft(
    itemId: itemId ?? this.itemId,
    weight: weight ?? this.weight,
    quantityMin: quantityMin ?? this.quantityMin,
    quantityMax: quantityMax ?? this.quantityMax,
    conditionalFlags: conditionalFlags ?? this.conditionalFlags,
  );

  @override
  bool operator ==(Object other) =>
      other is LootTableEntryDraft &&
      other.itemId == itemId &&
      other.weight == weight &&
      other.quantityMin == quantityMin &&
      other.quantityMax == quantityMax &&
      jsonEquals(other.conditionalFlags, conditionalFlags);

  @override
  int get hashCode => Object.hash(
    itemId,
    weight,
    quantityMin,
    quantityMax,
    jsonHash(conditionalFlags),
  );

  @override
  String toString() =>
      'LootTableEntryDraft($itemId, $weight, $quantityMin, $quantityMax, '
      '$conditionalFlags)';
}

/// The editable value of one loot table; ports the fields of 0.1.6
/// `UpdateLootTableInput` plus its `LootTableEntry` rows.
class LootTableDraft {
  LootTableDraft({
    required this.displayName,
    required this.exportKey,
    this.description = '',
    List<LootTableEntryDraft> entries = const [],
  }) : entries = List.unmodifiable(entries);

  final String displayName;
  final String exportKey;
  final String description;

  /// Entries in order; the index is the `sort_order`.
  final List<LootTableEntryDraft> entries;

  LootTableDraft copyWith({
    String? displayName,
    String? exportKey,
    String? description,
    List<LootTableEntryDraft>? entries,
  }) => LootTableDraft(
    displayName: displayName ?? this.displayName,
    exportKey: exportKey ?? this.exportKey,
    description: description ?? this.description,
    entries: entries ?? this.entries,
  );

  @override
  bool operator ==(Object other) =>
      other is LootTableDraft &&
      other.displayName == displayName &&
      other.exportKey == exportKey &&
      other.description == description &&
      listEquals(other.entries, entries);

  @override
  int get hashCode =>
      Object.hash(displayName, exportKey, description, listHash(entries));

  @override
  String toString() =>
      'LootTableDraft($displayName, $exportKey, $description, $entries)';
}
