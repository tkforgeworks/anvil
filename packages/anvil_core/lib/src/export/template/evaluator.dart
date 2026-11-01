/// Tree-walking evaluator with Nunjucks 3.2.4 runtime semantics: JS
/// truthiness and operators, frame-scoped `set`, `undefined` distinct from
/// `null`, and Anvil's `throwOnUndefined` (outputting null or undefined
/// throws; looking up a missing name does not).
library;

import '../js_compat.dart';
import '../render_limits.dart';
import 'ast.dart';
import 'errors.dart';
import 'filters.dart';

final class _Frame {
  _Frame(this.parent);
  final _Frame? parent;
  final Map<String, Object?> vars = {};

  Object? lookup(String name) {
    for (_Frame? f = this; f != null; f = f.parent) {
      final v = f.vars[name];
      if (v != null || f.vars.containsKey(name)) {
        if (v is! JsUndefined) return v;
      }
    }
    return jsUndefined;
  }

  /// Nunjucks `frame.set(name, value, resolveUp = true)`: assign where the
  /// name already lives, else in this frame.
  void assign(String name, Object? value) {
    for (_Frame? f = this; f != null; f = f.parent) {
      if (f.vars.containsKey(name) && f.vars[name] is! JsUndefined) {
        f.vars[name] = value;
        return;
      }
    }
    vars[name] = value;
  }
}

final class Evaluator {
  Evaluator(this.root, this.limits) : _ctx = {...root, 'ctx': root};

  /// The export context; `ctx` is an alias for it, as in 0.1.6.
  final Map<String, Object?> root;
  final RenderLimits limits;
  final Map<String, Object?> _ctx;

  /// Built on the first `export_key`, once per render.
  late final ExportKeyIndex _exportKeys = ExportKeyIndex(root);
  final StringBuffer _out = StringBuffer();
  int _iterations = 0;
  int _work = 0;

  String render(List<Node> nodes) {
    _block(nodes, _Frame(null));
    return _out.toString();
  }

  Never _error(
    Node at,
    String message, [
    TemplateErrorKind kind = TemplateErrorKind.render,
  ]) =>
      throw AnvilTemplateError(kind, message, line: at.line, column: at.column);

  String _sized(Node at, String s) {
    _work += s.length;
    if (s.length > limits.maxOutputChars) {
      _error(at, 'string size limit exceeded', TemplateErrorKind.limit);
    }
    if (_work > limits.maxWorkChars) {
      _error(at, 'string work limit exceeded', TemplateErrorKind.limit);
    }
    return s;
  }

  void _block(List<Node> nodes, _Frame frame) {
    for (final node in nodes) {
      switch (node) {
        case TextNode(:final text):
          _write(node, text);
        case OutputNode(:final expr):
          final v = _eval(expr, frame);
          if (v == null || v is JsUndefined) {
            _error(node, 'attempted to output null or undefined value');
          }
          _write(node, _str(node, v));
        case IfNode(:final test, :final body, :final orElse):
          if (jsTruthy(_eval(test, frame))) {
            _block(body, frame);
          } else if (orElse != null) {
            _block(orElse, frame);
          }
        case SetNode(:final targets, :final value):
          final v = _eval(value, frame);
          for (final t in targets) {
            frame.assign(t, v);
          }
        case ForNode():
          _for(node, frame);
        case Expr():
          _error(node, 'expression in statement position');
      }
    }
  }

  void _write(Node at, String s) {
    _out.write(s);
    if (_out.length > limits.maxOutputChars) {
      _error(at, 'output size limit exceeded', TemplateErrorKind.limit);
    }
  }

  void _for(ForNode node, _Frame outer) {
    final frame = _Frame(outer);
    final iterable = _eval(node.iterable, frame);
    var length = 0;
    void iteration(int i, int len, void Function() bind) {
      if (++_iterations > limits.maxIterations) {
        _error(node, 'loop iteration limit exceeded', TemplateErrorKind.limit);
      }
      bind();
      frame.vars['loop'] = <String, Object?>{
        'index': i + 1,
        'index0': i,
        'revindex': len - i,
        'revindex0': len - i - 1,
        'first': i == 0,
        'last': i == len - 1,
        'length': len,
      };
      _block(node.body, frame);
    }

    if (jsTruthy(iterable)) {
      final targets = node.targets;
      if (targets.length == 1) {
        // Arrays and strings iterate; objects and numbers have no .length.
        final items = iterable is List
            ? iterable
            : iterable is String
            ? iterable.split('')
            : null;
        if (items != null) {
          length = items.length;
          for (var i = 0; i < items.length; i++) {
            iteration(i, length, () => frame.vars[targets[0]] = items[i]);
          }
        }
      } else if (iterable is List) {
        length = iterable.length;
        for (var i = 0; i < iterable.length; i++) {
          iteration(i, length, () {
            for (var u = 0; u < targets.length; u++) {
              frame.vars[targets[u]] = memberLookup(iterable[i], u);
            }
          });
        }
      } else if (iterable is Map) {
        final keys = jsKeyOrder(iterable);
        length = keys.length;
        for (var i = 0; i < keys.length; i++) {
          iteration(i, length, () {
            frame.vars[targets[0]] = keys[i];
            frame.vars[targets[1]] = iterable[keys[i]];
          });
        }
      }
    }
    if (length == 0 && node.orElse != null) _block(node.orElse!, frame);
  }

  String _str(Node at, Object? v) => _sized(at, jsString(v));

  Object? _eval(Expr e, _Frame frame) {
    switch (e) {
      case Literal(:final value):
        return value;
      case Name(:final name):
        final v = frame.lookup(name);
        if (v is! JsUndefined) return v;
        return _ctx.containsKey(name) ? _ctx[name] : jsUndefined;
      case Lookup(:final target, :final key):
        return memberLookup(_eval(target, frame), _eval(key, frame));
      case Group(:final inner):
        return _eval(inner, frame);
      case ListLiteral(:final items):
        return [for (final i in items) _eval(i, frame)];
      case DictLiteral(:final keys, :final values):
        return <String, Object?>{
          for (var i = 0; i < keys.length; i++)
            jsString(_eval(keys[i], frame)): _eval(values[i], frame),
        };
      case InlineIf(:final test, :final body, :final orElse):
        if (jsTruthy(_eval(test, frame))) return _eval(body, frame);
        return orElse == null ? '' : _eval(orElse, frame);
      case Unary(:final op, :final operand):
        final v = _eval(operand, frame);
        return switch (op) {
          'not' => !jsTruthy(v),
          '-' => -jsToNumber(v),
          'floor' => jsToNumber(v).floorToDouble(),
          _ => jsToNumber(v),
        };
      case Compare(:final first, :final ops, :final operands):
        var left = _eval(first, frame);
        for (var i = 0; i < ops.length; i++) {
          final right = _eval(operands[i], frame);
          left = switch (ops[i]) {
            '==' => jsLooseEquals(left, right),
            '!=' => !jsLooseEquals(left, right),
            '===' => jsStrictEquals(left, right),
            '!==' => !jsStrictEquals(left, right),
            final op => jsCompare(left, op, right),
          };
        }
        return left;
      case Binary(:final op, :final left, :final right):
        return _binary(e, op, left, right, frame);
      case FilterCall(:final name, :final target, :final args):
        final value = _eval(target, frame);
        final argv = [for (final a in args) _eval(a, frame)];
        final Object? result;
        try {
          result = filters[name]!(_exportKeys, value, argv);
        } on FilterError catch (f) {
          _error(e, f.message);
        }
        return result is String ? _sized(e, result) : result;
    }
  }

  Object? _binary(Expr e, String op, Expr l, Expr r, _Frame frame) {
    final left = _eval(l, frame);
    if (op == 'and') return jsTruthy(left) ? _eval(r, frame) : left;
    if (op == 'or') return jsTruthy(left) ? left : _eval(r, frame);
    final right = _eval(r, frame);
    switch (op) {
      case '~': // emitted as `left + "" + right`
        return _sized(e, jsAdd(jsAdd(left, ''), right) as String);
      case '+':
        final v = jsAdd(left, right);
        return v is String ? _sized(e, v) : v;
      case 'in' || 'not in':
        final found = _in(e, left, right);
        return op == 'in' ? found : !found;
      default:
        return jsArithmetic(left, op, right);
    }
  }

  /// Nunjucks `runtime.inOperator`.
  bool _in(Expr e, Object? key, Object? container) {
    if (container is List) return container.any((v) => jsStrictEquals(v, key));
    if (container is String) return container.contains(jsString(key));
    if (container is Map) return container.containsKey(jsString(key));
    _error(
      e,
      'Cannot use "in" operator to search for "${jsString(key)}" '
      'in unexpected types.',
    );
  }
}
