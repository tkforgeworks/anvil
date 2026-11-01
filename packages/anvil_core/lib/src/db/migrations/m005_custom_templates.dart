// Ported verbatim from src/main/db/migrations/005_custom_templates.ts (Electron 0.1.6).
// The SQL text is the Electron template literal byte for byte, so the text
// SQLite stores in sqlite_master matches files created by 0.1.x.
import 'package:sqlite3/sqlite3.dart';

import 'migration.dart';

/// `005_custom_templates`: the `custom_templates` table. Electron creates it without
/// `IF NOT EXISTS`, and so does this port.
const m005CustomTemplates = Migration('005_custom_templates', _up);

void _up(Database db) {
  db.execute('''\n    CREATE TABLE custom_templates (
      id          TEXT PRIMARY KEY,
      name        TEXT NOT NULL,
      description TEXT NOT NULL DEFAULT '',
      template_source TEXT NOT NULL DEFAULT '',
      format      TEXT NOT NULL DEFAULT 'text',
      created_at  TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
    )
  ''');
}
