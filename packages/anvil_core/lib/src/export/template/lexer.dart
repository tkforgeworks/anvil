/// Tokeniser: a port of Nunjucks 3.2.4 `lexer.js` (default tags, no
/// trimBlocks/lstripBlocks, no regex literals) so that whitespace, string
/// escapes and number literals lex exactly as they did in Anvil 0.1.x.
library;

import 'errors.dart';

enum Tok {
  data,
  comment,
  blockStart,
  blockEnd,
  variableStart,
  variableEnd,
  whitespace,
  string,
  integer,
  float,
  boolean,
  none,
  symbol,
  operator,
  leftParen,
  rightParen,
  leftBracket,
  rightBracket,
  leftCurly,
  rightCurly,
  comma,
  colon,
  tilde,
  pipe,
}

final class Token {
  Token(this.type, this.value, this.line, this.column);
  final Tok type;
  final String value;

  /// 0-based, like Nunjucks; errors report +1.
  final int line;
  final int column;

  @override
  String toString() => '$type(${value.replaceAll('\n', r'\n')})';
}

const _whitespace = ' \n\t\r ';
const _delimiters = '()[]{}%*-+~/#,:|.<>=!';
const _digits = '0123456789';
const _complexOps = ['==', '===', '!=', '!==', '<=', '>=', '//', '**'];
final _intPattern = RegExp(r'^[-+]?[0-9]+$');

List<Token> tokenize(String source) {
  final lexer = _Lexer(source);
  final tokens = <Token>[];
  for (Token? t = lexer.next(); t != null; t = lexer.next()) {
    tokens.add(t);
  }
  return tokens;
}

final class _Lexer {
  _Lexer(this.src);

  final String src;
  int _i = 0, _line = 0, _col = 0;
  bool _inCode = false;

  bool get _done => _i >= src.length;
  String get _cur => _done ? '' : src[_i];

  void _forward() {
    _i++;
    if (src[_i - 1] == '\n') {
      _line++;
      _col = 0;
    } else {
      _col++;
    }
  }

  bool _matches(String s) => src.startsWith(s, _i);

  String? _take(String s) {
    if (!_matches(s)) return null;
    for (var k = 0; k < s.length; k++) {
      _forward();
    }
    return s;
  }

  /// `_extractMatching`: consume chars while they are (or, with
  /// [breakOnMatch], are not) in [chars]. Null at end of input.
  String? _extract(bool breakOnMatch, String chars) {
    if (_done) return null;
    bool stop(String c) =>
        breakOnMatch ? chars.contains(c) : !chars.contains(c);
    if (stop(_cur)) return '';
    final b = StringBuffer(_cur);
    _forward();
    while (!stop(_cur) && !_done) {
      b.write(_cur);
      _forward();
    }
    return b.toString();
  }

  Never _fail(String message, int line, int col) => throw AnvilTemplateError(
    TemplateErrorKind.syntax,
    message,
    line: line + 1,
    column: col + 1,
  );

  Token? next() {
    final line = _line, col = _col;
    Token tok(Tok type, String value) => Token(type, value, line, col);
    if (_done) return null;

    if (_inCode) {
      final cur = _cur;
      if (cur == '"' || cur == "'") return tok(Tok.string, _string(cur));
      final ws = _extract(false, _whitespace);
      if (ws != null && ws.isNotEmpty) return tok(Tok.whitespace, ws);
      final blockEnd = _take('%}') ?? _take('-%}');
      if (blockEnd != null) {
        _inCode = false;
        return tok(Tok.blockEnd, blockEnd);
      }
      final varEnd = _take('}}') ?? _take('-}}');
      if (varEnd != null) {
        _inCode = false;
        return tok(Tok.variableEnd, varEnd);
      }
      if (cur == 'r' && _i + 1 < src.length && src[_i + 1] == '/') {
        throw AnvilTemplateError(
          TemplateErrorKind.unsupported,
          'regular expression literals are not supported',
          line: line + 1,
          column: col + 1,
        );
      }
      if (_delimiters.contains(cur)) {
        _forward();
        var op = cur;
        final two = cur + _cur;
        if (_complexOps.contains(two)) {
          _forward();
          op = two;
          if (_complexOps.contains(two + _cur)) {
            op = two + _cur;
            _forward();
          }
        }
        return tok(switch (op) {
          '(' => Tok.leftParen,
          ')' => Tok.rightParen,
          '[' => Tok.leftBracket,
          ']' => Tok.rightBracket,
          '{' => Tok.leftCurly,
          '}' => Tok.rightCurly,
          ',' => Tok.comma,
          ':' => Tok.colon,
          '~' => Tok.tilde,
          '|' => Tok.pipe,
          _ => Tok.operator,
        }, op);
      }
      final word = _extract(true, _whitespace + _delimiters)!;
      if (_intPattern.hasMatch(word)) {
        if (_cur == '.') {
          _forward();
          return tok(Tok.float, '$word.${_extract(false, _digits) ?? ''}');
        }
        return tok(Tok.integer, word);
      }
      if (word == 'true' || word == 'false') return tok(Tok.boolean, word);
      if (word == 'none' || word == 'null') return tok(Tok.none, word);
      if (word.isEmpty) _fail('Unexpected value while parsing', line, col);
      return tok(Tok.symbol, word);
    }

    final blockStart = _take('{%-') ?? _take('{%');
    if (blockStart != null) {
      _inCode = true;
      return tok(Tok.blockStart, blockStart);
    }
    final varStart = _take('{{-') ?? _take('{{');
    if (varStart != null) {
      _inCode = true;
      return tok(Tok.variableStart, varStart);
    }
    final text = StringBuffer();
    var inComment = false;
    if (_matches('{#')) {
      inComment = true;
      text.write(_take('{#'));
    }
    String? data;
    while ((data = _extract(true, '{#')) != null) {
      text.write(data);
      if (!inComment && (_matches('{%') || _matches('{{') || _matches('{#'))) {
        break;
      } else if (_matches('#}')) {
        if (!inComment) _fail('unexpected end of comment', _line, _col);
        text.write(_take('#}'));
        break;
      } else {
        text.write(_cur);
        if (!_done) _forward();
      }
    }
    if (data == null && inComment) {
      _fail('expected end of comment, got end of file', line, col);
    }
    return tok(inComment ? Tok.comment : Tok.data, text.toString());
  }

  /// Nunjucks string literal: only `\n`, `\t`, `\r` are escapes; `\x` is `x`.
  String _string(String quote) {
    final line = _line, col = _col;
    _forward();
    final b = StringBuffer();
    while (!_done && _cur != quote) {
      if (_cur == r'\') {
        _forward();
        b.write(switch (_cur) {
          'n' => '\n',
          't' => '\t',
          'r' => '\r',
          final c => c,
        });
        if (!_done) _forward();
      } else {
        b.write(_cur);
        _forward();
      }
    }
    if (_done) _fail('unterminated string', line, col);
    _forward();
    return b.toString();
  }
}
