/// Port probe of the three built-in presets (Electron renderer.ts lines
/// 53-327): plain Dart over the export context, no template engine. Object
/// key order follows the JS spreads (`{...c, abilities: x}` keeps `abilities`
/// in place; new keys go last), which Dart's LinkedHashMap reproduces.
library;

import 'js_compat.dart';

const _domains = [
  'classes',
  'abilities',
  'items',
  'recipes',
  'npcs',
  'loot_tables',
];

// Note: derived_stats is absent, as in Electron, so flat JSON prints a
// derived stat override's raw id as its "export key".
const _lookupMeta = [
  'stats',
  'rarities',
  'item_categories',
  'npc_types',
  'crafting_stations',
  'crafting_specializations',
];

typedef Json = Map<String, Object?>;

/// Serialisers, injectable so the tests can show what a naive port (Dart's
/// `JsonEncoder` / `toString`) gets wrong. Defaults are the JS-compatible ones.
typedef JsonEncodeFn = String Function(Object? value);
typedef CellStringFn = String Function(Object? value);

String jsJson2(Object? value) => jsJsonStringify(value, 2)!;

List<Json> _records(Json ctx, String domain) =>
    (ctx[domain] as List).cast<Json>();

Map<String, Object?> _exportKeyLookup(Json ctx) {
  final map = <String, Object?>{};
  for (final d in _domains) {
    for (final r in _records(ctx, d)) {
      map[r['id'] as String] = r['export_key'];
    }
  }
  final meta = ctx['meta'] as Json;
  for (final d in _lookupMeta) {
    for (final r in (meta[d] as List).cast<Json>()) {
      map[r['id'] as String] = r['export_key'];
    }
  }
  return map;
}

/// `resolveKey`: falsy id -> null; else lookup ?? id.
Object? _resolve(Map<String, Object?> lookup, Object? id) {
  if (!jsTruthy(id)) return null;
  return lookup[id] ?? id;
}

Json _without(Json r, Set<String> keys) => {
  for (final e in r.entries)
    if (!keys.contains(e.key)) e.key: e.value,
};

String _scoped(Map<String, List<Json>> transformed, JsonEncodeFn encode) =>
    encode({
      for (final e in transformed.entries)
        if (e.value.isNotEmpty) e.key: e.value,
    });

String renderNestedJson(
  Json ctx, {
  bool fullScope = true,
  JsonEncodeFn encode = jsJson2,
}) {
  final meta = ctx['meta'] as Json;
  final metaLookup = <String, Json>{
    for (final e in meta.entries)
      for (final r in (e.value as List).cast<Json>()) '${e.key}:${r['id']}': r,
  };
  final records = <String, Json>{
    for (final d in _domains)
      for (final r in _records(ctx, d)) r['id'] as String: r,
  };
  Object? ref(Object? id) => jsTruthy(id) ? records[id] : null;
  Object? metaRef(String d, Object? id) =>
      jsTruthy(id) ? metaLookup['$d:$id'] : null;
  List<Json> mapList(Object? list, Json Function(Json) f) =>
      (list as List).cast<Json>().map(f).toList();

  final transformed = <String, List<Json>>{
    'classes': [
      for (final c in _records(ctx, 'classes'))
        {
          ...c,
          'abilities': mapList(
            c['abilities'],
            (a) => {...a, 'ability': ref(a['ability_id'])},
          ),
        },
    ],
    'abilities': _records(ctx, 'abilities'),
    'items': [
      for (final i in _records(ctx, 'items'))
        {
          ...i,
          'item_category': metaRef('item_categories', i['item_category_id']),
          'rarity': metaRef('rarities', i['rarity_id']),
        },
    ],
    'recipes': [
      for (final r in _records(ctx, 'recipes'))
        {
          ...r,
          'output_item': ref(r['output_item_id']),
          'crafting_station': metaRef(
            'crafting_stations',
            r['crafting_station_id'],
          ),
          'crafting_specialization': metaRef(
            'crafting_specializations',
            r['crafting_specialization_id'],
          ),
          'ingredients': mapList(
            r['ingredients'],
            (g) => {...g, 'item': ref(g['item_id'])},
          ),
        },
    ],
    'npcs': [
      for (final n in _records(ctx, 'npcs'))
        {
          ...n,
          'npc_type': metaRef('npc_types', n['npc_type_id']),
          'loot_table': ref(n['loot_table_id']),
          'class_assignments': mapList(
            n['class_assignments'],
            (a) => {...a, 'class': ref(a['class_id'])},
          ),
          'ability_assignments': mapList(
            n['ability_assignments'],
            (a) => {...a, 'ability': ref(a['ability_id'])},
          ),
        },
    ],
    'loot_tables': [
      for (final t in _records(ctx, 'loot_tables'))
        {
          ...t,
          'entries': mapList(
            t['entries'],
            (e) => {...e, 'item': ref(e['item_id'])},
          ),
        },
    ],
  };
  if (!fullScope) return _scoped(transformed, encode);
  return encode({'project': ctx['project'], 'meta': meta, ...transformed});
}

String renderFlatJson(
  Json ctx, {
  bool fullScope = true,
  JsonEncodeFn encode = jsJson2,
}) {
  final lookup = _exportKeyLookup(ctx);
  Object? key(Object? id) => _resolve(lookup, id);
  List<Json> each(Object? list, Json Function(Json) f) =>
      (list as List).cast<Json>().map(f).toList();

  final transformed = <String, List<Json>>{
    'classes': [
      for (final c in _records(ctx, 'classes'))
        {
          ...c,
          'abilities': each(
            c['abilities'],
            (a) => {
              'ability_export_key': key(a['ability_id']),
              'sort_order': a['sort_order'],
            },
          ),
          'derived_stat_overrides': each(
            c['derived_stat_overrides'],
            (o) => {
              'derived_stat_export_key': key(o['derived_stat_id']),
              'formula': o['formula'],
            },
          ),
        },
    ],
    'abilities': _records(ctx, 'abilities'),
    'items': [
      for (final i in _records(ctx, 'items'))
        {
          ..._without(i, {'item_category_id', 'rarity_id'}),
          'item_category_export_key': key(i['item_category_id']),
          'rarity_export_key': key(i['rarity_id']),
        },
    ],
    'recipes': [
      for (final r in _records(ctx, 'recipes'))
        {
          ..._without(r, {
            'output_item_id',
            'crafting_station_id',
            'crafting_specialization_id',
          }),
          'output_item_export_key': key(r['output_item_id']),
          'crafting_station_export_key': key(r['crafting_station_id']),
          'crafting_specialization_export_key': key(
            r['crafting_specialization_id'],
          ),
          'ingredients': each(
            r['ingredients'],
            (g) => {
              'item_export_key': key(g['item_id']),
              'quantity': g['quantity'],
            },
          ),
        },
    ],
    'npcs': [
      for (final n in _records(ctx, 'npcs'))
        {
          ..._without(n, {'npc_type_id', 'loot_table_id'}),
          'npc_type_export_key': key(n['npc_type_id']),
          'loot_table_export_key': key(n['loot_table_id']),
          'class_assignments': each(
            n['class_assignments'],
            (a) => {
              'class_export_key': key(a['class_id']),
              'level': a['level'],
            },
          ),
          'ability_assignments': each(
            n['ability_assignments'],
            (a) => {'ability_export_key': key(a['ability_id'])},
          ),
        },
    ],
    'loot_tables': [
      for (final t in _records(ctx, 'loot_tables'))
        {
          ...t,
          'entries': each(
            t['entries'],
            (e) => {
              'item_export_key': key(e['item_id']),
              'weight': e['weight'],
              'quantity_min': e['quantity_min'],
              'quantity_max': e['quantity_max'],
            },
          ),
        },
    ],
  };
  if (!fullScope) return _scoped(transformed, encode);
  return encode({'project': ctx['project'], ...transformed});
}

final class CsvFile {
  CsvFile(this.filename, this.content);
  final String filename;
  final String content;
}

/// `renderCsv`: one file per non-empty domain plus the preview summary.
({String summary, List<CsvFile> files}) renderCsv(
  Json ctx, {
  CellStringFn cell = jsToString,
}) {
  final lookup = _exportKeyLookup(ctx);
  Object? key(Object? id) => _resolve(lookup, id);
  final files = <CsvFile>[];
  void add(String domain, Json Function(Json) row) {
    final records = _records(ctx, domain);
    if (records.isNotEmpty) {
      files.add(
        CsvFile('$domain.csv', toCsv(records.map(row).toList(), cell: cell)),
      );
    }
  }

  add(
    'classes',
    (c) => {
      'export_key': c['export_key'],
      'display_name': c['display_name'],
      'description': c['description'],
      'resource_multiplier': c['resource_multiplier'],
    },
  );
  add(
    'abilities',
    (a) => {
      'export_key': a['export_key'],
      'display_name': a['display_name'],
      'description': a['description'],
      'ability_type': a['ability_type'],
      'resource_type': a['resource_type'],
      'resource_cost': a['resource_cost'],
      'cooldown': a['cooldown'],
    },
  );
  add(
    'items',
    (i) => {
      'export_key': i['export_key'],
      'display_name': i['display_name'],
      'description': i['description'],
      'item_category': key(i['item_category_id']),
      'rarity': key(i['rarity_id']),
    },
  );
  add(
    'recipes',
    (r) => {
      'export_key': r['export_key'],
      'display_name': r['display_name'],
      'description': r['description'],
      'output_item': key(r['output_item_id']),
      'output_quantity': r['output_quantity'],
      'crafting_station': key(r['crafting_station_id']),
      'crafting_specialization': key(r['crafting_specialization_id']),
    },
  );
  add(
    'npcs',
    (n) => {
      'export_key': n['export_key'],
      'display_name': n['display_name'],
      'description': n['description'],
      'npc_type': key(n['npc_type_id']),
      'loot_table': key(n['loot_table_id']),
    },
  );
  add(
    'loot_tables',
    (t) => {
      'export_key': t['export_key'],
      'display_name': t['display_name'],
      'description': t['description'],
    },
  );
  final summary = files
      .map((f) => '--- ${f.filename} ---\n${f.content}')
      .join('\n\n');
  return (summary: summary, files: files);
}

/// `toCsv`: header from the first row's keys, LF line ends, no final newline.
String toCsv(List<Json> rows, {CellStringFn cell = jsToString}) {
  if (rows.isEmpty) return '';
  final headers = rows.first.keys.toList();
  return [
    headers.join(','),
    for (final row in rows)
      headers.map((h) => csvEscape(row[h], cell: cell)).join(','),
  ].join('\n');
}

/// `csvEscape`: `String(value)`, quoted when it holds `,` `"` or `\n`
/// (a lone `\r` is not quoted, as in Electron).
String csvEscape(Object? value, {CellStringFn cell = jsToString}) {
  if (value == null || value is JsUndefined) return '';
  final s = cell(value);
  if (s.contains(',') || s.contains('"') || s.contains('\n')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}
