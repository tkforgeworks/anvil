// Ported verbatim from src/main/db/migrations/004_ability_resource_type.ts (Electron 0.1.6).
// The SQL text is the Electron template literal byte for byte, so the text
// SQLite stores in sqlite_master matches files created by 0.1.x.
import 'package:sqlite3/sqlite3.dart';

import 'migration.dart';

/// `004_ability_resource_type`: adds `abilities.resource_type`.
const m004AbilityResourceType = Migration('004_ability_resource_type', _up);

void _up(Database db) {
  db.execute('''\n    ALTER TABLE abilities ADD COLUMN resource_type TEXT NOT NULL DEFAULT '';
  ''');
}
