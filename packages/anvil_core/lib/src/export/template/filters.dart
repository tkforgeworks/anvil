/// The 15 template filters: 13 ported from Nunjucks 3.2.4 `filters.js` plus
/// Anvil's `json` and `export_key` with Electron 0.1.6 semantics. The names
/// must match `supportedFilters` in parser.dart.
library;

import '../js_compat.dart';

/// A filter failed; the evaluator adds the filter's line and column.
final class FilterError implements Exception {
  FilterError(this.message);
  final String message;
}

typedef FilterFn = Object? Function(
  ExportKeyIndex keys,
  Object? value,
  List<Object?> args,
);

/// The domains `export_key` searches, in Electron's order. Meta layers
/// (rarities, item categories, stations, ...) are deliberately absent: the
/// 0.1.6 filter never resolved them, so `{{ item.rarity_id | export_key }}`
/// prints `rarity-common`, not `common` (the presets do resolve them).
const exportKeyDomains = [
  'classes',
  'abilities',
  'items',
  'recipes',
  'npcs',
  'loot_tables',
];

/// `export_key`'s lookup, built once per render instead of 0.1.6's linear
/// scan per call. Same result: the `export_key` of the first record, in
/// [exportKeyDomains] order, whose `id` is strictly equal (`===`) to the
/// argument; otherwise the argument unchanged.
final class ExportKeyIndex {
  ExportKeyIndex(Map<String, Object?> context) {
    for (final domain in exportKeyDomains) {
      final records = context[domain];
      if (records is! List) continue;
      for (final record in records) {
        if (record is! Map) continue;
        final exportKey = record.containsKey('export_key')
            ? record['export_key']
            : jsUndefined;
        final id = record.containsKey('id') ? record['id'] : jsUndefined;
        final key = _key(id);
        if (key == _unindexed) {
          _byIdentity.add((id, exportKey));
        } else if (key != _never) {
          _byId.putIfAbsent(key, () => exportKey);
        }
      }
    }
  }

  // Distinct sentinels (`final`, not `const`, which would canonicalise them).
  static final Object _unindexed = Object();
  static final Object _never = Object();

  final Map<Object?, Object?> _byId = {};

  /// Records whose id is a list or map: `===` is identity for those.
  final List<(Object?, Object?)> _byIdentity = [];

  /// The map key that makes Dart `==` agree with JS `===` for primitives.
  static Object? _key(Object? id) {
    if (id is num) {
      if (id.isNaN) return _never; // NaN === NaN is false
      return id == 0 ? 0.0 : id.toDouble(); // 1 === 1.0, 0 === -0
    }
    if (id == null || id is String || id is bool || id is JsUndefined) {
      return id;
    }
    return _unindexed;
  }

  Object? resolve(Object? id) {
    final key = _key(id);
    if (key == _never) return id;
    if (key == _unindexed) {
      for (final (recordId, exportKey) in _byIdentity) {
        if (identical(recordId, id)) return exportKey;
      }
      return id;
    }
    return _byId.containsKey(key) ? _byId[key] : id;
  }
}

/// `json`: `JSON.stringify(value, null, indent ?? 2)`. `json(0)` is compact.
/// Undefined where JS returns `undefined`, so the output check then throws,
/// as Nunjucks does.
Object? _json(Object? value, Object? indent) =>
    jsonStringify(
      value,
      indent: (indent == null || indent is JsUndefined) ? 2 : indent,
    ) ??
    jsUndefined;

Object? _arg(List<Object?> args, int i) =>
    i < args.length ? args[i] : jsUndefined;

bool _nullish(Object? v) => v == null || v is JsUndefined;

/// Nunjucks `normalize`: null, undefined and false become [fallback].
Object? _normalize(Object? v, Object? fallback) =>
    (_nullish(v) || v == false) ? fallback : v;

String _string(String filter, Object? v) {
  if (v is String) return v;
  throw FilterError("the '$filter' filter needs a string, got ${jsString(v)}");
}

/// `obj[key]` with JS semantics for the shapes templates see.
Object? memberLookup(Object? obj, Object? key) {
  if (_nullish(obj)) return jsUndefined;
  if (obj is Map) {
    final k = key is String ? key : jsString(key);
    return obj.containsKey(k) ? obj[k] : jsUndefined;
  }
  if (obj is List || obj is String) {
    final length = obj is List ? obj.length : (obj as String).length;
    if (key == 'length') return length;
    final i = key is num ? key : (key is String ? int.tryParse(key) : null);
    if (i == null || i != i.truncate() || i < 0 || i >= length) {
      return jsUndefined;
    }
    return obj is List ? obj[i.toInt()] : (obj as String)[i.toInt()];
  }
  return jsUndefined;
}

final Map<String, FilterFn> filters = {
  'json': (keys, v, a) => _json(v, _arg(a, 0)),
  'export_key': (keys, v, a) => keys.resolve(v),
  'dump': (keys, v, a) => jsonStringify(v, indent: _arg(a, 0)) ?? jsUndefined,
  'length': (keys, v, a) {
    final value = _normalize(v, '');
    if (value is Map) return value.length;
    if (value is List) return value.length;
    if (value is String) return value.length;
    return jsUndefined;
  },
  'upper': (keys, v, a) => _string('upper', _normalize(v, '')).toUpperCase(),
  'lower': (keys, v, a) => _string('lower', _normalize(v, '')).toLowerCase(),
  'capitalize': (keys, v, a) =>
      _capitalize(_string('capitalize', _normalize(v, ''))),
  'title': (keys, v, a) =>
      _string('title', _normalize(v, '')).split(' ').map(_capitalize).join(' '),
  'trim': (keys, v, a) =>
      _string('trim', v).replaceAll(RegExp(r'^\s*|\s*$'), ''),
  'default': _default,
  'd': _default,
  'replace': (keys, v, a) => _replace(v, _arg(a, 0), _arg(a, 1), _arg(a, 2)),
  'join': (keys, v, a) {
    if (v is! List) {
      throw FilterError("'join' needs a list");
    }
    final del = jsTruthy(_arg(a, 0)) ? jsString(_arg(a, 0)) : '';
    final attr = _arg(a, 1);
    final items = jsTruthy(attr) ? v.map((e) => memberLookup(e, attr)) : v;
    return items.map((e) => _nullish(e) ? '' : jsString(e)).join(del);
  },
  'first': (keys, v, a) {
    if (_nullish(v)) {
      throw FilterError("'first' of undefined");
    }
    return memberLookup(v, 0);
  },
  'last': (keys, v, a) {
    if (_nullish(v)) {
      throw FilterError("'last' of undefined");
    }
    if (v is List && v.isNotEmpty) return v.last;
    if (v is String && v.isNotEmpty) return v[v.length - 1];
    return jsUndefined;
  },
  'reverse': (keys, v, a) {
    if (v is String) return v.split('').reversed.join();
    if (v is List) return v.reversed.toList();
    return <Object?>[];
  },
};

String _capitalize(String s) {
  final lower = s.toLowerCase();
  return lower.isEmpty ? lower : lower[0].toUpperCase() + lower.substring(1);
}

Object? _default(ExportKeyIndex keys, Object? v, List<Object?> a) {
  final fallback = _arg(a, 0);
  if (jsTruthy(_arg(a, 1))) return jsTruthy(v) ? v : fallback;
  return v is JsUndefined ? fallback : v;
}

Object? _replace(Object? str, Object? from, Object? replacement, Object? max) {
  final maxCount = max is num ? max : -1;
  final String old;
  if (from is num) {
    old = jsString(from);
  } else if (from is String) {
    old = from;
  } else {
    return str;
  }
  if (str is num) str = jsString(str);
  if (str is! String) return str;
  final repl = jsString(replacement);
  if (old.isEmpty) return repl + str.split('').join(repl) + repl;
  var next = str.indexOf(old);
  if (maxCount == 0 || next == -1) return str;
  final out = StringBuffer();
  var pos = 0, count = 0;
  while (next > -1 && (maxCount == -1 || count < maxCount)) {
    out
      ..write(str.substring(pos, next))
      ..write(repl);
    pos = next + old.length;
    count++;
    next = str.indexOf(old, pos);
  }
  if (pos < str.length) out.write(str.substring(pos));
  return out.toString();
}
