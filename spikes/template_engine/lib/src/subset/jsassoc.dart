/// Nunjucks compiles `or`, `and`, `not`, `~`, `+ - * / %` and comparisons to
/// unparenthesised JavaScript, so JavaScript's precedence, not the parser's
/// ladder, decides the result: `not a == b` is `(!a) == b`, `1 ~ 2 + 3` is
/// `"123"`, `2 * 3 % 4` is `2`. This pass flattens each such operator region
/// and re-parses it with JS precedence. Boundaries are what Nunjucks emits as
/// calls or brackets: filters, lookups, literals, `( )`, inline `if`, `in`,
/// `**` (`Math.pow`) and `//` (`Math.floor(a / b)`, whose inside is a region).
library;

import 'ast.dart';

const _binaryPrecedence = {
  'or': 1, 'and': 2, //
  '==': 3, '!=': 3, '===': 3, '!==': 3,
  '<': 4, '>': 4, '<=': 4, '>=': 4,
  '+': 5, '-': 5, '~': 5,
  '*': 6, '/': 6, '%': 6,
};

const _compareOps = {'==', '!=', '===', '!==', '<', '>', '<=', '>='};

Expr jsReassociate(Expr e) => _isRegion(e) ? _parse(_flatten(e)) : _atom(e);

bool _isRegion(Expr e) => switch (e) {
  Binary(:final op) => _binaryPrecedence.containsKey(op),
  Compare() => true,
  Unary(:final op) => op != 'floor',
  _ => false,
};

/// Items are operator strings (`!x`, `-x`, `+x` for prefixes) or atoms.
List<Object> _flatten(Expr e, [List<Object>? into]) {
  final out = into ?? <Object>[];
  switch (e) {
    case Binary(:final op, :final left, :final right)
        when _binaryPrecedence.containsKey(op):
      _flatten(left, out);
      out.add(op);
      _flatten(right, out);
    case Compare(:final first, :final ops, :final operands):
      _flatten(first, out);
      for (var i = 0; i < ops.length; i++) {
        out.add(ops[i]);
        _flatten(operands[i], out);
      }
    case Unary(:final op, :final operand) when op != 'floor':
      out.add(op == 'not' ? '!x' : '${op}x');
      _flatten(operand, out);
    default:
      out.add(_atom(e));
  }
  return out;
}

Expr _atom(Expr e) => switch (e) {
  Literal() || Name() => e,
  Group(:final inner) => Group(e.line, e.column, jsReassociate(inner)),
  Lookup(:final target, :final key) => Lookup(
    e.line,
    e.column,
    jsReassociate(target),
    jsReassociate(key),
  ),
  ListLiteral(:final items) => ListLiteral(
    e.line,
    e.column,
    items.map(jsReassociate).toList(),
  ),
  DictLiteral(:final keys, :final values) => DictLiteral(
    e.line,
    e.column,
    keys,
    values.map(jsReassociate).toList(),
  ),
  InlineIf(:final test, :final body, :final orElse) => InlineIf(
    e.line,
    e.column,
    jsReassociate(test),
    jsReassociate(body),
    orElse == null ? null : jsReassociate(orElse),
  ),
  FilterCall(:final name, :final target, :final args) => FilterCall(
    e.line,
    e.column,
    name,
    jsReassociate(target),
    args.map(jsReassociate).toList(),
  ),
  // Math.floor(<left> / <right>): the inside is one region.
  Binary(op: '//', :final left, :final right) => Unary(
    e.line,
    e.column,
    'floor',
    _parse([..._flatten(left), '/', ..._flatten(right)]),
  ),
  Binary(:final op, :final left, :final right) => Binary(
    e.line,
    e.column,
    op,
    jsReassociate(left),
    jsReassociate(right),
  ),
  Unary(:final op, :final operand) => Unary(
    e.line,
    e.column,
    op,
    jsReassociate(operand),
  ),
  Compare() => jsReassociate(e),
};

Expr _parse(List<Object> items) {
  var pos = 0;
  Expr prefix() {
    final item = items[pos++];
    if (item is Expr) return item;
    final op = item as String; // '!x', '-x', '+x'
    final operand = prefix();
    return Unary(
      operand.line,
      operand.column,
      op == '!x' ? 'not' : op[0],
      operand,
    );
  }

  Expr level(int min) {
    var left = prefix();
    while (pos < items.length) {
      final op = items[pos] as String;
      final p = _binaryPrecedence[op]!;
      if (p < min) break;
      pos++;
      final right = level(p + 1); // all left-associative
      left = _compareOps.contains(op)
          ? Compare(left.line, left.column, left, [op], [right])
          : Binary(left.line, left.column, op, left, right);
    }
    return left;
  }

  return level(1);
}
