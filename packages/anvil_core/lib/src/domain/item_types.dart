/// Item record, create input and draft.
///
/// Ported from the "Items" section of 0.1.6's `src/shared/domain-types.ts`.
library;

import 'equality.dart';

/// A list row of the items table; ports 0.1.6 `ItemRecord`.
class ItemRecord {
  const ItemRecord({
    required this.id,
    required this.displayName,
    required this.exportKey,
    required this.description,
    required this.itemCategoryId,
    required this.rarityId,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  final String id;
  final String displayName;
  final String exportKey;
  final String description;
  final String itemCategoryId;
  final String rarityId;

  /// SQLite `datetime('now')` text, as 0.1.6 passes it through.
  final String createdAt;
  final String updatedAt;

  /// Set when the item is soft-deleted.
  final String? deletedAt;
}

/// Ports 0.1.6 `CreateItemInput`.
class CreateItemInput {
  const CreateItemInput({
    required this.displayName,
    required this.exportKey,
    this.description = '',
    required this.itemCategoryId,
    required this.rarityId,
  });

  final String displayName;
  final String exportKey;
  final String description;
  final String itemCategoryId;
  final String rarityId;
}

/// The editable value of one item; ports the fields of 0.1.6
/// `UpdateItemInput` plus the item's `CustomFieldValue` rows.
class ItemDraft {
  ItemDraft({
    required this.displayName,
    required this.exportKey,
    this.description = '',
    required this.itemCategoryId,
    required this.rarityId,
    Map<String, String?> customFieldValues = const {},
  }) : customFieldValues = Map.unmodifiable(customFieldValues);

  final String displayName;
  final String exportKey;
  final String description;
  final String itemCategoryId;
  final String rarityId;

  /// Category-scoped custom field values by field definition id; values are
  /// text whatever the field type, `null` when unset.
  final Map<String, String?> customFieldValues;

  ItemDraft copyWith({
    String? displayName,
    String? exportKey,
    String? description,
    String? itemCategoryId,
    String? rarityId,
    Map<String, String?>? customFieldValues,
  }) => ItemDraft(
    displayName: displayName ?? this.displayName,
    exportKey: exportKey ?? this.exportKey,
    description: description ?? this.description,
    itemCategoryId: itemCategoryId ?? this.itemCategoryId,
    rarityId: rarityId ?? this.rarityId,
    customFieldValues: customFieldValues ?? this.customFieldValues,
  );

  @override
  bool operator ==(Object other) =>
      other is ItemDraft &&
      other.displayName == displayName &&
      other.exportKey == exportKey &&
      other.description == description &&
      other.itemCategoryId == itemCategoryId &&
      other.rarityId == rarityId &&
      mapEquals(other.customFieldValues, customFieldValues);

  @override
  int get hashCode => Object.hash(
    displayName,
    exportKey,
    description,
    itemCategoryId,
    rarityId,
    mapHash(customFieldValues),
  );

  @override
  String toString() =>
      'ItemDraft($displayName, $exportKey, $description, $itemCategoryId, '
      '$rarityId, $customFieldValues)';
}
