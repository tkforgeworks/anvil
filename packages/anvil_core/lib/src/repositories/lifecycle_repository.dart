import '../domain/lifecycle_types.dart';
import '../project/project_metadata.dart';

/// Cross-domain record lifecycle: replaces 0.1.6's `lifecycle:*` channels
/// (`lifecycle.handlers.ts`, `impact.ts`) and `project:get-weekly-deltas`.
///
/// The bulk operations and [emptyTrash] are each one save transaction with
/// one save history row, written only when at least one row changes. Ids
/// that do not exist, or are not in the state an operation needs, are
/// skipped silently, as 0.1.6 did; each returns the number of records it
/// changed. A hard delete a foreign key refuses (a class an NPC still
/// references, an item in a recipe) rolls the whole operation back and
/// throws `SaveFailed`.
abstract interface class LifecycleRepository {
  /// Soft-deleted records per domain (0.1.6 returned only the total).
  Future<RecordCounts> countDeleted();

  /// Soft-deletes the active records among [ids]; recorded as
  /// `<n> <domains> deleted`, or `<Domain> deleted` for one record.
  Future<int> bulkSoftDelete(LifecycleDomain domain, List<String> ids);

  /// Restores the soft-deleted records among [ids]; recorded as
  /// `<n> <domains> restored`, or `<Domain> restored` for one record.
  Future<int> bulkRestore(LifecycleDomain domain, List<String> ids);

  /// Deletes the records among [ids], soft-deleted or not, with their
  /// custom field values; owned junction rows cascade. Recorded as
  /// `<n> <domains> permanently deleted`, or as
  /// `<Domain> permanently deleted` for one record.
  Future<int> bulkHardDelete(LifecycleDomain domain, List<String> ids);

  /// Deletes every soft-deleted record of the six domains, in 0.1.6's
  /// table order, with their custom field values; recorded as 0.1.6 did,
  /// `Changes across 6 domains`.
  Future<int> emptyTrash();

  /// What deleting [ids] from [domain] would affect: per reverse reference,
  /// the number of distinct active records that point at any of them.
  /// A pure read.
  Future<DeleteImpact> computeDeleteImpact(
    LifecycleDomain domain,
    List<String> ids,
  );

  /// Per domain: records created in the last 7 days that are still active,
  /// minus records soft-deleted in the last 7 days (0.1.6
  /// `getWeeklyDeltas`). Can be negative.
  Future<RecordCounts> weeklyDeltas();
}
