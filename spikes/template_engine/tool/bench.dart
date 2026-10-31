// Rough throughput of the two Dart engines on the fixture templates over a
// context scaled up 200x (1000 items, 400 recipes, 400 classes, ...).
//   dart run tool/bench.dart
import 'dart:convert';
import 'dart:io';

import 'package:template_engine/template_engine.dart';

Map<String, Object?> scaled(Map<String, Object?> ctx, int factor) {
  final out = <String, Object?>{...ctx};
  for (final d in exportKeyDomains) {
    final records = (ctx[d] as List).cast<Map<String, Object?>>();
    out[d] = [
      for (var i = 0; i < factor; i++)
        for (final r in records) {...r, 'id': '${r['id']}-$i'},
    ];
  }
  return out;
}

void main() {
  final base = jsonDecode(
    File('test/fixtures/context-full.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final ctx = scaled(base, 200);
  for (final name in ['guide', 'recipe-book']) {
    final src = File('test/fixtures/template-$name.njk').readAsStringSync();
    for (final (engine, render) in <(String, RenderFn)>[
      ('jinja', JinjaRenderer().render),
      ('subset', renderAnvilTemplate),
    ]) {
      render(src, ctx); // warm up
      final sw = Stopwatch()..start();
      var chars = 0;
      for (var i = 0; i < 5; i++) {
        chars = render(src, ctx).length;
      }
      print(
        '$name x200 [$engine]: ${(sw.elapsedMilliseconds / 5).toStringAsFixed(1)}'
        ' ms/render, $chars chars',
      );
    }
  }
}
