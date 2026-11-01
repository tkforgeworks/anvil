import 'package:sqlite3/sqlite3.dart';

/// One schema migration, ported from `src/main/db/migrations/`.
///
/// [filename] is the Electron migration filename without `.ts`; it is the key
/// recorded in `schema_migrations`, so it must never change.
final class Migration {
  const Migration(this.filename, this.up);

  final String filename;

  /// Applies the migration. The runner calls it inside a transaction.
  final void Function(Database db) up;
}
