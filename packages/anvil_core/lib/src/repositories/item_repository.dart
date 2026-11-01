import '../domain/equality.dart';
import '../domain/item_types.dart';
import '../domain/record_list_mode.dart';
import '../domain/used_by.dart';

/// The active records that reference one item; 0.1.6 `ItemUsedBy`.
class ItemUsedBy {
  ItemUsedBy({
    required List<UsedByRef> recipes,
    required List<UsedByRef> lootTables,
  }) : recipes = List.unmodifiable(recipes),
       lootTables = List.unmodifiable(lootTables);

  /// Recipes that use the item as an ingredient or as their output, each
  /// once, ordered by display name ignoring case.
  final List<UsedByRef> recipes;

  /// Loot tables with an entry for the item, each once, ordered by display
  /// name ignoring case.
  final List<UsedByRef> lootTables;

  @override
  bool operator ==(Object other) =>
      other is ItemUsedBy &&
      listEquals(other.recipes, recipes) &&
      listEquals(other.lootTables, lootTables);

  @override
  int get hashCode => Object.hash(listHash(recipes), listHash(lootTables));

  @override
  String toString() => 'ItemUsedBy($recipes, $lootTables)';
}

/// The items domain: replaces 0.1.6's `items:*` channels and the item side
/// of `custom-fields:get-values` / `set-values`.
///
/// Every mutation is one save transaction with one save history row.
///
/// Errors: [get], [load], [save], [duplicate], [softDelete], [restore] and
/// [hardDelete] throw `RecordNotFound('items', id)` for an unknown id;
/// [save] also throws it for a soft-deleted item. [save] throws
/// `SaveBlocked` when `itemSaveBlockers` reports anything, before any
/// write. [create] and [save] throw `DuplicateExportKey(key)` when another
/// item (soft-deleted ones included) has the export key. Any other SQLite
/// failure, such as a foreign key that refuses a hard delete of an item a
/// recipe or loot table still references, is `SaveFailed`.
abstract interface class ItemRepository {
  /// Ordered by display name ignoring case.
  Future<List<ItemRecord>> list({RecordListMode mode = RecordListMode.active});

  /// Items that are not soft-deleted.
  Future<int> countActive();

  /// The row, soft-deleted or not.
  Future<ItemRecord> get(String id);

  /// The draft of any existing item, soft-deleted or not, with every
  /// `custom_field_values` row the item has.
  Future<ItemDraft> load(String id);

  /// Inserts an item with no custom field values; recorded as
  /// `<name> - Item created`.
  Future<ItemRecord> create(CreateItemInput input);

  /// Writes [draft] to the active item [id] and returns it as read back;
  /// recorded as `<name> - Item changed`.
  ///
  /// The item's `custom_field_values` rows are replaced by
  /// [ItemDraft.customFieldValues] as given, a `null` value stored as a
  /// row with `NULL`, as 0.1.6's `setCustomFieldValues` did. When the
  /// draft moves the item to another category, values whose definition is
  /// not scoped to the new category are then deleted, as 0.1.6's `update`
  /// did on a category change.
  Future<ItemDraft> save(String id, ItemDraft draft);

  /// Copies the item as `<name> (Copy)` with a fresh export key and the
  /// values of the custom fields scoped to its category; recorded as
  /// `<name> (Copy) - Item duplicated`.
  Future<ItemRecord> duplicate(String id);

  /// Recorded as `<name> - Item deleted`; an already deleted item keeps its
  /// `deleted_at`.
  Future<void> softDelete(String id);

  /// Recorded as `<name> - Item restored`.
  Future<void> restore(String id);

  /// Deletes the item and its custom field values; recorded as
  /// `<name> - Item permanently deleted`.
  Future<void> hardDelete(String id);

  /// The active recipes and loot tables that reference the item; empty
  /// lists for an unknown id, as 0.1.6.
  Future<ItemUsedBy> usedBy(String id);
}
