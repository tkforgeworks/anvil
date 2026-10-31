/// The two Anvil-specific template filters, with Electron 0.1.6 semantics.
library;

import 'js_compat.dart';

/// The domains `export_key` searches, in Electron's order. Meta layers
/// (rarities, item categories, stations, ...) are deliberately absent: the
/// Electron filter never resolved them, so `{{ item.rarity_id | export_key }}`
/// prints `rarity-common`, not `common` (the presets do resolve them).
const exportKeyDomains = [
  'classes',
  'abilities',
  'items',
  'recipes',
  'npcs',
  'loot_tables',
];

/// `export_key`: the `export_key` of the first record (in [exportKeyDomains]
/// order) whose `id` is strictly equal to [id]; otherwise [id] unchanged.
Object? anvilExportKey(Map<String, Object?> context, Object? id) {
  for (final domain in exportKeyDomains) {
    final records = context[domain];
    if (records is! List) continue;
    for (final record in records) {
      if (record is Map && jsStrictEquals(record['id'], id)) {
        return record.containsKey('export_key')
            ? record['export_key']
            : jsUndefined;
      }
    }
  }
  return id;
}

/// `json`: `JSON.stringify(value, null, indent ?? 2)`. `json(0)` is compact.
/// Returns `null` where JS returns `undefined` (the caller's output check
/// then throws, as Nunjucks does).
String? anvilJson(Object? value, [Object? indent]) {
  final space = (indent == null || indent is JsUndefined) ? 2 : indent;
  return jsJsonStringify(value, space);
}
