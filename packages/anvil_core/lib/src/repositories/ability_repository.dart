import '../domain/ability_types.dart';
import '../domain/record_list_mode.dart';
import '../domain/used_by.dart';

/// The active records that reference an ability; 0.1.6 `AbilityUsedBy`.
class AbilityUsedBy {
  AbilityUsedBy({
    required List<UsedByRef> classes,
    required List<UsedByRef> npcs,
  }) : classes = List.unmodifiable(classes),
       npcs = List.unmodifiable(npcs);

  /// Active classes with the ability assigned, by display name ignoring
  /// case.
  final List<UsedByRef> classes;

  /// Active NPCs with the ability assigned, by display name ignoring case.
  final List<UsedByRef> npcs;

  @override
  bool operator ==(Object other) =>
      other is AbilityUsedBy &&
      _sameRefs(other.classes, classes) &&
      _sameRefs(other.npcs, npcs);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(classes), Object.hashAll(npcs));

  @override
  String toString() => 'AbilityUsedBy(classes: $classes, npcs: $npcs)';
}

bool _sameRefs(List<UsedByRef> a, List<UsedByRef> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Abilities: replaces 0.1.6's `abilities:*` channels
/// (`abilities.handlers.ts`, `ability.repository.ts`).
///
/// Every mutation is one save transaction with one save-history row:
/// `<name> - Ability changed` / `created` / `duplicated` / `deleted` /
/// `restored` / `permanently deleted`.
///
/// Errors: [get], [load], [save], [duplicate], [softDelete], [restore] and
/// [hardDelete] throw `RecordNotFound('abilities', id)` for an unknown id
/// ([save] also for a soft-deleted one); [save] throws `SaveBlocked` when
/// `abilitySaveBlockers` is non-empty; [create] and [save] throw
/// `DuplicateExportKey(key)` for a key another ability holds; a hard delete
/// while classes or NPCs still reference the ability throws `SaveFailed`,
/// as the foreign keys refused it in 0.1.6.
abstract interface class AbilityRepository {
  /// Ordered by display name, ignoring case.
  Future<List<AbilityRecord>> list({
    RecordListMode mode = RecordListMode.active,
  });

  /// Abilities that are not soft-deleted.
  Future<int> countActive();

  /// The row, soft-deleted or not.
  Future<AbilityRecord> get(String id);

  /// The draft of an ability, soft-deleted or not.
  Future<AbilityDraft> load(String id);

  Future<AbilityRecord> create(CreateAbilityInput input);

  /// Writes [draft] over the active ability [id] (stat modifiers as
  /// `JSON.stringify` wrote them) and returns the draft as read back.
  Future<AbilityDraft> save(String id, AbilityDraft draft);

  /// Copies the ability as `<name> (Copy)` with a fresh export key.
  Future<AbilityRecord> duplicate(String id);

  /// Sets `deleted_at` (kept if already set) and bumps `updated_at`.
  Future<void> softDelete(String id);

  /// Clears `deleted_at` and bumps `updated_at`.
  Future<void> restore(String id);

  Future<void> hardDelete(String id);

  /// Active classes and NPCs the ability is assigned to. Empty lists for an
  /// unknown id, as in 0.1.6.
  Future<AbilityUsedBy> usedBy(String id);
}
