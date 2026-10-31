/// Option 1: the `jinja` package (ykmnkmi/jinja.dart 0.7.2), configured as
/// close to Anvil's Nunjucks environment as its public API allows.
///
/// Public hooks used: `finalize` (every `{{ }}` value), `getItem` (every
/// `.name` / `[key]` lookup, since no `getAttribute` is passed), `undefined`
/// (unknown top-level names), `filters` and `globals`. Behaviour outside
/// those hooks (truthiness, `~`, `+`, `set` scoping, `for` over null) is
/// Jinja's and cannot be changed without importing `package:jinja/src/...`.
library;

import 'package:jinja/jinja.dart';

import 'anvil_filters.dart';
import 'js_compat.dart';

/// How a template's unknown names behave.
enum JinjaUndefinedMode {
  /// Unknown names are `null`; outputting `null` throws (Nunjucks-like).
  throwOnOutput,

  /// Any reference to an unknown top-level name throws, even in `if`.
  throwOnReference,
}

final class JinjaRenderer {
  JinjaRenderer({
    this.undefinedMode = JinjaUndefinedMode.throwOnOutput,
    this.jsOutput = true,
  }) {
    _env = Environment(
      // Nunjucks never strips the template's final newline; Jinja does.
      keepTrailingNewLine: true,
      autoReload: false,
      finalize: _finalize,
      getItem: _getItem,
      undefined: undefinedMode == JinjaUndefinedMode.throwOnReference
          ? _throwUndefined
          : _nullUndefined,
      filters: {'json': anvilJson, 'dump': _dump},
    );
    // Not Nunjucks globals, and `print` writes to the app's stdout.
    _env.globals
      ..remove('print')
      ..remove('namespace')
      ..remove('list')
      // jinja materialises the whole range before looping; cap it.
      ..['range'] = _cappedRange;
    _env.filters.remove('runtimetype');
  }

  /// Largest `range()` a template may build.
  static const maxRange = 100000;

  static Iterable<int> _cappedRange(
    int startOrStop, [
    int? stop,
    int step = 1,
  ]) {
    final start = stop == null ? 0 : startOrStop;
    final end = stop ?? startOrStop;
    if (step == 0) throw TemplateRuntimeError('range() step must not be zero');
    final count = ((end - start) / step).ceil();
    if (count > maxRange) {
      throw TemplateRuntimeError('range() of $count items exceeds $maxRange');
    }
    return [for (var i = start; step > 0 ? i < end : i > end; i += step) i];
  }

  final JinjaUndefinedMode undefinedMode;

  /// Print `{{ }}` values with JS `String(value)` rather than Dart `toString`.
  final bool jsOutput;

  late final Environment _env;

  String render(String source, Map<String, Object?> context) {
    // `export_key` needs the context; jinja's `Context` type is not exported,
    // so the filter is rebound per render instead of using `passContext`.
    _env.filters['export_key'] = (Object? id) => anvilExportKey(context, id);
    final template = _env.fromString(source);
    return template.render({...context, 'ctx': context});
  }

  Object? _finalize(Object? value) {
    if (value == null) {
      throw TemplateRuntimeError('attempted to output null or undefined value');
    }
    return jsOutput ? jsToString(value) : value;
  }

  static Object? _nullUndefined(String name, [String? template]) => null;

  static Object? _throwUndefined(String name, [String? template]) =>
      throw UndefinedError("'$name' is undefined");

  static String? _dump(Object? value, [Object? space]) =>
      jsJsonStringify(value, space);

  /// Nunjucks `memberLookup`: lookups on null yield null instead of throwing;
  /// `.length` works on lists and strings as in JS.
  static Object? _getItem(Object? key, Object? object) {
    if (object == null) return null;
    if (object is Map) return object[key];
    if (object is List) {
      if (key == 'length') return object.length;
      if (key is int) {
        return key >= 0 && key < object.length ? object[key] : null;
      }
      return null;
    }
    if (object is String) {
      if (key == 'length') return object.length;
      if (key is int) {
        return key >= 0 && key < object.length ? object[key] : null;
      }
      return null;
    }
    try {
      // jinja's LoopContext answers `loop['index']` etc.
      return (object as dynamic)[key];
    } on NoSuchMethodError {
      return null;
    } on TypeError {
      return null;
    }
  }
}
