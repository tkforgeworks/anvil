import 'formula_errors.dart';

/// Token kinds. [label] is the name Electron prints in
/// `Expected RPAREN but found ...`.
enum TokenType {
  number('NUMBER'),
  ident('IDENT'),
  plus('PLUS'),
  minus('MINUS'),
  star('STAR'),
  slash('SLASH'),
  lparen('LPAREN'),
  rparen('RPAREN'),
  comma('COMMA'),
  eof('EOF');

  const TokenType(this.label);

  final String label;
}

final class Token {
  const Token(this.type, this.value, this.pos);

  final TokenType type;
  final String value;

  /// Offset in UTF-16 code units, as JavaScript string indexing counts.
  final int pos;
}

const _singleCharTokens = <String, TokenType>{
  '+': TokenType.plus,
  '-': TokenType.minus,
  '*': TokenType.star,
  '/': TokenType.slash,
  '(': TokenType.lparen,
  ')': TokenType.rparen,
  ',': TokenType.comma,
};

/// Whether [codeUnit] matches JavaScript's `/\s/` (WhiteSpace and
/// LineTerminator), which is also the set `String.prototype.trim` removes.
/// Dart's `String.trim` differs: it also strips U+0085 (NEL).
bool isJsWhitespace(int codeUnit) =>
    (codeUnit >= 0x09 && codeUnit <= 0x0D) ||
    codeUnit == 0x20 ||
    codeUnit == 0xA0 ||
    codeUnit == 0x1680 ||
    (codeUnit >= 0x2000 && codeUnit <= 0x200A) ||
    codeUnit == 0x2028 ||
    codeUnit == 0x2029 ||
    codeUnit == 0x202F ||
    codeUnit == 0x205F ||
    codeUnit == 0x3000 ||
    codeUnit == 0xFEFF;

/// JavaScript's `!formula.trim()`: true when [input] is empty or holds only
/// JavaScript whitespace.
bool isBlankFormula(String input) {
  for (var i = 0; i < input.length; i++) {
    if (!isJsWhitespace(input.codeUnitAt(i))) return false;
  }
  return true;
}

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

bool _isIdentStart(int c) =>
    (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || c == 0x5F;

bool _isIdentPart(int c) => _isIdentStart(c) || _isDigit(c);

const _dot = 0x2E;

/// Splits [input] into tokens, ending with an [TokenType.eof] token.
///
/// A number starts at a digit, or at a `.` followed by a digit, and then
/// takes every following digit and `.` (`1.2.3` is one token; the parser
/// reads it the way `parseFloat` does). Identifiers are ASCII
/// `[a-zA-Z_][a-zA-Z0-9_]*`. Positions and the reported character are
/// UTF-16 code units, so an astral character reports its high surrogate.
List<Token> tokenize(String input) {
  final tokens = <Token>[];
  var pos = 0;

  while (pos < input.length) {
    final c = input.codeUnitAt(pos);
    if (isJsWhitespace(c)) {
      pos++;
      continue;
    }

    if (_isDigit(c) ||
        (c == _dot &&
            pos + 1 < input.length &&
            _isDigit(input.codeUnitAt(pos + 1)))) {
      final start = pos;
      while (pos < input.length) {
        final d = input.codeUnitAt(pos);
        if (!_isDigit(d) && d != _dot) break;
        pos++;
      }
      tokens.add(Token(TokenType.number, input.substring(start, pos), start));
      continue;
    }

    if (_isIdentStart(c)) {
      final start = pos;
      while (pos < input.length && _isIdentPart(input.codeUnitAt(pos))) {
        pos++;
      }
      tokens.add(Token(TokenType.ident, input.substring(start, pos), start));
      continue;
    }

    final ch = input[pos];
    final single = _singleCharTokens[ch];
    if (single != null) {
      tokens.add(Token(single, ch, pos++));
      continue;
    }

    throw FormulaSyntaxError("Unexpected character '$ch' at position $pos");
  }

  tokens.add(Token(TokenType.eof, '', pos));
  return tokens;
}

/// JavaScript `parseFloat` on a number token (digits and dots only): the
/// longest prefix of the form `digits [. digits]` is read, so `1.2.3` is
/// 1.2, `5.` is 5 and `.5` is 0.5. Returns NaN when no digit leads the
/// prefix, which the lexer never produces.
double parseFloatPrefix(String token) {
  var i = 0;
  while (i < token.length && _isDigit(token.codeUnitAt(i))) {
    i++;
  }
  final intDigits = i;
  var fracDigits = 0;
  if (i < token.length && token.codeUnitAt(i) == _dot) {
    i++;
    while (i < token.length && _isDigit(token.codeUnitAt(i))) {
      i++;
      fracDigits++;
    }
  }
  if (intDigits == 0 && fracDigits == 0) return double.nan;
  final intPart = intDigits == 0 ? '0' : token.substring(0, intDigits);
  final fracPart = fracDigits == 0
      ? ''
      : '.${token.substring(intDigits + 1, intDigits + 1 + fracDigits)}';
  return double.parse('$intPart$fracPart');
}
