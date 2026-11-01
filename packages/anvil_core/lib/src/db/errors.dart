/// A migration (or the runner's own bookkeeping around it) failed. The
/// failing migration's transaction was rolled back; earlier migrations stay
/// applied, as in Electron.
final class MigrationFailed implements Exception {
  const MigrationFailed(this.filename, this.cause);

  /// The `schema_migrations` filename of the migration that failed, for
  /// example `005_custom_templates`. Two runner steps outside any migration
  /// report a pseudo-filename instead: `schema_migrations` (creating or
  /// reading the tracking table) and `project_info.schema_version` (the
  /// version update after the migrations).
  final String filename;

  /// The underlying error, usually a `SqliteException`.
  final Object cause;

  @override
  String toString() => 'MigrationFailed: $filename: $cause';
}

/// `PRAGMA integrity_check` did not return a single `ok`, or could not run.
final class IntegrityCheckFailed implements Exception {
  const IntegrityCheckFailed(this.message);

  /// What SQLite reported: the integrity_check rows joined by newlines, or
  /// the error that stopped the check.
  final String message;

  @override
  String toString() => 'IntegrityCheckFailed: $message';
}

/// No active record with [id] in [domain] (for example `items`).
final class RecordNotFound implements Exception {
  const RecordNotFound(this.domain, this.id);

  final String domain;
  final String id;

  @override
  String toString() => 'RecordNotFound: $domain $id';
}

/// A save was refused because the draft breaks save-blocking rules.
final class SaveBlocked implements Exception {
  const SaveBlocked(this.blockers);

  final List<String> blockers;

  @override
  String toString() => 'SaveBlocked: ${blockers.join('; ')}';
}

/// The `UNIQUE` constraint on `export_key` refused a write. [exportKey] is
/// null when the key is not known (SQLite names the column, not the value).
final class DuplicateExportKey implements Exception {
  const DuplicateExportKey(this.exportKey);

  final String? exportKey;

  @override
  String toString() => exportKey == null
      ? 'DuplicateExportKey'
      : 'DuplicateExportKey: $exportKey';
}

/// A meta row cannot be deleted because [counts] records still use it.
final class MetaInUse implements Exception {
  const MetaInUse(this.kind, this.counts);

  final String kind;
  final Map<String, int> counts;

  @override
  String toString() => 'MetaInUse: $kind $counts';
}

/// A save failed in SQLite for a reason with no more specific type.
final class SaveFailed implements Exception {
  const SaveFailed(this.message, this.cause);

  final String message;
  final Object cause;

  @override
  String toString() => 'SaveFailed: $message';
}
