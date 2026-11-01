// What a template can reach and what it can cost (design §11.4). The limit
// tests use small limits so they finish in milliseconds; the shipping
// defaults are only asserted, not exercised.
import 'package:anvil_core/anvil_core.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  final context = fullContext();

  /// `classes[0].stat_growth` has 40 rows: 40^depth iterations.
  String nestedLoops(int depth, [String body = '']) {
    var s = body;
    for (var i = 0; i < depth; i++) {
      s = '{% for x$i in classes[0].stat_growth %}$s{% endfor %}';
    }
    return s;
  }

  String render(String s, [RenderLimits limits = const RenderLimits()]) =>
      AnvilTemplate.parse(s, limits: limits).render(context, limits: limits);

  TypeMatcher<AnvilTemplateError> templateError(TemplateErrorKind kind) =>
      isA<AnvilTemplateError>()
          .having((e) => e.kind, 'kind', kind)
          .having((e) => e.line, 'line', isNotNull)
          .having((e) => e.column, 'column', isNotNull);

  test('the defaults are the design §11.4 limits', () {
    const limits = RenderLimits();
    expect(limits.maxIterations, 5000000);
    expect(limits.maxOutputChars, 33554432);
    expect(limits.maxWorkChars, 268435456);
    expect(limits.maxNesting, 200);
  });

  group('no host access', () {
    test("''.constructor and other prototype names are just undefined", () {
      for (final s in [
        "{{ ''.constructor }}",
        "{{ ''.constructor.constructor }}",
        '{{ project.__proto__ }}',
        '{{ items.map }}',
        '{{ ctx.constructor }}',
      ]) {
        expect(
          () => render(s),
          throwsA(
            templateError(TemplateErrorKind.render).having(
              (e) => e.message,
              'message',
              'attempted to output null or undefined value',
            ),
          ),
          reason: s,
        );
      }
      expect(render("{% if ''.constructor %}yes{% else %}no{% endif %}"), 'no');
    });

    test('the 0.1.6 escape is a parse-time unsupported error', () {
      expect(
        () => render(
          "{{ ''.constructor.constructor('return process.platform')() }}",
        ),
        throwsA(templateError(TemplateErrorKind.unsupported)),
      );
    });

    test('includes, imports, macros and function calls are unsupported', () {
      for (final s in [
        "{% include '/etc/passwd' %}",
        "{% import 'x' as y %}",
        "{% extends 'base.njk' %}",
        '{{ range(10) }}',
        '{% macro f() %}{% endmacro %}',
        "{{ 'abc'.toUpperCase() }}",
      ]) {
        expect(
          () => render(s),
          throwsA(templateError(TemplateErrorKind.unsupported)),
          reason: s,
        );
      }
    });
  });

  group('limits', () {
    test('loop iterations', () {
      const limits = RenderLimits(maxIterations: 1000);
      expect(render(nestedLoops(1), limits), ''); // 40 iterations
      expect(
        () => render(nestedLoops(3), limits), // 64,000 iterations
        throwsA(templateError(TemplateErrorKind.limit)),
      );
    });

    test('characters per output or intermediate string', () {
      const limits = RenderLimits(maxOutputChars: 4096);
      // Doubling a string 40 times: an intermediate string trips it.
      expect(
        () => render(
          "{% set s = 'x' %}{% for g in classes[0].stat_growth %}"
          '{% set s = s ~ s %}{% endfor %}{{ s | length }}',
          limits,
        ),
        throwsA(templateError(TemplateErrorKind.limit)),
      );
      // Many small writes: the output trips it.
      expect(
        () => render(nestedLoops(2, '{{ project.name }}'), limits),
        throwsA(templateError(TemplateErrorKind.limit)),
      );
    });

    test('total characters of string work', () {
      const limits = RenderLimits(maxWorkChars: 10000);
      // Each concatenation is small and nothing is output, but 1,600 of
      // them add up.
      const source =
          '{% for a in classes[0].stat_growth %}'
          '{% for b in classes[0].stat_growth %}'
          "{% set s = 'abcdef' ~ 'ghij' %}"
          '{% endfor %}{% endfor %}';
      expect(render(source), '');
      expect(
        () => render(source, limits),
        throwsA(templateError(TemplateErrorKind.limit)),
      );
    });

    test('parser nesting, without a stack overflow', () {
      const limits = RenderLimits(maxNesting: 20);
      expect(render('{{ ${'(' * 5}1${')' * 5} }}', limits), '1');
      for (final s in [
        '{{ ${'(' * 50}1${')' * 50} }}',
        '${'{% if true %}' * 50}x${'{% endif %}' * 50}',
        '{{ ${'not ' * 50}true }}',
        '{{ ${'[' * 50}1${']' * 50} }}',
      ]) {
        expect(
          () => render(s, limits),
          throwsA(templateError(TemplateErrorKind.limit)),
          reason: s.substring(0, 20),
        );
      }
      // Long operator chains are flat in the source but deep as a tree.
      expect(render('{{ ${List.filled(15, '1').join(' + ')} }}', limits), '15');
      for (final op in [' + ', ' ~ ', ' and ', ' < ', ' ** ', ' in ']) {
        expect(
          () => render('{{ ${List.filled(10000, '1').join(op)} }}'),
          throwsA(templateError(TemplateErrorKind.limit)),
          reason: op,
        );
      }
      expect(
        () => render("{{ 'a'${' | upper' * 10000} }}"),
        throwsA(templateError(TemplateErrorKind.limit)),
      );
      expect(
        () => render('{{ project${'.x' * 10000} }}'),
        throwsA(templateError(TemplateErrorKind.limit)),
      );
      // The default cap stops a 10,000-deep expression at parse time.
      expect(
        () => render('{{ ${'(' * 10000}1${')' * 10000} }}'),
        throwsA(templateError(TemplateErrorKind.limit)),
      );
    });
  });

  group('render isolate', () {
    test('renders a fixture template off the calling isolate', () async {
      expectSameBytes(
        await renderTemplateIsolated(
          readFixture('template-recipe-book.njk'),
          context,
        ),
        readFixture('template-recipe-book.expected.txt'),
      );
    });

    test('passes template errors through unchanged', () async {
      await expectLater(
        renderTemplateIsolated('{{ nope }}', context),
        throwsA(templateError(TemplateErrorKind.render)),
      );
      await expectLater(
        renderTemplateIsolated('{% macro f() %}{% endmacro %}', context),
        throwsA(templateError(TemplateErrorKind.unsupported)),
      );
      await expectLater(
        renderTemplateIsolated(
          nestedLoops(3),
          context,
          limits: const RenderLimits(maxIterations: 100),
        ),
        throwsA(templateError(TemplateErrorKind.limit)),
      );
    });

    test('kills a render that outlives its timeout', () async {
      // 40^6 iterations with the iteration cap lifted: minutes of CPU.
      final sw = Stopwatch()..start();
      await expectLater(
        renderTemplateIsolated(
          nestedLoops(6),
          context,
          limits: const RenderLimits(maxIterations: 1 << 62),
          timeout: const Duration(milliseconds: 300),
        ),
        throwsA(isA<RenderTimeout>()),
      );
      expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
    });
  });
}
