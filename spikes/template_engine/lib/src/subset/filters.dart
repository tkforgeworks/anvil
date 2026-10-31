/// Filter implementations, ported from Nunjucks 3.2.4 `filters.js` plus
/// Anvil's `json` and `export_key`. Names must match [supportedFilters].
library;

import '../anvil_filters.dart';
import '../js_compat.dart';
import 'errors.dart';

typedef FilterFn = Object? Function(
  Map<String, Object?> root,
  Object? value,
  List<Object?> args,
);

Object? _arg(List<Object?> args, int i) =>
    i < args.length ? args[i] : jsUndefined;

bool _nullish(Object? v) => v == null || v is JsUndefined;

/// Nunjucks `normalize`: null, undefined and false become [fallback].
Object? _normalize(Object? v, Object? fallback) =>
    (_nullish(v) || v == false) ? fallback : v;

String _string(String filter, Object? v) {
  if (v is String) return v;
  throw AnvilTemplateError(
    TemplateErrorKind.render,
    "the '$filter' filter needs a string, got ${jsToString(v)}",
  );
}

/// `obj[key]` with JS semantics for the shapes templates see.
Object? memberLookup(Object? obj, Object? key) {
  if (_nullish(obj)) return jsUndefined;
  if (obj is Map) {
    final k = key is String ? key : jsToString(key);
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
  'json': (root, v, a) => anvilJson(v, _arg(a, 0)) ?? jsUndefined,
  'export_key': (root, v, a) => anvilExportKey(root, v),
  'dump': (root, v, a) => jsJsonStringify(v, _arg(a, 0)) ?? jsUndefined,
  'length': (root, v, a) {
    final value = _normalize(v, '');
    if (value is Map) return value.length;
    if (value is List) return value.length;
    if (value is String) return value.length;
    return jsUndefined;
  },
  'upper': (root, v, a) => _string('upper', _normalize(v, '')).toUpperCase(),
  'lower': (root, v, a) => _string('lower', _normalize(v, '')).toLowerCase(),
  'capitalize': (root, v, a) =>
      _capitalize(_string('capitalize', _normalize(v, ''))),
  'title': (root, v, a) =>
      _string('title', _normalize(v, '')).split(' ').map(_capitalize).join(' '),
  'trim': (root, v, a) =>
      _string('trim', v).replaceAll(RegExp(r'^\s*|\s*$'), ''),
  'default': _default,
  'd': _default,
  'replace': (root, v, a) => _replace(v, _arg(a, 0), _arg(a, 1), _arg(a, 2)),
  'join': (root, v, a) {
    if (v is! List) {
      throw AnvilTemplateError(TemplateErrorKind.render, "'join' needs a list");
    }
    final del = jsTruthy(_arg(a, 0)) ? jsToString(_arg(a, 0)) : '';
    final attr = _arg(a, 1);
    final items = jsTruthy(attr) ? v.map((e) => memberLookup(e, attr)) : v;
    return items.map((e) => _nullish(e) ? '' : jsToString(e)).join(del);
  },
  'first': (root, v, a) {
    if (_nullish(v)) {
      throw AnvilTemplateError(
        TemplateErrorKind.render,
        "'first' of undefined",
      );
    }
    return memberLookup(v, 0);
  },
  'last': (root, v, a) {
    if (_nullish(v)) {
      throw AnvilTemplateError(TemplateErrorKind.render, "'last' of undefined");
    }
    if (v is List && v.isNotEmpty) return v.last;
    if (v is String && v.isNotEmpty) return v[v.length - 1];
    return jsUndefined;
  },
  'reverse': (root, v, a) {
    if (v is String) return v.split('').reversed.join();
    if (v is List) return v.reversed.toList();
    return <Object?>[];
  },
};

String _capitalize(String s) {
  final lower = s.toLowerCase();
  return lower.isEmpty ? lower : lower[0].toUpperCase() + lower.substring(1);
}

Object? _default(Map<String, Object?> root, Object? v, List<Object?> a) {
  final fallback = _arg(a, 0);
  if (jsTruthy(_arg(a, 1))) return jsTruthy(v) ? v : fallback;
  return v is JsUndefined ? fallback : v;
}

Object? _replace(Object? str, Object? from, Object? replacement, Object? max) {
  final maxCount = max is num ? max : -1;
  final String old;
  if (from is num) {
    old = jsToString(from);
  } else if (from is String) {
    old = from;
  } else {
    return str;
  }
  if (str is num) str = jsToString(str);
  if (str is! String) return str;
  final repl = jsToString(replacement);
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
