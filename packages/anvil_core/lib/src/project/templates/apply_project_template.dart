import 'package:meta/meta.dart';
import 'package:sqlite3/sqlite3.dart';

import 'project_template_content.dart';

/// The seven meta tables a template replaces, children first so nothing a
/// later delete needs is gone already (a new project has no records, so no
/// foreign key points at these rows yet).
const _metaTables = [
  'derived_stat_definitions',
  'stats',
  'rarities',
  'item_categories',
  'npc_types',
  'crafting_stations',
  'crafting_specializations',
];

const _insertNamed =
    'INSERT INTO {table} (id, display_name, export_key, description, '
    'sort_order) VALUES (?, ?, ?, ?, ?)';

/// Writes [content] over the meta layer the migrations seeded, as one plain
/// transaction on [db] (no `save_history` row: a template is part of
/// creating the project, not a save). An empty [content] writes nothing.
///
/// Called once, by `ProjectService.create`, after the migrations and before
/// the integrity check. Rolls back and rethrows on any failure, so the
/// caller's cleanup removes the project.
@internal
void applyProjectTemplate(Database db, ProjectTemplateContent content) {
  if (content.isEmpty) return;
  db.execute('BEGIN IMMEDIATE');
  try {
    for (final table in _metaTables) {
      db.execute('DELETE FROM $table');
    }
    void insert(String table, List<List<Object?>> rows) {
      final statement = db.prepare(_insertNamed.replaceFirst('{table}', table));
      try {
        for (final row in rows) {
          statement.execute(row);
        }
      } finally {
        statement.close();
      }
    }

    insert('stats', [
      for (final s in content.stats)
        [s.id, s.displayName, s.exportKey, '', s.sortOrder],
    ]);
    insert('item_categories', [
      for (final c in content.itemCategories)
        [c.id, c.displayName, c.exportKey, c.description, c.sortOrder],
    ]);
    insert('npc_types', [
      for (final t in content.npcTypes)
        [t.id, t.displayName, t.exportKey, t.description, t.sortOrder],
    ]);
    insert('crafting_stations', [
      for (final s in content.craftingStations)
        [s.id, s.displayName, s.exportKey, s.description, s.sortOrder],
    ]);
    insert('crafting_specializations', [
      for (final s in content.craftingSpecializations)
        [s.id, s.displayName, s.exportKey, s.description, s.sortOrder],
    ]);

    final rarity = db.prepare(
      'INSERT INTO rarities (id, display_name, export_key, color_hex, '
      'sort_order) VALUES (?, ?, ?, ?, ?)',
    );
    try {
      for (final r in content.rarities) {
        rarity.execute([
          r.id,
          r.displayName,
          r.exportKey,
          r.colorHex,
          r.sortOrder,
        ]);
      }
    } finally {
      rarity.close();
    }

    final derived = db.prepare(
      'INSERT INTO derived_stat_definitions (id, display_name, export_key, '
      'formula, output_type, rounding_mode, sort_order) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
    );
    try {
      for (final d in content.derivedStats) {
        derived.execute([
          d.id,
          d.displayName,
          d.exportKey,
          d.formula,
          d.outputType.value,
          d.roundingMode.value,
          d.sortOrder,
        ]);
      }
    } finally {
      derived.close();
    }

    final maxLevel = content.maxLevel;
    if (maxLevel != null) {
      db.execute('UPDATE project_info SET max_level = ? WHERE id = 1', [
        maxLevel,
      ]);
    }
    db.execute('COMMIT');
  } catch (_) {
    if (!db.autocommit) db.execute('ROLLBACK');
    rethrow;
  }
}
