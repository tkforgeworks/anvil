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
