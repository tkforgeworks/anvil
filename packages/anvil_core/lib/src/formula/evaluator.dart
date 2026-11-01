import 'formula_errors.dart';
import 'parser.dart';

/// The built-in function names. They are also dropped from
/// `extractVariableNames`, as Electron does.
const builtinFunctionNames = {'min', 'max', 'floor', 'ceil'};

/// How deep evaluation and variable collection recurse into a syntax tree
/// before giving up. The parser bounds nesting, but a flat chain such as
/// `x + x + ... + x` parses iteratively into a tree as deep as it is long
/// (Electron overflows Node's stack evaluating one of a few thousand terms).
/// The bound is well below where the Dart VM's own stack gave out (between
/// 4000 and 5000 levels for a cold JIT on Linux, 2026-11-01), so the failure
/// is the same on every machine; a real [StackOverflowError] is still caught
/// by the callers as a fallback.
const int maxFormulaTreeDepth = 2000;

/// Thrown past [maxFormulaTreeDepth]; not a runtime error.
final class FormulaTreeTooDeep implements Exception {
  const FormulaTreeTooDeep();
}

/// Evaluates [expr] with JavaScript number semantics. Throws
/// [FormulaRuntimeError] for an unknown variable or function, or a division
/// by an exact zero (either sign). NaN and infinities are ordinary values.
///
/// Evaluation order matches Electron: both operands before the division
/// check, the function name before its arguments, arguments left to right.
double evaluateExpr(
  FormulaExpr expr,
  Map<String, double> bindings, [
  int depth = 0,
]) {
  if (depth > maxFormulaTreeDepth) throw const FormulaTreeTooDeep();
  final next = depth + 1;
  switch (expr) {
    case NumberExpr(:final value):
      return value;
    case VariableExpr(:final name):
      final value = bindings[name];
      if (value == null) {
        throw FormulaRuntimeError("Unknown variable '$name'");
      }
      return value;
    case NegateExpr(:final operand):
      return -evaluateExpr(operand, bindings, next);
    case BinaryExpr(:final op, :final left, :final right):
      final l = evaluateExpr(left, bindings, next);
      final r = evaluateExpr(right, bindings, next);
      switch (op) {
        case BinaryOp.add:
          return l + r;
        case BinaryOp.subtract:
          return l - r;
        case BinaryOp.multiply:
          return l * r;
        case BinaryOp.divide:
          if (r == 0.0) throw const FormulaRuntimeError('Division by zero');
          return l / r;
      }
    case CallExpr(:final name, :final args):
      if (!builtinFunctionNames.contains(name)) {
        throw FormulaRuntimeError("Unknown function '$name'");
      }
      final values = [for (final a in args) evaluateExpr(a, bindings, next)];
      return switch (name) {
        'min' => _jsMin(values),
        'max' => _jsMax(values),
        'floor' => values.isEmpty ? double.nan : values.first.floorToDouble(),
        _ => values.isEmpty ? double.nan : values.first.ceilToDouble(),
      };
  }
}

/// `Math.min`: Infinity for no arguments, NaN if any argument is NaN, and
/// -0 below +0.
double _jsMin(List<double> values) {
  var result = double.infinity;
  var sawNaN = false;
  for (final v in values) {
    if (v.isNaN) {
      sawNaN = true;
    } else if (v < result || (v == 0 && result == 0 && v.isNegative)) {
      result = v;
    }
  }
  return sawNaN ? double.nan : result;
}

/// `Math.max`: -Infinity for no arguments, NaN if any argument is NaN, and
/// +0 above -0.
double _jsMax(List<double> values) {
  var result = double.negativeInfinity;
  var sawNaN = false;
  for (final v in values) {
    if (v.isNaN) {
      sawNaN = true;
    } else if (v > result || (v == 0 && result == 0 && result.isNegative)) {
      result = v;
    }
  }
  return sawNaN ? double.nan : result;
}

/// Variable names in [expr] in first-occurrence order (left before right,
/// arguments in order), without duplicates. Function names are not
/// variables; the caller drops [builtinFunctionNames] used as variables.
Set<String> collectVariables(FormulaExpr expr) {
  final acc = <String>{}; // insertion-ordered, like a JavaScript Set
  void visit(FormulaExpr e, int depth) {
    if (depth > maxFormulaTreeDepth) throw const FormulaTreeTooDeep();
    switch (e) {
      case NumberExpr():
        break;
      case VariableExpr(:final name):
        acc.add(name);
      case NegateExpr(:final operand):
        visit(operand, depth + 1);
      case BinaryExpr(:final left, :final right):
        visit(left, depth + 1);
        visit(right, depth + 1);
      case CallExpr(:final args):
        for (final a in args) {
          visit(a, depth + 1);
        }
    }
  }

  visit(expr, 0);
  return acc;
}
