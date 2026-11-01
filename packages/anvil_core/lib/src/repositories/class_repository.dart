import '../domain/class_types.dart';
import '../domain/record_list_mode.dart';
import '../domain/used_by.dart';

/// Character classes: replaces 0.1.6's `classes:*` channels
/// (`classes.handlers.ts`, `class.repository.ts`).
///
/// The draft carries the class row and its five junction lists (manual stat
/// growth, stat growth formulas, ability assignments, derived stat overrides
/// and metadata fields), which load and save as one unit.
///
/// Every mutation is one save transaction with one save-history row:
/// `<name> - Class changed` / `created` / `duplicated` / `deleted` /
/// `restored` / `permanently deleted`.
///
/// Errors: [get], [load], [save], [duplicate], [softDelete], [restore],
/// [hardDelete] and [resolvedStatGrowth] throw `RecordNotFound('classes',
/// id)` for an unknown id ([save] also for a soft-deleted one); [save]
/// throws `SaveBlocked` when `classSaveBlockers` is non-empty; [create] and
/// [save] throw `DuplicateExportKey(key)` for a key another class holds; a
/// write SQLite refuses (a missing stat, ability or derived stat, or a hard
/// delete while NPCs still reference the class) throws `SaveFailed`.
abstract interface class ClassRepository {
  /// Ordered by display name, ignoring case.
  Future<List<ClassRecord>> list({RecordListMode mode = RecordListMode.active});

  /// Classes that are not soft-deleted.
  Future<int> countActive();

  /// The row, soft-deleted or not.
  Future<ClassRecord> get(String id);

  /// The draft of a class, soft-deleted or not: manual stat growth by stat
  /// and level, ability assignments by `sort_order`, metadata fields by
  /// key, as 0.1.6 read them.
  Future<ClassDraft> load(String id);

  /// Inserts a class with no junction data.
  Future<ClassRecord> create(CreateClassInput input);

  /// Writes [draft] over the active class [id], replacing every junction
  /// list (ability assignment `sort_order` is the list index), and returns
  /// the draft as read back.
  Future<ClassDraft> save(String id, ClassDraft draft);

  /// Copies the class as `<name> (Copy)` with a fresh export key and every
  /// junction list.
  Future<ClassRecord> duplicate(String id);

  /// Sets `deleted_at` (kept if already set) and bumps `updated_at`.
  Future<void> softDelete(String id);

  /// Clears `deleted_at` and bumps `updated_at`.
  Future<void> restore(String id);

  /// Deletes the row; its junction rows cascade.
  Future<void> hardDelete(String id);

  /// Active NPCs assigned this class, by display name ignoring case. Empty
  /// for an unknown id, as in 0.1.6.
  Future<List<UsedByRef>> usedBy(String id);

  /// The class's stat growth with formulas evaluated up to the project's
  /// `max_level` (see `resolveStatGrowth`).
  Future<Map<StatGrowthKey, double>> resolvedStatGrowth(String id);
}
