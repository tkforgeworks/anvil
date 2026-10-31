// What a user template can reach and what it can cost, per option.
// Sizes are chosen to show the behaviour without stressing the machine.
import 'dart:async';

import 'package:jinja/jinja.dart';
import 'package:template_engine/template_engine.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  final context = fullContext();

  String nestedLoops(int depth, [String body = '']) {
    var s = body;
    for (var i = 0; i < depth; i++) {
      s = '{% for x$i in classes[0].stat_growth %}$s{% endfor %}';
    }
    return s; // stat_growth has 40 rows: 40^depth iterations
  }

  Matcher templateError(TemplateErrorKind kind) =>
      isA<AnvilTemplateError>().having((e) => e.kind, 'kind', kind);

  group('option 2: subset renderer is sandboxed by construction', () {
    String render(String s, [RenderLimits l = const RenderLimits()]) =>
        AnvilTemplate.parse(s).render(context, limits: l);

    test('no host access: calls, includes and prototype walks fail', () {
      expect(
        () => render("{{ ''.constructor.constructor('return 1')() }}"),
        throwsA(templateError(TemplateErrorKind.unsupported)),
      );
      for (final s in [
        "{% include '/etc/passwd' %}",
        "{% import 'x' as y %}",
        '{{ range(10) }}',
        '{% macro f() %}{% endmacro %}',
      ]) {
        expect(
          () => render(s),
          throwsA(templateError(TemplateErrorKind.unsupported)),
          reason: s,
        );
      }
      // Lookups only see the export context: JS-style prototype names are
      // simply undefined.
      for (final s in [
        "{{ ''.constructor }}",
        '{{ project.__proto__ }}',
        '{{ items.map }}',
      ]) {
        expect(
          () => render(s),
          throwsA(templateError(TemplateErrorKind.render)),
          reason: s,
        );
      }
    });

    test('runaway loops stop at the iteration limit', () {
      final sw = Stopwatch()..start();
      expect(
        () => render(nestedLoops(6)), // 4.1e9 iterations
        throwsA(templateError(TemplateErrorKind.limit)),
      );
      print('40^6 nested loops aborted after ${sw.elapsedMilliseconds}ms');
      expect(sw.elapsed, lessThan(const Duration(seconds: 30)));
      expect(render(nestedLoops(3)), ''); // 64k iterations are fine
    });

    test('string doubling and output floods stop at the size limits', () {
      expect(
        () => render(
          "{% set s = 'x' %}{% for g in classes[0].stat_growth %}"
          '{% set s = s ~ s %}{% endfor %}{{ s | length }}',
        ),
        throwsA(templateError(TemplateErrorKind.limit)),
      );
      expect(
        () => render(
          nestedLoops(3, '{{ classes | json }}'),
          const RenderLimits(maxOutputChars: 1 << 20),
        ),
        throwsA(templateError(TemplateErrorKind.limit)),
      );
    });

    test('deep nesting is a limit error, not a stack overflow', () {
      expect(
        () => render('{{ ${'(' * 10000}1${')' * 10000} }}'),
        throwsA(templateError(TemplateErrorKind.limit)),
      );
      expect(
        () => render('${'{% if true %}' * 1000}x${'{% endif %}' * 1000}'),
        throwsA(templateError(TemplateErrorKind.limit)),
      );
    });
  });

  group('option 1: jinja 0.7.2', () {
    final stock = Environment();
    String renderStock(String s) =>
        stock.fromString(s).render({...context, 'ctx': context});
    String renderTuned(String s) => JinjaRenderer().render(s, context);

    test('no file or network access without a loader', () {
      for (final render in [renderStock, renderTuned]) {
        expect(() => render("{% include '/etc/passwd' %}"), throwsStateError);
      }
    });

    test('no Dart member access without dart:mirrors reflection', () {
      for (final s in [
        "{{ 'abc'.toUpperCase() }}",
        '{{ items.add(1) }}',
        '{{ project.clear() }}',
      ]) {
        expect(() => renderStock(s), throwsA(anything), reason: s);
        expect(() => renderTuned(s), throwsA(anything), reason: s);
      }
      // The stock runtimetype filter reveals Dart type names (harmless).
      expect(renderStock("{{ '' | runtimetype }}"), 'String');
    });

    test('stock globals include print, which writes to the app stdout', () {
      final printed = <String>[];
      runZoned(
        () => renderStock("{{ print('from a template') }}"),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => printed.add(line),
        ),
      );
      expect(printed, ['from a template']);
      expect(() => renderTuned("{{ print('x') }}"), throwsA(anything));
    });

    test('allocation is unbounded: one expression builds a 50 MB string', () {
      // `'x' * 10000000000` would try to allocate 10 GB and can take the
      // process down; isolates share a heap, so a timeout cannot help.
      final sw = Stopwatch()..start();
      expect(renderTuned("{{ ('x' * 50000000) | length }}"), '50000000');
      print('50 MB string in ${sw.elapsedMilliseconds}ms');
    });

    test('range() materialises its list; the tuned config caps it', () {
      expect(renderTuned('{{ range(3) | join }}'), '012');
      expect(
        () => renderTuned('{% for i in range(100000000) %}{% endfor %}'),
        throwsA(isA<TemplateRuntimeError>()),
      );
      // Stock: range(200000) is accepted and costs ~0.5 s; range(1e7) ~27 s.
      final sw = Stopwatch()..start();
      expect(renderStock('{% for i in range(200000) %}{% endfor %}ok'), 'ok');
      print('stock range(200000) loop: ${sw.elapsedMilliseconds}ms');
    });

    test('unbounded recursion ends in a catchable StackOverflowError', () {
      for (final s in [
        '{% macro f(n) %}{{ f(n + 1) }}{% endmacro %}{{ f(0) }}',
        '{% for x in items recursive %}{{ loop(items) }}{% endfor %}',
      ]) {
        expect(
          () => renderTuned(s),
          throwsA(isA<StackOverflowError>()),
          reason: s,
        );
      }
    });
  });

  group('mitigation: render in an isolate and kill it on timeout', () {
    test('a 2^28-call macro (minutes of CPU in jinja) is killed', () async {
      final sw = Stopwatch()..start();
      await expectLater(
        renderIsolated(
          Engine.jinja,
          '{% macro f(n) %}{% if n > 0 %}{{ f(n - 1) }}{{ f(n - 1) }}'
          '{% endif %}{% endmacro %}{{ f(28) }}',
          context,
          timeout: const Duration(seconds: 1),
        ),
        throwsA(isA<RenderTimeout>()),
      );
      print('killed after ${sw.elapsedMilliseconds}ms');
      expect(sw.elapsed, lessThan(const Duration(seconds: 10)));
    });

    test('nested loops in jinja (no iteration cap) are killed too', () async {
      await expectLater(
        renderIsolated(
          Engine.jinja,
          nestedLoops(6),
          context,
          timeout: const Duration(seconds: 1),
        ),
        throwsA(isA<RenderTimeout>()),
      );
    });

    test('normal renders round-trip through the isolate', () async {
      final source = readFixture('template-recipe-book.njk');
      final expected = readFixture('template-recipe-book.expected.txt');
      for (final engine in Engine.values) {
        expectSameBytes(
          await renderIsolated(engine, source, context),
          expected,
        );
      }
    });
  });
}
