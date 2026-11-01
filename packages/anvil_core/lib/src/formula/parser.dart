import 'formula_errors.dart';
import 'lexer.dart';

/// Formula syntax tree. Immutable and made of plain values, so a tree can be
/// cached and sent to another isolate.
sealed class FormulaExpr {
  const FormulaExpr();
}

final class NumberExpr extends FormulaExpr {
  const NumberExpr(this.value);
  final double value;
}

final class VariableExpr extends FormulaExpr {
  const VariableExpr(this.name);
  final String name;
}

final class NegateExpr extends FormulaExpr {
  const NegateExpr(this.operand);
  final FormulaExpr operand;
}

enum BinaryOp { add, subtract, multiply, divide }

final class BinaryExpr extends FormulaExpr {
  const BinaryExpr(this.op, this.left, this.right);
  final BinaryOp op;
  final FormulaExpr left;
  final FormulaExpr right;
}

final class CallExpr extends FormulaExpr {
  const CallExpr(this.name, this.args);
  final String name;
  final List<FormulaExpr> args;
}

/// The deepest nesting a formula may have: each parenthesised group, call
/// argument list and unary minus counts one level, so `-(-(1))` is four
/// levels deep and a flat chain like `1 + 2 + 3` is one. A deeper formula
/// does not parse: `validateFormula` reports `Invalid formula` and
/// `evaluateFormula` `Formula evaluation failed`, which is what 0.1.6
/// reports when Node's stack overflows (a machine-dependent few thousand
/// levels). An explicit limit keeps the outcome the same on every machine.
const int maxFormulaNestingDepth = 1000;

/// Thrown by [parse] past [maxFormulaNestingDepth]; not a syntax error.
final class FormulaNestingTooDeep implements Exception {
  const FormulaNestingTooDeep();
}

/// Parses [tokens] (from [tokenize]) with the Electron grammar:
///
///     expr    = term (('+' | '-') term)*
///     term    = factor (('*' | '/') factor)*
///     factor  = '-' factor | primary
///     primary = NUMBER | IDENT '(' arglist ')' | IDENT | '(' expr ')'
///     arglist = expr (',' expr)*
///
/// Throws [FormulaSyntaxError] with the Electron messages, and
/// [FormulaNestingTooDeep] past [maxFormulaNestingDepth].
FormulaExpr parse(List<Token> tokens) => _Parser(tokens).parseFormula();

final class _Parser {
  _Parser(this._tokens);

  final List<Token> _tokens;
  int _pos = 0;
  int _depth = 0;

  /// Runs one nested level of the descent under [maxFormulaNestingDepth].
  FormulaExpr _nested(FormulaExpr Function() parseLevel) {
    if (++_depth > maxFormulaNestingDepth) throw const FormulaNestingTooDeep();
    try {
      return parseLevel();
    } finally {
      _depth--;
    }
  }

  Token get _peek => _tokens[_pos];

  Token _consume() => _tokens[_pos++];

  Token _expect(TokenType type) {
    final tok = _peek;
    if (tok.type != type) {
      throw FormulaSyntaxError(
        "Expected ${type.label} but found '${tok.value}' at position ${tok.pos}",
      );
    }
    return _consume();
  }

  FormulaExpr parseFormula() {
    final ast = _parseExpr();
    final tok = _peek;
    if (tok.type != TokenType.eof) {
      throw FormulaSyntaxError(
        "Unexpected '${tok.value}' at position ${tok.pos}",
      );
    }
    return ast;
  }

  FormulaExpr _parseExpr() {
    var left = _parseTerm();
    while (_peek.type == TokenType.plus || _peek.type == TokenType.minus) {
      final op = _consume().type == TokenType.plus
          ? BinaryOp.add
          : BinaryOp.subtract;
      left = BinaryExpr(op, left, _parseTerm());
    }
    return left;
  }

  FormulaExpr _parseTerm() {
    var left = _parseFactor();
    while (_peek.type == TokenType.star || _peek.type == TokenType.slash) {
      final op = _consume().type == TokenType.star
          ? BinaryOp.multiply
          : BinaryOp.divide;
      left = BinaryExpr(op, left, _parseFactor());
    }
    return left;
  }

  FormulaExpr _parseFactor() {
    if (_peek.type == TokenType.minus) {
      _consume();
      return NegateExpr(_nested(_parseFactor));
    }
    return _parsePrimary();
  }

  FormulaExpr _parsePrimary() {
    final tok = _peek;
    switch (tok.type) {
      case TokenType.number:
        _consume();
        final value = parseFloatPrefix(tok.value);
        if (value.isNaN) {
          throw FormulaSyntaxError("Invalid number '${tok.value}'");
        }
        return NumberExpr(value);
      case TokenType.ident:
        _consume();
        if (_peek.type == TokenType.lparen) {
          _consume();
          final args = <FormulaExpr>[];
          if (_peek.type != TokenType.rparen) {
            args.add(_nested(_parseExpr));
            while (_peek.type == TokenType.comma) {
              _consume();
              args.add(_nested(_parseExpr));
            }
          }
          _expect(TokenType.rparen);
          return CallExpr(tok.value, List.unmodifiable(args));
        }
        return VariableExpr(tok.value);
      case TokenType.lparen:
        _consume();
        final expr = _nested(_parseExpr);
        _expect(TokenType.rparen);
        return expr;
      case TokenType.eof:
        throw const FormulaSyntaxError('Unexpected end of formula');
      default:
        throw FormulaSyntaxError(
          "Unexpected '${tok.value}' at position ${tok.pos}",
        );
    }
  }
}
