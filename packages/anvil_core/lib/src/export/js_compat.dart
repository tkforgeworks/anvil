/// JavaScript value semantics that Anvil 0.1.x exports depend on (design
/// §11.3, ANVL-151 FINDINGS §5).
///
/// The Electron app produced every export with JavaScript: `JSON.stringify`
/// for the JSON presets and the `json` filter, `String(value)` for CSV cells
/// and `{{ }}` output, and JS truthiness and operators inside Nunjucks.
/// Dart differs in each of these (`1.0` vs `1`, `[a, b]` vs `a,b`, integer
/// keys keep insertion order), so the presets and the template renderer both
/// go through these helpers. Checked against node in
/// `test/fixtures/export/js-values.json`.
library;

import 'dart:math' as math;

/// JavaScript `undefined`: a missing variable or key, distinct from `null`.
///
/// Nunjucks treats them differently in places (`default` only replaces
/// `undefined`; `'a' ~ x` prints `aundefined` or `anull`).
final class JsUndefined {
  const JsUndefined._();

  @override
  String toString() => 'undefined';
}

/// The single [JsUndefined] value.
const JsUndefined jsUndefined = JsUndefined._();

bool _isNullish(Object? v) => v == null || v is JsUndefined;

/// `Number.prototype.toString()` for a Dart number.
///
/// Dart's `double.toString()` uses the same shortest-round-trip digits and
/// exponent thresholds as JS, but appends `.0` to integral values and prints
/// `-0.0`; both are corrected here (checked against 20k doubles from node).
String jsNumberString(num n) {
  if (n is int) return n.toString();
  final d = n as double;
  if (d.isNaN) return 'NaN';
  if (d.isInfinite) return d > 0 ? 'Infinity' : '-Infinity';
  if (d == 0) return '0';
  final s = d.toString();
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

/// JS `ToString(value)`: what `{{ value }}`, `~` and CSV cells print.
String jsString(Object? v) {
  if (v == null) return 'null';
  if (v is JsUndefined) return 'undefined';
  if (v is String) return v;
  if (v is bool) return v ? 'true' : 'false';
  if (v is num) return jsNumberString(v);
  if (v is List) {
    // Array.prototype.join: null and undefined elements print as ''.
    return v.map((e) => _isNullish(e) ? '' : jsString(e)).join(',');
  }
  if (v is Map) return '[object Object]';
  return v.toString();
}

/// JS truthiness: `''`, `0`, `NaN`, `null`, `undefined`, `false` are falsy;
/// empty lists and maps are truthy (unlike Jinja/Python).
bool jsTruthy(Object? v) {
  if (_isNullish(v)) return false;
  if (v is bool) return v;
  if (v is num) return !(v == 0 || v.isNaN);
  if (v is String) return v.isNotEmpty;
  return true;
}

/// JS `ToNumber(value)` (always a double, as in JS).
double jsToNumber(Object? v) {
  if (v is JsUndefined) return double.nan;
  if (v == null) return 0;
  if (v is bool) return v ? 1 : 0;
  if (v is num) return v.toDouble();
  if (v is String) {
    final s = v.trim();
    if (s.isEmpty) return 0;
    if (s == 'Infinity' || s == '+Infinity') return double.infinity;
    if (s == '-Infinity') return double.negativeInfinity;
    final hex = RegExp(r'^0[xX]([0-9a-fA-F]+)$').firstMatch(s);
    // BigInt: a hex string longer than 64 bits is still a (large) number.
    if (hex != null) return BigInt.parse(hex.group(1)!, radix: 16).toDouble();
    if (!RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$').hasMatch(s)) {
      return double.nan;
    }
    return double.parse(s);
  }
  if (v is List) return jsToNumber(jsString(v));
  return double.nan;
}

Object? _toPrimitive(Object? v) => (v is List || v is Map) ? jsString(v) : v;

/// JS `===`.
bool jsStrictEquals(Object? a, Object? b) {
  if (a is num && b is num) return a == b; // NaN != NaN, 1 == 1.0
  if (a is String && b is String) return a == b;
  if (a is bool && b is bool) return a == b;
  if (a == null && b == null) return true;
  if (a is JsUndefined && b is JsUndefined) return true;
  return identical(a, b);
}

/// JS `==` (abstract equality), which Nunjucks emits for `==`.
bool jsLooseEquals(Object? a, Object? b) {
  if (_isNullish(a) || _isNullish(b)) return _isNullish(a) && _isNullish(b);
  if ((a is List || a is Map) && (b is List || b is Map)) {
    return identical(a, b);
  }
  if (a is bool) return jsLooseEquals(a ? 1 : 0, b);
  if (b is bool) return jsLooseEquals(a, b ? 1 : 0);
  if (a is List || a is Map) return jsLooseEquals(_toPrimitive(a), b);
  if (b is List || b is Map) return jsLooseEquals(a, _toPrimitive(b));
  if (a is num && b is String) return a == jsToNumber(b);
  if (a is String && b is num) return jsToNumber(a) == b;
  return jsStrictEquals(a, b);
}

/// JS relational comparison; [op] is one of `<`, `>`, `<=`, `>=`.
bool jsCompare(Object? a, String op, Object? b) {
  final pa = _toPrimitive(a), pb = _toPrimitive(b);
  if (pa is String && pb is String) {
    final c = pa.compareTo(pb); // UTF-16 code-unit order, as in JS
    return switch (op) {
      '<' => c < 0,
      '>' => c > 0,
      '<=' => c <= 0,
      _ => c >= 0,
    };
  }
  final x = jsToNumber(pa), y = jsToNumber(pb);
  if (x.isNaN || y.isNaN) return false;
  return switch (op) {
    '<' => x < y,
    '>' => x > y,
    '<=' => x <= y,
    _ => x >= y,
  };
}

/// JS binary `+`: string concatenation if either side is (or becomes) a
/// string, numeric addition otherwise.
Object jsAdd(Object? a, Object? b) {
  final pa = _toPrimitive(a), pb = _toPrimitive(b);
  if (pa is String || pb is String) return jsString(pa) + jsString(pb);
  return jsToNumber(pa) + jsToNumber(pb);
}

/// JS arithmetic for `-`, `*`, `/`, `%`, `**` and Nunjucks `//`
/// (`Math.floor(a / b)`). Results are doubles, as in JS.
double jsArithmetic(Object? a, String op, Object? b) {
  final x = jsToNumber(a), y = jsToNumber(b);
  return switch (op) {
    '-' => x - y,
    '*' => x * y,
    '/' => x / y,
    '%' => x.remainder(y), // JS %: sign follows the dividend
    '**' => _pow(x, y),
    '//' => (x / y).floorToDouble(),
    _ => throw ArgumentError.value(op, 'op'),
  };
}

double _pow(double x, double y) {
  // Math.pow differs from C pow only for these two cases.
  if (y.isNaN) return double.nan;
  if (y.isInfinite && x.abs() == 1) return double.nan;
  return math.pow(x, y).toDouble();
}

// ---------------------------------------------------------------------------
// JSON.stringify
// ---------------------------------------------------------------------------

/// The `gap` that `JSON.stringify(v, null, space)` derives from `space`:
/// a number is clamped to 0..10 spaces, a string is cut to 10 characters,
/// anything else means compact output.
String _jsonGap(Object? space) {
  if (space is num) {
    final n = space.isNaN ? 0 : space.clamp(0, 10).truncate();
    return ' ' * n;
  }
  if (space is String) {
    return space.length > 10 ? space.substring(0, 10) : space;
  }
  return '';
}

/// Keys in JavaScript property order: array-index keys ("0".."4294967294")
/// first in ascending numeric order, then the rest in insertion order.
List<String> jsKeyOrder(Map map) {
  final keys = map.keys.map((k) => k.toString()).toList();
  final index = keys.where(_isArrayIndex).toList()
    ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
  if (index.isEmpty) return keys;
  return [...index, ...keys.where((k) => !_isArrayIndex(k))];
}

bool _isArrayIndex(String k) {
  if (k.isEmpty || k.length > 10) return false;
  if (k == '0') return true;
  if (k.codeUnitAt(0) == 0x30) return false;
  for (final c in k.codeUnits) {
    if (c < 0x30 || c > 0x39) return false;
  }
  return int.parse(k) <= 4294967294;
}

/// `JSON.stringify(value, null, indent)`: compact without [indent], JS key
/// order, integral doubles without `.0`, NaN and infinities as `null`.
///
/// [indent] is a number (clamped to 10) or a string (cut to 10 characters),
/// as in JS; the `json` filter passes a string through, so `json('\t')`
/// indents with tabs. Returns `null` where JS returns `undefined` (an
/// undefined top-level value).
String? jsonStringify(Object? value, {Object? indent}) {
  if (value is JsUndefined) return null;
  final out = StringBuffer();
  _writeJson(out, value, _jsonGap(indent), '');
  return out.toString();
}

void _writeJson(StringBuffer out, Object? v, String gap, String indent) {
  if (v == null || v is JsUndefined) {
    out.write('null');
  } else if (v is bool) {
    out.write(v ? 'true' : 'false');
  } else if (v is num) {
    out.write(v.isFinite ? jsNumberString(v) : 'null');
  } else if (v is String) {
    out.write(jsonQuote(v));
  } else if (v is List) {
    if (v.isEmpty) {
      out.write('[]');
      return;
    }
    final inner = indent + gap;
    out.write('[');
    for (var i = 0; i < v.length; i++) {
      if (i > 0) out.write(',');
      if (gap.isNotEmpty) out.write('\n$inner');
      _writeJson(out, v[i], gap, inner);
    }
    if (gap.isNotEmpty) out.write('\n$indent');
    out.write(']');
  } else if (v is Map) {
    final keys = jsKeyOrder(v).where((k) => v[k] is! JsUndefined).toList();
    if (keys.isEmpty) {
      out.write('{}');
      return;
    }
    final inner = indent + gap;
    out.write('{');
    for (var i = 0; i < keys.length; i++) {
      if (i > 0) out.write(',');
      if (gap.isNotEmpty) out.write('\n$inner');
      out.write(jsonQuote(keys[i]));
      out.write(gap.isNotEmpty ? ': ' : ':');
      _writeJson(out, v[keys[i]], gap, inner);
    }
    if (gap.isNotEmpty) out.write('\n$indent');
    out.write('}');
  } else {
    throw ArgumentError('Cannot serialise ${v.runtimeType} to JSON');
  }
}

/// `QuoteJSONString` from ECMA-262 (well-formed `JSON.stringify`).
String jsonQuote(String s) {
  final out = StringBuffer('"');
  final units = s.codeUnits;
  for (var i = 0; i < units.length; i++) {
    final c = units[i];
    switch (c) {
      case 0x08:
        out.write(r'\b');
      case 0x09:
        out.write(r'\t');
      case 0x0A:
        out.write(r'\n');
      case 0x0C:
        out.write(r'\f');
      case 0x0D:
        out.write(r'\r');
      case 0x22:
        out.write(r'\"');
      case 0x5C:
        out.write(r'\\');
      default:
        if (c < 0x20) {
          out.write('\\u${c.toRadixString(16).padLeft(4, '0')}');
        } else if (c >= 0xD800 && c <= 0xDBFF) {
          if (i + 1 < units.length &&
              units[i + 1] >= 0xDC00 &&
              units[i + 1] <= 0xDFFF) {
            out.writeCharCode(c);
            out.writeCharCode(units[++i]);
          } else {
            out.write('\\u${c.toRadixString(16)}');
          }
        } else if (c >= 0xDC00 && c <= 0xDFFF) {
          out.write('\\u${c.toRadixString(16)}');
        } else {
          out.writeCharCode(c);
        }
    }
  }
  out.write('"');
  return out.toString();
}
