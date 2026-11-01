import '../domain/npc_types.dart';
import '../domain/record_list_mode.dart';

/// The NPCs domain: replaces 0.1.6's `npcs:*` channels and the NPC side of
/// `custom-fields:get-values` / `set-values`.
///
/// The draft carries the NPC row (combat stat overrides included), its
/// class assignments, ability assignments and custom field values, which
/// load and save as one unit. Nothing references an NPC, so there is no
/// `usedBy`.
///
/// Every mutation is one save transaction with one save history row.
///
/// Errors: [get], [load], [save], [duplicate], [softDelete], [restore],
/// [hardDelete] and [inheritedStatBlock] throw `RecordNotFound('npcs', id)`
/// for an unknown id; [save] also throws it for a soft-deleted NPC. [save]
/// throws `SaveBlocked` when `npcSaveBlockers` reports anything, before any
/// write. [create] and [save] throw `DuplicateExportKey(key)` when another
/// NPC (soft-deleted ones included) has the export key. Any other SQLite
/// failure, such as a type, class, ability or loot table id that does not
/// exist, is `SaveFailed`.
abstract interface class NpcRepository {
  /// Ordered by display name ignoring case.
  Future<List<NpcRecord>> list({RecordListMode mode = RecordListMode.active});

  /// NPCs that are not soft-deleted.
  Future<int> countActive();

  /// The row, soft-deleted or not.
  Future<NpcRecord> get(String id);

  /// The draft of any existing NPC, soft-deleted or not: class and ability
  /// assignments by `sort_order`, combat stats in their stored key order,
  /// and every `custom_field_values` row the NPC has.
  Future<NpcDraft> load(String id);

  /// Inserts an NPC with no assignments and no custom field values;
  /// recorded as `<name> - NPC created`.
  Future<NpcRecord> create(CreateNpcInput input);

  /// Writes [draft] to the active NPC [id] and returns it as read back;
  /// recorded as `<name> - NPC changed`.
  ///
  /// Class and ability assignments are replaced with `sort_order` as the
  /// list index. The custom field values are replaced by
  /// [NpcDraft.customFieldValues] as given, a `null` value stored as a row
  /// with `NULL`; when the draft moves the NPC to another type, values
  /// whose definition is not scoped to the new type are then deleted, as
  /// 0.1.6's `update` did on a type change.
  Future<NpcDraft> save(String id, NpcDraft draft);

  /// Copies the NPC as `<name> (Copy)` with a fresh export key, its class
  /// and ability assignments and the values of the custom fields scoped to
  /// its type; recorded as `<name> (Copy) - NPC duplicated`.
  Future<NpcRecord> duplicate(String id);

  /// Recorded as `<name> - NPC deleted`; an already deleted NPC keeps its
  /// `deleted_at`.
  Future<void> softDelete(String id);

  /// Recorded as `<name> - NPC restored`.
  Future<void> restore(String id);

  /// Deletes the NPC and its custom field values; its assignments cascade.
  /// Recorded as `<name> - NPC permanently deleted`.
  Future<void> hardDelete(String id);

  /// The inherited value of every project stat, in stat `sort_order`: the
  /// sum over the NPC's stored class assignments of each class's resolved
  /// stat growth (formulas evaluated up to the project's `max_level`) at
  /// the assigned level, as 0.1.6's stat block panel showed in its
  /// "Inherited" column (`computeNpcStatBlock`). Combat stat overrides are
  /// not applied.
  Future<Map<String, double>> inheritedStatBlock(String id);
}
