// What a hostile template can reach or cost in
// the jinja package, with timings. Sizes are kept small enough to be safe.
import 'dart:convert';
import 'dart:io';

import 'package:jinja/jinja.dart';
import 'package:template_engine/template_engine.dart';

void main() {
  final ctx = jsonDecode(
    File('test/fixtures/context-full.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final stock = Environment();
  final probes = <String, String>{
    'runtimeType attr': "{{ ''.runtimeType }}",
    'runtimetype filter': "{{ '' | runtimetype }} {{ items | runtimetype }}",
    'string method': "{{ 'abc'.toUpperCase() }}",
    'list method': '{{ items.add(1) }}',
    'map method': '{{ project.clear() }}',
    'globals': '{{ range }} | {{ namespace }} | {{ list }}',
    'print global': "{{ print('printed-from-template') }}",
    'include': "{% include '/etc/passwd' %}",
    'import': "{% import 'x' as y %}",
    'range 1e6 loop': '{% for i in range(1000000) %}{% endfor %}done',
    'range 1e7 loop': '{% for i in range(10000000) %}{% endfor %}done',
    'string repeat 1e8': "{{ ('x' * 100000000) | length }}",
    'center 1e7': "{{ ('x' | center(10000000)) | length }}",
    'macro recursion': '{% macro f(n) %}{{ f(n + 1) }}{% endmacro %}{{ f(0) }}',
    'macro 2^16 calls': '{% macro f(n) %}{% if n > 0 %}{{ f(n - 1) }}{{ f(n - 1) }}{% endif %}{% endmacro %}{{ f(16) }}done',
    'macro 2^20 calls': '{% macro f(n) %}{% if n > 0 %}{{ f(n - 1) }}{{ f(n - 1) }}{% endif %}{% endmacro %}{{ f(20) }}done',
    'recursive loop':
        '{% for x in items recursive %}{{ loop(items) }}{% endfor %}',
    'nested loops 40^4': '{% for a in classes[0].stat_growth %}{% for b in classes[0].stat_growth %}{% for c in classes[0].stat_growth %}{% for d in classes[0].stat_growth %}{% endfor %}{% endfor %}{% endfor %}{% endfor %}done',
  };
  for (final MapEntry(:key, :value) in probes.entries) {
    for (final (label, render) in [
      ('stock', (String s) => stock.fromString(s).render({...ctx, 'ctx': ctx})),
      ('tuned', (String s) => JinjaRenderer().render(s, ctx)),
    ]) {
      final sw = Stopwatch()..start();
      String result;
      try {
        final out = render(value);
        result = 'OK "${out.length > 80 ? '${out.substring(0, 80)}...' : out}"';
      } catch (e) {
        result = 'THREW ${e.runtimeType}: ${'$e'.split('\n').first}';
      }
      print('$key [$label] ${sw.elapsedMilliseconds}ms $result');
    }
  }
}
