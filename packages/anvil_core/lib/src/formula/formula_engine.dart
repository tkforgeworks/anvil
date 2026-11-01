import 'package:meta/meta.dart';

import 'evaluator.dart';
import 'formula_batch.dart';
import 'formula_errors.dart';
import 'lexer.dart';
import 'parser.dart';

/// The outcome of evaluating a formula, as Electron's `FormulaEvalResult`:
/// either a [value] (which may be NaN or infinite, as in JavaScript) or an
/// [error] message, with [isSyntaxError] telling a formula that does not
/// parse from one that fails with these bindings.
final class FormulaEvalResult {
  const FormulaEvalResult.value(double this.value)
    : error = null,
      isSyntaxError = false;

  const FormulaEvalResult.error(
    String this.error, {
    required this.isSyntaxError,
  }) : value = null;

  final double? value;
  final String? error;
  final bool isSyntaxError;

  @override
  String toString() => error == null
      ? 'FormulaEvalResult(value: $value)'
      : 'FormulaEvalResult(error: $error, isSyntaxError: $isSyntaxError)';
}

/// What parsing a formula produced; cached by [FormulaEngine].
@internal
sealed class FormulaAnalysis {
  const FormulaAnalysis();
}

@internal
final class ParsedFormula extends FormulaAnalysis {
  const ParsedFormula(this.ast);
  final FormulaExpr ast;
}

/// Empty formula, or a [FormulaSyntaxError] from the lexer or parser.
@internal
final class FormulaSyntaxFailure extends FormulaAnalysis {
  const FormulaSyntaxFailure(this.message);
  final String message;
}

/// Nesting past [maxFormulaNestingDepth] (or anything else the lexer or
/// parser threw, such as a stack overflow): Electron reports `Formula evaluation failed` from
/// `evaluateFormula` and `Invalid formula` from `validateFormula`.
@internal
final class FormulaParseCrash extends FormulaAnalysis {
  const FormulaParseCrash();
}

const _evaluationFailed = FormulaEvalResult.error(
  'Formula evaluation failed',
  isSyntaxError: false,
);

@internal
FormulaAnalysis analyzeFormula(String formula) {
  if (isBlankFormula(formula)) {
    return const FormulaSyntaxFailure('Formula is empty');
  }
  try {
    return ParsedFormula(parse(tokenize(formula)));
  } on FormulaSyntaxError catch (e) {
    return FormulaSyntaxFailure(e.message);
  } on FormulaNestingTooDeep {
    return const FormulaParseCrash();
  } on Object {
    // A real stack overflow, as a fallback.
    return const FormulaParseCrash();
  }
}

/// The result every evaluation of a formula that failed to parse returns,
/// or null when [analysis] parsed.
@internal
FormulaEvalResult? failedAnalysisResult(FormulaAnalysis analysis) =>
    switch (analysis) {
      ParsedFormula() => null,
      // TODO(ANVL-173): log 'Formula syntax error: <message>' as a warning.
      FormulaSyntaxFailure(:final message) => FormulaEvalResult.error(
        message,
        isSyntaxError: true,
      ),
      // TODO(ANVL-173): log 'Formula evaluation failed' as a warning.
      FormulaParseCrash() => _evaluationFailed,
    };

@internal
FormulaEvalResult evaluateAst(FormulaExpr ast, Map<String, double> bindings) {
  try {
    return FormulaEvalResult.value(evaluateExpr(ast, bindings));
  } on FormulaRuntimeError catch (e) {
    // TODO(ANVL-173): log 'Formula runtime error: <message>' as a warning.
    return FormulaEvalResult.error(e.message, isSyntaxError: false);
  } on Object {
    // TODO(ANVL-173): log 'Formula evaluation failed' as a warning.
    return _evaluationFailed;
  }
}

FormulaEvalResult _evaluate(
  FormulaAnalysis analysis,
  Map<String, double> bindings,
) => switch (analysis) {
  ParsedFormula(:final ast) => evaluateAst(ast, bindings),
  _ => failedAnalysisResult(analysis)!,
};

String? _validate(FormulaAnalysis analysis) => switch (analysis) {
  ParsedFormula() => null,
  FormulaSyntaxFailure(:final message) => message,
  FormulaParseCrash() => 'Invalid formula',
};

List<String> _variableNames(FormulaAnalysis analysis) {
  if (analysis is! ParsedFormula) return const [];
  try {
    final names = collectVariables(analysis.ast)
      ..removeAll(builtinFunctionNames);
    return List.unmodifiable(names);
  } on Object {
    return const [];
  }
}

/// Evaluates [formula] with [bindings]. Syntax and runtime errors come back
/// in the result, never as exceptions. Stateless; [FormulaEngine] caches.
FormulaEvalResult evaluateFormula(
  String formula,
  Map<String, double> bindings,
) => _evaluate(analyzeFormula(formula), bindings);

/// The syntax error message for [formula], or null when it parses.
String? validateFormula(String formula) => _validate(analyzeFormula(formula));

/// The variables [formula] references, in first-occurrence order without
/// duplicates and without the built-in function names; empty when the
/// formula does not parse.
List<String> extractVariableNames(String formula) =>
    _variableNames(analyzeFormula(formula));

/// The formula engine with an editor session's caches: a parse cache from
/// formula text to syntax tree (or syntax error) and an evaluation cache
/// keyed by formula and bindings, the bindings compared by value. Both
/// live as long as the engine; drop it (or call [clear]) with the editor.
final class FormulaEngine {
  final _parses = <String, FormulaAnalysis>{};
  final _results = <_EvalKey, FormulaEvalResult>{};
  int _parseCount = 0;
  int _evaluationCount = 0;

  /// How many times this engine has parsed a formula (parse-cache misses).
  @visibleForTesting
  int get parseCount => _parseCount;

  /// How many single evaluations ran (evaluation-cache misses).
  @visibleForTesting
  int get evaluationCount => _evaluationCount;

  FormulaAnalysis _analysis(String formula) => _parses.putIfAbsent(formula, () {
    _parseCount++;
    return analyzeFormula(formula);
  });

  /// [evaluateFormula] through both caches.
  FormulaEvalResult evaluate(String formula, Map<String, double> bindings) {
    final cached = _results[_EvalKey(formula, bindings)];
    if (cached != null) return cached;
    _evaluationCount++;
    final result = _evaluate(_analysis(formula), bindings);
    _results[_EvalKey(formula, Map.unmodifiable(bindings))] = result;
    return result;
  }

  /// [validateFormula] through the parse cache.
  String? validate(String formula) => _validate(_analysis(formula));

  /// [extractVariableNames] through the parse cache.
  List<String> extractVariableNames(String formula) =>
      _variableNames(_analysis(formula));

  /// [evaluateBatch] through the parse cache. A batch does not read or fill
  /// the evaluation cache, which would otherwise hold one entry per level.
  Future<List<FormulaEvalResult>> evaluateBatch(
    String formula,
    List<Map<String, double>> bindingsList, {
    int threshold = isolateThreshold,
  }) => evaluateAnalysisBatch(
    _analysis(formula),
    bindingsList,
    threshold: threshold,
  );

  /// Empties both caches.
  void clear() {
    _parses.clear();
    _results.clear();
  }
}

/// Evaluation-cache key. Bindings compare by value; doubles compare by
/// identity of value, so NaN matches NaN and -0 does not match 0 (they can
/// give different results, for example `min(x, 1)`).
final class _EvalKey {
  _EvalKey(this.formula, this.bindings)
    : hashCode = Object.hash(
        formula,
        Object.hashAllUnordered(
          bindings.entries.map((e) => Object.hash(e.key, e.value)),
        ),
      );

  final String formula;
  final Map<String, double> bindings;

  @override
  final int hashCode;

  @override
  bool operator ==(Object other) {
    if (other is! _EvalKey ||
        other.hashCode != hashCode ||
        other.formula != formula ||
        other.bindings.length != bindings.length) {
      return false;
    }
    for (final MapEntry(:key, :value) in bindings.entries) {
      final o = other.bindings[key];
      if (o == null || !_sameDouble(value, o)) return false;
    }
    return true;
  }
}

bool _sameDouble(double a, double b) =>
    a == b ? (a != 0 || a.isNegative == b.isNegative) : (a.isNaN && b.isNaN);
