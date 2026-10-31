/// Recursive-descent parser following Nunjucks 3.2.4 `parser.js`: the same
/// precedence ladder (filters bind to the operand, each arithmetic operator
/// has its own level) and the same whitespace-control rules. Anything outside
/// the subset is rejected here, at parse time, so a stored template can be
/// checked without rendering it.
library;

import 'ast.dart';
import 'errors.dart';
import 'jsassoc.dart';
import 'lexer.dart';

/// Filters the renderer implements (see filters.dart).
const supportedFilters = {
  'json', 'export_key', // Anvil's own
  'length', 'upper', 'lower', 'capitalize', 'title', 'trim', 'default', 'd',
  'replace', 'join', 'first', 'last', 'reverse', 'dump',
};

/// Nunjucks tags that are valid but deliberately unsupported.
const _unsupportedTags = {
  'macro',
  'call',
  'import',
  'from',
  'include',
  'extends',
  'block',
  'raw',
  'verbatim',
  'filter',
  'switch',
  'asyncEach',
  'asyncAll',
  'ifAsync',
};

const _maxDepth = 200;

List<Node> parseTemplate(String source) => _Parser(tokenize(source)).parse();

final class _Parser {
  _Parser(List<Token> tokens) : _tokens = tokens;

  final List<Token> _tokens;
  int _pos = 0;
  bool _dropLeadingWhitespace = false;
  List<String>? _breakOnBlocks;
  int _depth = 0;

  List<Node> parse() => _parseNodes();

  // --- token helpers ------------------------------------------------------

  Token? _next({bool withWhitespace = false}) {
    while (_pos < _tokens.length) {
      final t = _tokens[_pos++];
      if (withWhitespace || t.type != Tok.whitespace) return t;
    }
    return null;
  }

  Token? _peek() {
    final saved = _pos;
    final t = _next();
    _pos = saved;
    return t;
  }

  Token? _peekRaw() => _pos < _tokens.length ? _tokens[_pos] : null;

  bool _skip(Tok type) {
    final t = _peek();
    if (t == null || t.type != type) return false;
    _next();
    return true;
  }

  bool _skipValue(Tok type, String value) {
    final t = _peek();
    if (t == null || t.type != type || t.value != value) return false;
    _next();
    return true;
  }

  bool _skipSymbol(String name) => _skipValue(Tok.symbol, name);

  Never _fail(String message, [Token? at]) {
    at ??= _peek() ?? (_tokens.isEmpty ? null : _tokens.last);
    throw AnvilTemplateError(
      TemplateErrorKind.syntax,
      message,
      line: at == null ? null : at.line + 1,
      column: at == null ? null : at.column + 1,
    );
  }

  Never _unsupported(String message, Token at) => throw AnvilTemplateError(
    TemplateErrorKind.unsupported,
    message,
    line: at.line + 1,
    column: at.column + 1,
  );

  T _nested<T>(T Function() body) {
    if (++_depth > _maxDepth) {
      throw AnvilTemplateError(
        TemplateErrorKind.limit,
        'template nesting too deep',
      );
    }
    try {
      return body();
    } finally {
      _depth--;
    }
  }

  // --- template structure ---------------------------------------------------

  List<Node> _parseNodes() => _nested(() {
    final out = <Node>[];
    for (Token? tok = _next(); tok != null; tok = _next()) {
      switch (tok.type) {
        case Tok.data:
          var text = tok.value;
          if (_dropLeadingWhitespace) {
            text = text.replaceFirst(RegExp(r'^\s*'), '');
            _dropLeadingWhitespace = false;
          }
          final n = _peekRaw();
          if (n != null &&
              ((n.type == Tok.blockStart && n.value.endsWith('-')) ||
                  (n.type == Tok.variableStart &&
                      n.value.length > 2 &&
                      n.value[2] == '-') ||
                  (n.type == Tok.comment &&
                      n.value.length > 2 &&
                      n.value[2] == '-'))) {
            text = text.replaceFirst(RegExp(r'\s*$'), '');
          }
          if (text.isNotEmpty) {
            out.add(TextNode(tok.line + 1, tok.column + 1, text));
          }
        case Tok.blockStart:
          _dropLeadingWhitespace = false;
          final node = _parseStatement(tok);
          if (node == null) return out;
          out.add(node);
        case Tok.variableStart:
          final expr = jsReassociate(_parseExpression());
          _dropLeadingWhitespace = false;
          final end = _next();
          if (end == null || end.type != Tok.variableEnd) {
            _fail('expected variable end', end);
          }
          _dropLeadingWhitespace = end.value.startsWith('-');
          out.add(OutputNode(tok.line + 1, tok.column + 1, expr));
        case Tok.comment:
          _dropLeadingWhitespace =
              tok.value.length >= 3 && tok.value[tok.value.length - 3] == '-';
        default:
          _fail('Unexpected token at top-level: ${tok.type.name}', tok);
      }
    }
    return out;
  });

  List<Node> _parseUntilBlocks(List<String> names) {
    final prev = _breakOnBlocks;
    _breakOnBlocks = names;
    final nodes = _parseNodes();
    _breakOnBlocks = prev;
    return nodes;
  }

  Node? _parseStatement(Token start) {
    final tok = _peek();
    if (tok == null || tok.type != Tok.symbol) {
      _fail('tag name expected', tok ?? start);
    }
    if (_breakOnBlocks?.contains(tok.value) ?? false) return null;
    return switch (tok.value) {
      'for' => _parseFor(),
      'if' => _parseIf(),
      'set' => _parseSet(),
      final t when _unsupportedTags.contains(t) => _unsupported(
        "the '$t' tag is not supported",
        tok,
      ),
      final t => _fail('unknown block tag: $t', tok),
    };
  }

  void _advanceAfterBlockEnd([String? name]) {
    if (name == null) {
      final t = _peek();
      if (t == null) _fail('unexpected end of file');
      if (t.type != Tok.symbol) _fail('expected symbol token', t);
      name = _next()!.value;
    }
    final end = _next();
    if (end == null || end.type != Tok.blockEnd) {
      _fail('expected block end in $name statement', end);
    }
    if (end.value.startsWith('-')) _dropLeadingWhitespace = true;
  }

  List<String> _targets(String tag) {
    final names = <String>[];
    do {
      final t = _next();
      if (t == null || t.type != Tok.symbol) {
        _fail('$tag: variable name expected', t);
      }
      final after = _peek();
      if (after != null &&
          (after.type == Tok.leftBracket ||
              (after.type == Tok.operator && after.value == '.'))) {
        _unsupported('$tag: only plain variable names can be assigned', t);
      }
      names.add(t.value);
    } while (_skip(Tok.comma));
    return names;
  }

  Node _parseFor() {
    final tag = _next()!;
    final targets = _targets('for');
    if (!_skipSymbol('in')) _fail('parseFor: expected "in" keyword for loop');
    final iterable = jsReassociate(_parseExpression());
    _advanceAfterBlockEnd('for');
    final body = _parseUntilBlocks(['endfor', 'else']);
    List<Node>? orElse;
    if (_skipSymbol('else')) {
      _advanceAfterBlockEnd('else');
      orElse = _parseUntilBlocks(['endfor']);
    }
    _advanceAfterBlockEnd();
    return ForNode(
      tag.line + 1,
      tag.column + 1,
      targets,
      iterable,
      body,
      orElse,
    );
  }

  Node _parseIf() {
    final tag = _next()!; // if, elif or elseif
    final test = jsReassociate(_parseExpression());
    _advanceAfterBlockEnd(tag.value);
    final body = _parseUntilBlocks(['elif', 'elseif', 'else', 'endif']);
    final tok = _peek();
    List<Node>? orElse;
    switch (tok?.value) {
      case 'elif' || 'elseif':
        orElse = [_parseIf()];
      case 'else':
        _advanceAfterBlockEnd();
        orElse = _parseUntilBlocks(['endif']);
        _advanceAfterBlockEnd();
      case 'endif':
        _advanceAfterBlockEnd();
      default:
        _fail('parseIf: expected elif, else, or endif, got end of file');
    }
    return IfNode(tag.line + 1, tag.column + 1, test, body, orElse);
  }

  Node _parseSet() {
    final tag = _next()!;
    final targets = _targets('set');
    if (!_skipValue(Tok.operator, '=')) {
      final t = _peek();
      if (t != null && t.type == Tok.blockEnd) {
        _unsupported(
          'block assignment ({% set x %}...{% endset %}) is not '
          'supported',
          tag,
        );
      }
      _fail('parseSet: expected = or block end in set tag', t);
    }
    final value = jsReassociate(_parseExpression());
    _advanceAfterBlockEnd('set');
    return SetNode(tag.line + 1, tag.column + 1, targets, value);
  }

  // --- expressions: the Nunjucks precedence ladder ---------------------------

  Expr _parseExpression() => _nested(_parseInlineIf);

  Expr _parseInlineIf() {
    var node = _parseOr();
    if (_skipSymbol('if')) {
      final test = _parseOr();
      final orElse = _skipSymbol('else') ? _parseOr() : null;
      node = InlineIf(node.line, node.column, test, node, orElse);
    }
    return node;
  }

  Expr _parseOr() {
    var node = _parseAnd();
    while (_skipSymbol('or')) {
      node = Binary(node.line, node.column, 'or', node, _parseAnd());
    }
    return node;
  }

  Expr _parseAnd() {
    var node = _parseNot();
    while (_skipSymbol('and')) {
      node = Binary(node.line, node.column, 'and', node, _parseNot());
    }
    return node;
  }

  Expr _parseNot() {
    final tok = _peek();
    if (_skipSymbol('not')) {
      return Unary(tok!.line + 1, tok.column + 1, 'not', _nested(_parseNot));
    }
    return _parseIn();
  }

  Expr _parseIn() {
    var node = _parseIs();
    while (true) {
      final saved = _pos;
      final invert = _skipSymbol('not');
      if (_skipSymbol('in')) {
        node = Binary(
          node.line,
          node.column,
          invert ? 'not in' : 'in',
          node,
          _parseIs(),
        );
      } else {
        _pos = saved;
        break;
      }
    }
    return node;
  }

  Expr _parseIs() {
    final node = _parseCompare();
    final tok = _peek();
    if (_skipSymbol('is')) _unsupported("'is' tests are not supported", tok!);
    return node;
  }

  static const _compareOps = ['==', '===', '!=', '!==', '<', '>', '<=', '>='];

  Expr _parseCompare() {
    final first = _parseConcat();
    final ops = <String>[], operands = <Expr>[];
    while (true) {
      final t = _peek();
      if (t == null ||
          t.type != Tok.operator ||
          !_compareOps.contains(t.value)) {
        break;
      }
      _next();
      ops.add(t.value);
      operands.add(_parseConcat());
    }
    return ops.isEmpty
        ? first
        : Compare(first.line, first.column, first, ops, operands);
  }

  Expr _parseConcat() {
    var node = _parseBinary(0);
    while (_skipValue(Tok.tilde, '~')) {
      node = Binary(node.line, node.column, '~', node, _parseBinary(0));
    }
    return node;
  }

  // parseAdd > parseSub > parseMul > parseDiv > parseFloorDiv > parseMod >
  // parsePow, each a separate level as in Nunjucks.
  static const _arithmetic = ['+', '-', '*', '/', '//', '%', '**'];

  Expr _parseBinary(int level) {
    if (level == _arithmetic.length) return _parseUnary();
    final op = _arithmetic[level];
    var node = _parseBinary(level + 1);
    while (_skipValue(Tok.operator, op)) {
      node = Binary(node.line, node.column, op, node, _parseBinary(level + 1));
    }
    return node;
  }

  Expr _parseUnary({bool noFilters = false}) {
    final tok = _peek();
    Expr node;
    if (_skipValue(Tok.operator, '-')) {
      node = Unary(
        tok!.line + 1,
        tok.column + 1,
        '-',
        _nested(() => _parseUnary(noFilters: true)),
      );
    } else if (_skipValue(Tok.operator, '+')) {
      node = Unary(
        tok!.line + 1,
        tok.column + 1,
        '+',
        _nested(() => _parseUnary(noFilters: true)),
      );
    } else {
      node = _parsePrimary();
    }
    return noFilters ? node : _parseFilter(node);
  }

  Expr _parsePrimary() {
    final tok = _next();
    if (tok == null) _fail('expected expression, got end of file');
    final line = tok.line + 1, col = tok.column + 1;
    Expr node;
    switch (tok.type) {
      case Tok.string:
        node = Literal(line, col, tok.value);
      case Tok.integer:
        node = Literal(
          line,
          col,
          int.tryParse(tok.value) ?? double.parse(tok.value),
        );
      case Tok.float:
        final v = tok.value.endsWith('.') ? '${tok.value}0' : tok.value;
        node = Literal(line, col, double.parse(v));
      case Tok.boolean:
        node = Literal(line, col, tok.value == 'true');
      case Tok.none:
        node = Literal(line, col, null);
      case Tok.symbol:
        node = Name(line, col, tok.value);
      default:
        _pos--;
        node =
            _parseAggregate() ?? _fail('unexpected token: ${tok.value}', tok);
    }
    return _parsePostfix(node);
  }

  Expr _parsePostfix(Expr node) {
    for (var tok = _peek(); tok != null; tok = _peek()) {
      if (tok.type == Tok.leftParen) {
        _unsupported(
          'function and method calls are not supported '
          '(macros, range(), cycler(), string methods)',
          tok,
        );
      } else if (tok.type == Tok.leftBracket) {
        final agg = _parseAggregate() as ListLiteral;
        if (agg.items.length != 1) _fail('invalid index', tok);
        node = Lookup(tok.line + 1, tok.column + 1, node, agg.items.single);
      } else if (tok.type == Tok.operator && tok.value == '.') {
        _next();
        final name = _next();
        if (name == null || name.type != Tok.symbol) {
          _fail('expected name as lookup value, got ${name?.value}', name);
        }
        node = Lookup(
          tok.line + 1,
          tok.column + 1,
          node,
          Literal(name.line + 1, name.column + 1, name.value),
        );
      } else {
        break;
      }
    }
    return node;
  }

  Expr? _parseAggregate() => _nested(() {
    final open = _next()!;
    final line = open.line + 1, col = open.column + 1;
    final items = <Expr>[], keys = <Expr>[];
    final isDict = open.type == Tok.leftCurly;
    if (open.type != Tok.leftParen && open.type != Tok.leftBracket && !isDict) {
      _pos--;
      return null;
    }
    while (true) {
      final t = _peek();
      if (t == null) _fail('unexpected end of file', open);
      if (t.type == Tok.rightParen ||
          t.type == Tok.rightBracket ||
          t.type == Tok.rightCurly) {
        _next();
        break;
      }
      if (items.isNotEmpty && !_skip(Tok.comma)) {
        _fail('parseAggregate: expected comma after expression', open);
      }
      if (isDict) {
        var key = _parsePrimary();
        // Nunjucks turns a bare-name key into a string key: {b: 2}.
        if (key is Name) key = Literal(key.line, key.column, key.name);
        if (!_skip(Tok.colon)) {
          _fail('parseAggregate: expected colon after dict key', open);
        }
        keys.add(key);
      }
      items.add(_parseExpression());
    }
    if (isDict) return DictLiteral(line, col, keys, items);
    if (open.type == Tok.leftBracket) return ListLiteral(line, col, items);
    if (items.length != 1) {
      _unsupported('a parenthesised group must hold one expression', open);
    }
    return Group(line, col, items.single);
  });

  Expr _parseFilter(Expr node) {
    while (_skip(Tok.pipe)) {
      final nameTok = _next();
      if (nameTok == null || nameTok.type != Tok.symbol) {
        _fail('expected symbol, got ${nameTok?.type.name}', nameTok);
      }
      if (!supportedFilters.contains(nameTok.value)) {
        _unsupported("the '${nameTok.value}' filter is not supported", nameTok);
      }
      final args = <Expr>[];
      if (_skip(Tok.leftParen)) {
        while (!_skip(Tok.rightParen)) {
          if (args.isNotEmpty && !_skip(Tok.comma)) {
            _fail('expected comma between filter arguments');
          }
          if (_peek()?.type == Tok.rightParen) continue;
          final saved = _pos;
          final t = _next();
          if (t?.type == Tok.symbol && _peek()?.value == '=') {
            _unsupported('keyword arguments are not supported', t!);
          }
          _pos = saved;
          args.add(_parseExpression());
        }
      }
      node = FilterCall(
        nameTok.line + 1,
        nameTok.column + 1,
        nameTok.value,
        node,
        args,
      );
    }
    return node;
  }
}
