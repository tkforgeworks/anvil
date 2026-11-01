import '../domain/loot_table_types.dart';
import '../domain/record_list_mode.dart';
import '../domain/used_by.dart';

/// The loot tables domain: replaces 0.1.6's `loot-tables:*` channels.
///
/// Every mutation is one save transaction with one save history row.
///
/// Errors: [get], [load], [save], [duplicate], [softDelete], [restore] and
/// [hardDelete] throw `RecordNotFound('loot_tables', id)` for an unknown
/// id; [save] also throws it for a soft-deleted loot table. [save] throws
/// `SaveBlocked` when `lootTableSaveBlockers` reports anything, before any
/// write (0.1.6 clamped the values instead). [create] and [save] throw
/// `DuplicateExportKey(key)` when another loot table (soft-deleted ones
/// included) has the export key. Any other SQLite failure, such as the
/// foreign key that refuses a hard delete of a table an NPC still
/// references, is `SaveFailed`.
abstract interface class LootTableRepository {
  /// Ordered by display name ignoring case.
  Future<List<LootTableRecord>> list({
    RecordListMode mode = RecordListMode.active,
  });

  /// Loot tables that are not soft-deleted.
  Future<int> countActive();

  /// The row, soft-deleted or not.
  Future<LootTableRecord> get(String id);

  /// The draft of any existing loot table, soft-deleted or not, with its
  /// entries in `sort_order`.
  Future<LootTableDraft> load(String id);

  /// Inserts a loot table with no entries; recorded as
  /// `<name> - Loot Table created`.
  Future<LootTableRecord> create(CreateLootTableInput input);

  /// Writes [draft] to the active loot table [id] and returns it as read
  /// back; recorded as `<name> - Loot Table changed`. The entries are
  /// replaced: every entry row gets a new id, `sort_order` is the list
  /// index and `conditional_flags` is the JSON text of the entry's flags.
  Future<LootTableDraft> save(String id, LootTableDraft draft);

  /// Copies the loot table and its entries (with new ids) as
  /// `<name> (Copy)` with a fresh export key; recorded as
  /// `<name> (Copy) - Loot Table duplicated`.
  Future<LootTableRecord> duplicate(String id);

  /// Recorded as `<name> - Loot Table deleted`; an already deleted table
  /// keeps its `deleted_at`.
  Future<void> softDelete(String id);

  /// Recorded as `<name> - Loot Table restored`.
  Future<void> restore(String id);

  /// Deletes the loot table; its entries cascade. Recorded as
  /// `<name> - Loot Table permanently deleted`.
  Future<void> hardDelete(String id);

  /// The active NPCs that drop from the loot table, ordered by display name
  /// ignoring case; empty for an unknown id, as 0.1.6.
  Future<List<UsedByRef>> usedBy(String id);
}
