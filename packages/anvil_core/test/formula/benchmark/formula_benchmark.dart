// Benchmark behind `isolateThreshold` (lib/src/formula/formula_batch.dart).
// Not a test. Run from the repo root:
//
//     fvm dart run packages/anvil_core/test/formula/benchmark/formula_benchmark.dart
//
// For each batch size N it times evaluateBatch on the calling isolate and
// via Isolate.run (5 repetitions after a warm-up, median, wall clock), with
// a realistic stat-growth formula and nine bindings per level. "blocked" is
// the part of the Isolate.run path that runs synchronously on the calling
// isolate (spawning and copying the bindings across), which is what the UI
// isolate pays; the rest of Isolate.run's wall time is spent elsewhere.
import 'dart:io';

import 'package:anvil_core/anvil_core.dart';

const _formula = 'floor(base_hp + level * hp_growth + max(1, strength * 0.5))';
const _sizes = [500, 1000, 2000, 5000, 10000];
const _repetitions = 5;

List<Map<String, double>> _bindings(int n) => [
  for (var level = 1; level <= n; level++)
    {
      'level': level.toDouble(),
      'max_level': n.toDouble(),
      'base_hp': 50,
      'hp_growth': 7.3,
      'strength': 10 + level * 0.25,
      'agility': 8,
      'intelligence': 12,
      'constitution': 9,
      'resource_multiplier': 1.1,
    },
];

Future<double> _medianMicros(Future<void> Function() run) async {
  final samples = <int>[];
  for (var i = 0; i < _repetitions; i++) {
    final sw = Stopwatch()..start();
    await run();
    samples.add(sw.elapsedMicroseconds);
  }
  samples.sort();
  return samples[samples.length ~/ 2].toDouble();
}

/// Median microseconds the calling isolate is busy before Isolate.run
/// hands control back (spawn plus copying the message).
Future<double> _medianBlockedMicros(List<Map<String, double>> bindings) async {
  final samples = <int>[];
  for (var i = 0; i < _repetitions; i++) {
    final sw = Stopwatch()..start();
    final pending = evaluateBatch(_formula, bindings, threshold: 0);
    samples.add(sw.elapsedMicroseconds);
    await pending;
  }
  samples.sort();
  return samples[samples.length ~/ 2].toDouble();
}

Future<void> main() async {
  // Warm up both paths so the JIT has compiled the evaluator.
  for (var i = 0; i < 3; i++) {
    await evaluateBatch(_formula, _bindings(10000), threshold: 1 << 30);
    await evaluateBatch(_formula, _bindings(500), threshold: 0);
  }

  stdout.writeln('formula: $_formula');
  stdout.writeln('median of $_repetitions, milliseconds');
  stdout.writeln(
    '${'N'.padLeft(6)} | in-isolate | Isolate.run | blocked | per eval (us)',
  );
  int? crossover;
  for (final n in _sizes) {
    final bindings = _bindings(n);
    final inIsolate = await _medianMicros(
      () => evaluateBatch(_formula, bindings, threshold: 1 << 30),
    );
    final viaIsolate = await _medianMicros(
      () => evaluateBatch(_formula, bindings, threshold: 0),
    );
    final blocked = await _medianBlockedMicros(bindings);
    stdout.writeln(
      '${'$n'.padLeft(6)} | '
      '${(inIsolate / 1000).toStringAsFixed(2).padLeft(10)} | '
      '${(viaIsolate / 1000).toStringAsFixed(2).padLeft(11)} | '
      '${(blocked / 1000).toStringAsFixed(2).padLeft(7)} | '
      '${(inIsolate / n).toStringAsFixed(3).padLeft(8)}',
    );
    if (crossover == null && blocked < inIsolate) crossover = n;
  }
  // The crossover is the first N at which Isolate.run costs the calling
  // isolate less than evaluating the batch on it.
  stdout.writeln(
    crossover == null
        ? 'crossover: none up to ${_sizes.last} (Isolate.run never cheaper)'
        : 'crossover: N = $crossover',
  );
}
