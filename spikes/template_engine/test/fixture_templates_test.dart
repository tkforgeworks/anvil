// The three templates captured from Electron 0.1.6, byte for byte.
import 'dart:convert';

import 'package:jinja/jinja.dart';
import 'package:template_engine/template_engine.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  final context = fullContext();
  const templates = ['guide', 'recipe-book', 'beyond-guide'];
  String source(String name) => readFixture('template-$name.njk');
  String expected(String name) => readFixture('template-$name.expected.txt');

  final engines = <String, RenderFn>{
    'option 1: jinja 0.7.2 (Anvil-tuned)': JinjaRenderer().render,
    'option 2: purpose-built subset renderer': renderAnvilTemplate,
  };
  for (final MapEntry(key: engine, value: render) in engines.entries) {
    group(engine, () {
      for (final name in templates) {
        test('$name is byte-identical', () {
          expectSameBytes(render(source(name), context), expected(name));
        });
      }
    });
  }

  group('jinja with Dart toString output (jsOutput: false)', () {
    final render = JinjaRenderer(jsOutput: false).render;
    test('guide and recipe-book are byte-identical', () {
      for (final name in ['guide', 'recipe-book']) {
        expectSameBytes(render(source(name), context), expected(name));
      }
    });
    // Accepted, documented difference: `{{ (1.5 + 1.5) }}` prints Dart's
    // `3.0` where JavaScript printed `3`. It is the only difference.
    test('beyond-guide differs only by 3 -> 3.0', () {
      final actual = render(source('beyond-guide'), context);
      expect(actual, isNot(expected('beyond-guide')));
      expect(
        actual,
        expected('beyond-guide').replaceFirst(' 3 1-2-3', ' 3.0 1-2-3'),
      );
    });
  });

  // Baseline: jinja defaults plus the most direct Dart filters. Documented,
  // accepted differences that show why the tuned configuration exists.
  group('jinja defaults with a dart:convert json filter', () {
    String render(String source) {
      final env = Environment(
        filters: {
          'json': (Object? v, [int indent = 2]) =>
              JsonEncoder.withIndent(' ' * indent).convert(v),
          'export_key': (Object? id) => anvilExportKey(context, id),
        },
      );
      return env.fromString(source).render({...context, 'ctx': context});
    }

    test('guide is byte-identical', () {
      expectSameBytes(render(source('guide')), expected('guide'));
    });
    test('recipe-book differs only in json(0), which is not compact', () {
      final actual = render(source('recipe-book'));
      final cut = expected('recipe-book').indexOf('COMPACT\n') + 8;
      expect(
        actual.substring(0, cut),
        expected('recipe-book').substring(0, cut),
      );
      expect(
        actual.substring(cut),
        const JsonEncoder.withIndent('')
            .convert((context['meta'] as Map<String, Object?>)['rarities']),
      );
    });
    test('beyond-guide fails: jinja has no dump filter', () {
      expect(
        () => render(source('beyond-guide')),
        throwsA(isA<TemplateRuntimeError>()),
      );
    });
  });

  test('the subset renderer parses all three without rendering', () {
    for (final name in templates) {
      expect(AnvilTemplate.check(source(name)), isNull, reason: name);
    }
  });
}
