/// The export context, ported from 0.1.6 `src/main/export/context-assembler.ts`
/// (design §11.9 step 2): `project`, `meta` and the six domain arrays, with
/// the same SELECTs, orderings, nested arrays, custom field maps and stat
/// growth formulas resolved per level.
///
/// The context is a plain JSON-shaped map, so it compares directly with the
/// 0.1.6 fixtures and feeds the presets and the template renderer. Values
/// keep their SQLite types: REAL columns arrive as doubles, which the
/// export encoders print as JavaScript would.
library;

import 'dart:convert';

import 'package:sqlite3/sqlite3.dart' show Row;

import '../db/project_database.dart';
import '../formula/formula_engine.dart' show evaluateFormula;
import 'export_scope.dart';

typedef _Json = Map<String, Object?>;
typedef _Assembler = List<_Json> Function(ReadScope tx, List<String>? ids);

const Map<ExportDomain, _Assembler> _assemblers = {
  ExportDomain.classes: _classes,
  ExportDomain.abilities: _abilities,
  ExportDomain.items: _items,
  ExportDomain.recipes: _recipes,
  ExportDomain.npcs: _npcs,
  ExportDomain.lootTables: _lootTables,
};

/// Builds the export context for [scope]. A pure read: run it inside
/// `ProjectDatabase.read`, which gives every query one consistent state.
///
/// In domain and selection scope the other five domain arrays are empty, as
/// in 0.1.6, which has no dependency auto-include; an empty selection
/// leaves all six empty. Soft-deleted records are never included.
Map<String, Object?> assembleExportContext(ReadScope tx, ExportScope scope) {
  final ctx = <String, Object?>{
    'project': _projectMeta(tx),
    'meta': _metaLayers(tx),
    for (final d in ExportDomain.values) d.contextKey: <_Json>[],
  };
  switch (scope) {
    case FullProjectScope():
      for (final MapEntry(key: d, value: assemble) in _assemblers.entries) {
        ctx[d.contextKey] = assemble(tx, null);
      }
    case DomainScope(:final domain):
      ctx[domain.contextKey] = _assemblers[domain]!(tx, null);
    case SelectionScope(:final domain, :final recordIds):
      if (recordIds.isNotEmpty) {
        ctx[domain.contextKey] = _assemblers[domain]!(tx, recordIds);
      }
  }
  return ctx;
}

_Json _row(Row r) => {...r};

List<_Json> _all(ReadScope tx, String sql, [List<Object?> params = const []]) =>
    [for (final r in tx.select(sql, params)) _row(r)];

_Json _projectMeta(ReadScope tx) {
  final rows = tx.select(
    'SELECT project_name, game_title, schema_version, max_level '
    'FROM project_info LIMIT 1',
  );
  if (rows.isEmpty) {
    return {'name': '', 'game_title': '', 'schema_version': 0, 'max_level': 20};
  }
  final r = rows.first;
  return {
    'name': r['project_name'],
    'game_title': r['game_title'],
    'schema_version': r['schema_version'],
    'max_level': r['max_level'],
  };
}

Map<String, Object?> _metaLayers(ReadScope tx) => {
  'stats': _all(
    tx,
    'SELECT id, display_name, export_key, sort_order FROM stats '
    'ORDER BY sort_order',
  ),
  'rarities': _all(
    tx,
    'SELECT id, display_name, export_key, color_hex, sort_order FROM rarities '
    'ORDER BY sort_order',
  ),
  'item_categories': _all(
    tx,
    'SELECT id, display_name, export_key, description, sort_order '
    'FROM item_categories ORDER BY sort_order',
  ),
  'npc_types': _all(
    tx,
    'SELECT id, display_name, export_key, description, sort_order '
    'FROM npc_types ORDER BY sort_order',
  ),
  'crafting_stations': _all(
    tx,
    'SELECT id, display_name, export_key, description, sort_order '
    'FROM crafting_stations ORDER BY sort_order',
  ),
  'crafting_specializations': _all(
    tx,
    'SELECT id, display_name, export_key, description, sort_order '
    'FROM crafting_specializations ORDER BY sort_order',
  ),
  'derived_stats': _all(
    tx,
    'SELECT id, display_name, export_key, formula, output_type, '
    'rounding_mode, sort_order FROM derived_stat_definitions '
    'ORDER BY sort_order',
  ),
};

/// 0.1.6 `whereActive`: active rows, optionally limited to [ids].
(String, List<Object?>) _whereActive(List<String>? ids) {
  if (ids != null && ids.isNotEmpty) {
    final placeholders = List.filled(ids.length, '?').join(', ');
    return ('WHERE deleted_at IS NULL AND id IN ($placeholders)', ids);
  }
  return ('WHERE deleted_at IS NULL', const []);
}

/// 0.1.6 `getCustomFields`: field name to stored text, in row order; a
/// repeated field name keeps its first position and its last value, as a
/// JavaScript object assignment does.
Map<String, Object?> _customFields(
  ReadScope tx,
  String domain,
  String recordId,
) => {
  for (final r in tx.select(
    'SELECT cfd.field_name, cfv.value '
    'FROM custom_field_values cfv '
    'JOIN custom_field_definitions cfd ON cfd.id = cfv.field_definition_id '
    'WHERE cfv.domain = ? AND cfv.record_id = ?',
    [domain, recordId],
  ))
    r['field_name'] as String: r['value'],
};

List<_Json> _classes(ReadScope tx, List<String>? ids) {
  final (clause, params) = _whereActive(ids);
  final rows = tx.select(
    'SELECT id, display_name, export_key, description, resource_multiplier '
    'FROM classes $clause ORDER BY display_name COLLATE NOCASE',
    params,
  );
  // 0.1.6 read this unguarded; a project without a project_info row fails
  // here (StateError) as 0.1.6 failed on destructuring undefined.
  final maxLevel =
      tx.select('SELECT max_level FROM project_info LIMIT 1').first['max_level']
          as int;

  return [for (final row in rows) _class(tx, row, maxLevel)];
}

_Json _class(ReadScope tx, Row row, int maxLevel) {
  final id = row['id'] as String;
  final manual = _all(
    tx,
    'SELECT stat_id, level, value FROM class_stat_growth '
    'WHERE class_id = ? ORDER BY stat_id, level',
    [id],
  );
  final formulas = _all(
    tx,
    'SELECT stat_id, formula FROM class_stat_growth_formulas '
    'WHERE class_id = ?',
    [id],
  );
  final formulaStatIds = {for (final f in formulas) f['stat_id']};
  final statGrowth = [
    for (final sg in manual)
      if (!formulaStatIds.contains(sg['stat_id'])) sg,
  ];
  for (final f in formulas) {
    for (var level = 1; level <= maxLevel; level++) {
      final result = evaluateFormula(f['formula'] as String, {
        'level': level.toDouble(),
        'max_level': maxLevel.toDouble(),
      });
      statGrowth.add({
        'stat_id': f['stat_id'],
        'level': level,
        'value': result.value ?? 0,
      });
    }
  }
  final abilities = _all(
    tx,
    'SELECT ability_id, sort_order FROM class_ability_assignments '
    'WHERE class_id = ? ORDER BY sort_order',
    [id],
  );
  final overrides = _all(
    tx,
    'SELECT derived_stat_id, formula FROM class_derived_stat_overrides '
    'WHERE class_id = ?',
    [id],
  );
  final metadata = <String, Object?>{
    for (final m in tx.select(
      'SELECT field_key, value FROM class_metadata_fields '
      'WHERE class_id = ?',
      [id],
    ))
      m['field_key'] as String: m['value'],
  };
  return <String, Object?>{
    'id': id,
    'display_name': row['display_name'],
    'export_key': row['export_key'],
    'description': row['description'],
    'resource_multiplier': row['resource_multiplier'],
    'stat_growth': statGrowth,
    'abilities': abilities,
    'derived_stat_overrides': overrides,
    'metadata': metadata,
  };
}

List<_Json> _abilities(ReadScope tx, List<String>? ids) {
  final (clause, params) = _whereActive(ids);
  return [
    for (final row in tx.select(
      'SELECT id, display_name, export_key, description, '
      'ability_type, resource_type, resource_cost, cooldown, '
      'stat_modifiers_json '
      'FROM abilities $clause ORDER BY display_name COLLATE NOCASE',
      params,
    ))
      {
        'id': row['id'],
        'display_name': row['display_name'],
        'export_key': row['export_key'],
        'description': row['description'],
        'ability_type': row['ability_type'],
        'resource_type': row['resource_type'],
        'resource_cost': row['resource_cost'],
        'cooldown': row['cooldown'],
        'stat_modifiers': jsonDecode(row['stat_modifiers_json'] as String),
      },
  ];
}

List<_Json> _items(ReadScope tx, List<String>? ids) {
  final (clause, params) = _whereActive(ids);
  return [
    for (final row in tx.select(
      'SELECT id, display_name, export_key, description, item_category_id, '
      'rarity_id FROM items $clause ORDER BY display_name COLLATE NOCASE',
      params,
    ))
      {
        'id': row['id'],
        'display_name': row['display_name'],
        'export_key': row['export_key'],
        'description': row['description'],
        'item_category_id': row['item_category_id'],
        'rarity_id': row['rarity_id'],
        'custom_fields': _customFields(tx, 'items', row['id'] as String),
      },
  ];
}

List<_Json> _recipes(ReadScope tx, List<String>? ids) {
  final (clause, params) = _whereActive(ids);
  return [
    for (final row in tx.select(
      'SELECT id, display_name, export_key, description, '
      'output_item_id, output_quantity, crafting_station_id, '
      'crafting_specialization_id '
      'FROM recipes $clause ORDER BY display_name COLLATE NOCASE',
      params,
    ))
      {
        'id': row['id'],
        'display_name': row['display_name'],
        'export_key': row['export_key'],
        'description': row['description'],
        'output_item_id': row['output_item_id'],
        'output_quantity': row['output_quantity'],
        'crafting_station_id': row['crafting_station_id'],
        'crafting_specialization_id': row['crafting_specialization_id'],
        'ingredients': _all(
          tx,
          'SELECT item_id, quantity, sort_order FROM recipe_ingredients '
          'WHERE recipe_id = ? ORDER BY sort_order',
          [row['id']],
        ),
      },
  ];
}

List<_Json> _npcs(ReadScope tx, List<String>? ids) {
  final (clause, params) = _whereActive(ids);
  return [
    for (final row in tx.select(
      'SELECT id, display_name, export_key, description, '
      'npc_type_id, loot_table_id, combat_stats_json '
      'FROM npcs $clause ORDER BY display_name COLLATE NOCASE',
      params,
    ))
      {
        'id': row['id'],
        'display_name': row['display_name'],
        'export_key': row['export_key'],
        'description': row['description'],
        'npc_type_id': row['npc_type_id'],
        'loot_table_id': row['loot_table_id'],
        'combat_stats': jsonDecode(row['combat_stats_json'] as String),
        'class_assignments': _all(
          tx,
          'SELECT class_id, level, sort_order FROM npc_class_assignments '
          'WHERE npc_id = ? ORDER BY sort_order',
          [row['id']],
        ),
        'ability_assignments': _all(
          tx,
          'SELECT ability_id, sort_order FROM npc_ability_assignments '
          'WHERE npc_id = ? ORDER BY sort_order',
          [row['id']],
        ),
        'custom_fields': _customFields(tx, 'npcs', row['id'] as String),
      },
  ];
}

List<_Json> _lootTables(ReadScope tx, List<String>? ids) {
  final (clause, params) = _whereActive(ids);
  return [
    for (final row in tx.select(
      'SELECT id, display_name, export_key, description '
      'FROM loot_tables $clause ORDER BY display_name COLLATE NOCASE',
      params,
    ))
      {
        'id': row['id'],
        'display_name': row['display_name'],
        'export_key': row['export_key'],
        'description': row['description'],
        'entries': _all(
          tx,
          'SELECT item_id, weight, quantity_min, quantity_max, sort_order '
          'FROM loot_table_entries WHERE loot_table_id = ? ORDER BY sort_order',
          [row['id']],
        ),
      },
  ];
}
