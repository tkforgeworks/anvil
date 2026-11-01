// The three custom templates of sample-0.1.6.anvil, byte for byte against
// what Electron 0.1.6 rendered (test/fixtures/template-*.expected.txt).
import 'package:anvil_core/anvil_core.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  final context = fullContext();
  const templates = ['guide', 'recipe-book', 'beyond-guide'];
  String source(String name) => readFixture('template-$name.njk');
  String expected(String name) => readFixture('template-$name.expected.txt');

  for (final name in templates) {
    test('$name is byte-identical', () {
      expectSameBytes(
        AnvilTemplate.parse(source(name)).render(context),
        expected(name),
      );
    });
    test('$name passes checkTemplate', () {
      expect(checkTemplate(source(name)), isNull);
    });
  }

  test('a parsed template renders the same twice', () {
    final template = AnvilTemplate.parse(source('recipe-book'));
    expect(template.render(context), template.render(context));
  });

  group('export_key keeps the 0.1.6 lookup', () {
    String render(String s, Map<String, Object?> ctx) =>
        AnvilTemplate.parse(s).render(ctx);
    final ctx = <String, Object?>{
      'classes': [
        {'id': 'dup', 'export_key': 'first'},
      ],
      'abilities': [
        {'id': 'dup', 'export_key': 'second'},
        {'id': 7, 'export_key': 'seven'},
        {'id': 'no-key'},
      ],
      'items': <Object?>[],
      'recipes': <Object?>[],
      'npcs': <Object?>[],
      'loot_tables': <Object?>[],
      'meta': {
        'rarities': [
          {'id': 'rarity-common', 'export_key': 'common'},
        ],
      },
    };

    test('the first domain in 0.1.6 order wins', () {
      expect(render("{{ 'dup' | export_key }}", ctx), 'first');
    });
    test('ids compare with ===', () {
      expect(
        render('{{ 7 | export_key }} {{ 7.0 | export_key }}', ctx),
        'seven seven',
      );
      expect(render("{{ '7' | export_key }}", ctx), '7');
    });
    test('meta ids and unknown ids come back unchanged', () {
      expect(
        render("{{ 'rarity-common' | export_key }}", ctx),
        'rarity-common',
      );
      expect(render("{{ 'nope' | export_key }}", ctx), 'nope');
    });
    test('a record without export_key outputs undefined, which throws', () {
      expect(
        () => render("{{ 'no-key' | export_key }}", ctx),
        throwsA(isA<AnvilTemplateError>()),
      );
    });
  });
}
