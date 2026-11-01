/// Scores a renderer against the Nunjucks parity corpus
/// (test/fixtures/export/nunjucks-parity.json, produced by
/// test/fixtures/export/tool/nunjucks_oracle.js).
library;

import 'text_diff.dart';

typedef RenderFn = String Function(String source, Map<String, Object?> context);

enum Verdict {
  /// Same output, or both rejected the template.
  match,

  /// Both rendered, outputs differ.
  outputDiffers,

  /// Nunjucks rendered it; the engine threw.
  engineRejects,

  /// Nunjucks threw; the engine rendered something.
  engineAccepts,
}

final class CaseResult {
  CaseResult(this.name, this.verdict, this.detail);
  final String name;
  final Verdict verdict;
  final String detail;
}

List<CaseResult> scoreCorpus(
  Map<String, Object?> corpus,
  Map<String, Object?> context,
  RenderFn render,
) {
  final results = <CaseResult>[];
  for (final MapEntry(:key, :value) in corpus.entries) {
    final c = value as Map<String, Object?>;
    final source = c['source'] as String;
    final nunjucksOk = c['ok'] as bool;
    String? output;
    Object? error;
    try {
      output = render(source, context);
    } catch (e) {
      error = e;
    }
    if (nunjucksOk && output != null) {
      final expected = c['output'] as String;
      final diff = describeDifference(expected, output, maxLines: 6);
      results.add(
        CaseResult(
          key,
          diff == null ? Verdict.match : Verdict.outputDiffers,
          diff == null ? '' : 'expected ${_q(expected)} got ${_q(output)}',
        ),
      );
    } else if (nunjucksOk) {
      results.add(
        CaseResult(key, Verdict.engineRejects, '${error.runtimeType}: $error'),
      );
    } else if (output != null) {
      results.add(
        CaseResult(
          key,
          Verdict.engineAccepts,
          'Nunjucks: ${c['error']}; engine printed ${_q(output)}',
        ),
      );
    } else {
      results.add(CaseResult(key, Verdict.match, 'both reject'));
    }
  }
  return results;
}

String _q(String s) {
  final v = s.replaceAll('\n', r'\n').replaceAll('\r', r'\r');
  return '"${v.length > 120 ? '${v.substring(0, 120)}...' : v}"';
}

/// A one-line-per-case summary of everything that is not a match.
String summarise(List<CaseResult> results) {
  final out = StringBuffer();
  for (final group in ['guide.', 'idiom.', 'edge.', 'host.']) {
    final g = results.where((r) => r.name.startsWith(group)).toList();
    final m = g.where((r) => r.verdict == Verdict.match).length;
    out.writeln('$group* ${g.length} cases: $m match');
  }
  for (final r in results.where((r) => r.verdict != Verdict.match)) {
    out.writeln('  ${r.name} [${r.verdict.name}] ${r.detail}');
  }
  return out.toString();
}
