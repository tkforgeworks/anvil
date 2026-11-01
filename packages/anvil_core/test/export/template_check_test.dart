// checkTemplate: parse-only detection of stored templates Anvil 0.2 cannot
// render, with the position for the warning (design §11.5).
import 'package:anvil_core/anvil_core.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  test('null for supported templates', () {
    for (final s in [
      '',
      'plain text',
      readFixture('template-guide.njk'),
      '{% for k, v in items[0].custom_fields %}{{ k }}={{ v }}{% endfor %}',
      '{% if a %}1{% elif b %}2{% elseif c %}3{% else %}4{% endif %}',
      "{{ items | join(', ', 'export_key') | upper }}",
    ]) {
      expect(checkTemplate(s), isNull, reason: s);
    }
  });

  test('checking does not render: an undefined output is not an error', () {
    expect(checkTemplate('{{ nope.deeper }}'), isNull);
    expect(checkTemplate('{% for x in nope %}{{ x }}{% endfor %}'), isNull);
  });

  test('unsupported features carry their 1-based line and column', () {
    expect(
      checkTemplate('Header\n\n  {% macro row(x) %}{% endmacro %}'),
      const TemplateCheck(
        TemplateErrorKind.unsupported,
        "the 'macro' tag is not supported",
        3,
        6,
      ),
    );
    expect(
      checkTemplate('{{ items | sort }}'),
      const TemplateCheck(
        TemplateErrorKind.unsupported,
        "the 'sort' filter is not supported",
        1,
        12,
      ),
    );
    final call = checkTemplate('a\n{{ range(3) }}')!;
    expect(call.kind, TemplateErrorKind.unsupported);
    expect((call.line, call.column), (2, 9));
    final test = checkTemplate('{% if x is defined %}{% endif %}')!;
    expect(test.kind, TemplateErrorKind.unsupported);
    expect((test.line, test.column), (1, 9));
  });

  test('syntax errors are reported as syntax, with a position', () {
    for (final s in ['{% for x in items %}', '{{ "open }}', '{% endif %}']) {
      final check = checkTemplate(s);
      expect(check?.kind, TemplateErrorKind.syntax, reason: s);
      expect(check!.line, greaterThanOrEqualTo(1));
      expect(check.column, greaterThanOrEqualTo(1));
    }
  });

  test('nesting deeper than the limit is a limit finding', () {
    final check = checkTemplate(
      '{{ ${'(' * 30}1${')' * 30} }}',
      limits: const RenderLimits(maxNesting: 10),
    );
    expect(check?.kind, TemplateErrorKind.limit);
    expect(check!.line, 1);
  });

  test('render errors carry the position of the failing expression', () {
    final template = AnvilTemplate.parse('line one\n  {{ items | join }}');
    expect(
      () => template.render({'items': 'not a list'}),
      throwsA(
        isA<AnvilTemplateError>()
            .having((e) => e.kind, 'kind', TemplateErrorKind.render)
            .having((e) => (e.line, e.column), 'position', (2, 14)),
      ),
    );
  });
}
