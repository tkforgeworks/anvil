import 'dart:isolate';

import 'package:meta/meta.dart';

import 'formula_engine.dart';
import 'parser.dart';

/// Batch size at and above which [evaluateBatch] evaluates on a background
/// isolate via `Isolate.run`. Below it the batch runs synchronously on the
/// calling isolate.
///
/// Set from `test/formula/benchmark/formula_benchmark.dart` (2026-11-01,
/// Linux x64, `floor(base_hp + level * hp_growth + max(1, strength * 0.5))`
/// with nine bindings per entry, median of 5, ms; "blocked" is the time
/// `Isolate.run` keeps the calling isolate busy spawning and copying the
/// bindings):
///
///     N      in-isolate  Isolate.run  blocked   (JIT, dart run)
///     500    0.10        0.45         0.11
///     1000   0.15        0.71         0.22
///     2000   0.30        0.95         0.40
///     5000   1.33        2.89         1.51
///     10000  2.00        6.07         3.86
///
/// AOT (`dart compile exe`) gave the same shape (10000: 1.56 / 4.47 / 2.33),
/// and 20000 to 100000 entries widened the gap (100000: 28.9 / 183.9 /
/// 126.0). There is no crossover: copying the bindings maps costs the
/// caller more than evaluating them (about 0.2 us per entry), so
/// `Isolate.run` never relieves the calling isolate for map-shaped
/// bindings. The design's 2000 is raised to 10000, the largest measured
/// size, below which every batch is cheapest where it is (at most a few
/// milliseconds); the isolate path only pays off once bindings cross the
/// isolate boundary in a cheaper form than maps.
const int isolateThreshold = 10000;

/// Evaluates [formula] once per entry of [bindingsList], parsing it once.
/// The results are in [bindingsList] order and equal what [evaluateFormula]
/// returns for each entry. Batches of at least [threshold] entries run in
/// `Isolate.run`; a formula that does not parse never spawns an isolate.
Future<List<FormulaEvalResult>> evaluateBatch(
  String formula,
  List<Map<String, double>> bindingsList, {
  int threshold = isolateThreshold,
}) => evaluateAnalysisBatch(
  analyzeFormula(formula),
  bindingsList,
  threshold: threshold,
);

@internal
Future<List<FormulaEvalResult>> evaluateAnalysisBatch(
  FormulaAnalysis analysis,
  List<Map<String, double>> bindingsList, {
  int threshold = isolateThreshold,
}) async {
  final failed = failedAnalysisResult(analysis);
  if (failed != null) return List.filled(bindingsList.length, failed);
  final ast = (analysis as ParsedFormula).ast;
  if (bindingsList.length < threshold) return _evaluateAll(ast, bindingsList);
  return _evaluateAllInIsolate(ast, bindingsList);
}

// A separate function so the closure sent to the isolate captures only the
// tree and the bindings.
Future<List<FormulaEvalResult>> _evaluateAllInIsolate(
  FormulaExpr ast,
  List<Map<String, double>> bindingsList,
) => Isolate.run(() => _evaluateAll(ast, bindingsList));

List<FormulaEvalResult> _evaluateAll(
  FormulaExpr ast,
  List<Map<String, double>> bindingsList,
) => [for (final bindings in bindingsList) evaluateAst(ast, bindings)];
