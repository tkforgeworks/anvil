// Prints how an engine scores against the Nunjucks parity corpus.
//   dart run tool/score_corpus.dart [jinja|jinja-dart-output|jinja-strict|subset]
import 'dart:convert';
import 'dart:io';

import 'package:template_engine/template_engine.dart';

void main(List<String> args) {
  const dir = 'test/fixtures';
  final ctx = jsonDecode(
    File('$dir/context-full.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final corpus = jsonDecode(
    File('$dir/nunjucks-parity.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final engine = args.isEmpty ? 'jinja' : args.first;
  final RenderFn render = switch (engine) {
    'jinja' => JinjaRenderer().render,
    'jinja-dart-output' => JinjaRenderer(jsOutput: false).render,
    'jinja-strict' => JinjaRenderer(
      undefinedMode: JinjaUndefinedMode.throwOnReference,
    ).render,
    'subset' => renderAnvilTemplate,
    _ => throw ArgumentError(engine),
  };
  print(summarise(scoreCorpus(corpus, ctx, render)));
}
