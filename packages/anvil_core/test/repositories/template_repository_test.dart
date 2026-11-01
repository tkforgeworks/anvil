import 'package:anvil_core/anvil_core.dart';
import 'package:test/test.dart';

import '../db/support/fixture_copy.dart';
import '../export/support/fixtures.dart' show readFixture;

final RegExp _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

/// 0.1.6 `new Date().toISOString()`.
final RegExp _jsIso = RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$');

/// SQLite `datetime('now')`.
final RegExp _sqliteNow = RegExp(r'^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$');

const String _seeded = '2026-10-31 20:58:16';

void main() {
  final copy = FixtureCopy.setUpEach();

  late ProjectDatabase db;
  late TemplateRepository repo;
  setUp(() {
    db = copy().openFixture();
    repo = SqliteTemplateRepository(db);
  });

  /// The save_history descriptions, oldest first.
  List<String> history() => [
    // ignore: invalid_use_of_internal_member
    for (final r in db.handle.select(
      'SELECT description FROM save_history ORDER BY id',
    ))
      r['description'] as String,
  ];

  final fixtureTemplates = [
    CustomTemplate(
      id: 'tpl-beyond',
      name: 'Beyond the guide',
      description: 'Nunjucks idioms outside the documented subset',
      templateSource: readFixture('template-beyond-guide.njk'),
      format: 'text',
      createdAt: _seeded,
      updatedAt: _seeded,
    ),
    CustomTemplate(
      id: 'tpl-guide',
      name: 'Items (guide example)',
      description: 'The example from the writing guide',
      templateSource: readFixture('template-guide.njk'),
      format: 'text',
      createdAt: _seeded,
      updatedAt: _seeded,
    ),
    CustomTemplate(
      id: 'tpl-recipe-book',
      name: 'Recipe Book',
      description: 'Nested loops, set, json filter',
      templateSource: readFixture('template-recipe-book.njk'),
      format: 'text',
      createdAt: _seeded,
      updatedAt: _seeded,
    ),
  ];

  test('list returns the fixture templates by name, field by field', () async {
    expect(await repo.list(), fixtureTemplates);
  });

  test('list orders by name ignoring case', () async {
    await repo.create(
      const CreateTemplateInput(name: 'alpha', templateSource: 'a'),
    );
    await repo.create(
      const CreateTemplateInput(name: 'Zulu', templateSource: 'z'),
    );
    expect((await repo.list()).map((t) => t.name), [
      'alpha',
      'Beyond the guide',
      'Items (guide example)',
      'Recipe Book',
      'Zulu',
    ]);
  });

  test('get returns one template', () async {
    expect(await repo.get('tpl-guide'), fixtureTemplates[1]);
  });

  test(
    'create stores the input with 0.1.6 defaults and one history row',
    () async {
      final before = history();
      final t = await repo.create(
        const CreateTemplateInput(name: 'Sheet', templateSource: '{{ x }}'),
      );
      expect(t.id, matches(_uuidV4));
      expect(t.name, 'Sheet');
      expect(t.description, '');
      expect(t.templateSource, '{{ x }}');
      expect(t.format, 'text');
      expect(t.createdAt, matches(_jsIso));
      expect(t.updatedAt, t.createdAt);
      expect(await repo.get(t.id), t);
      expect(history(), [...before, 'Sheet - Template changed']);
    },
  );

  test('update overwrites only the given fields', () async {
    final before = history();
    final t = await repo.update(
      'tpl-guide',
      const UpdateTemplateInput(name: 'Guide', format: 'json'),
    );
    expect(t.id, 'tpl-guide');
    expect(t.name, 'Guide');
    expect(t.format, 'json');
    expect(t.description, fixtureTemplates[1].description);
    expect(t.templateSource, fixtureTemplates[1].templateSource);
    expect(t.createdAt, _seeded);
    expect(t.updatedAt, matches(_sqliteNow));
    expect(t.updatedAt, isNot(_seeded));
    expect(await repo.get('tpl-guide'), t);
    expect(history(), [...before, 'Guide - Template changed']);
  });

  test('update without a name records the stored name', () async {
    final before = history();
    final t = await repo.update(
      'tpl-recipe-book',
      const UpdateTemplateInput(templateSource: 'new', description: 'd'),
    );
    expect(t.templateSource, 'new');
    expect(t.description, 'd');
    expect(t.name, 'Recipe Book');
    expect(history(), [...before, 'Recipe Book - Template changed']);
  });

  test('delete removes the template and records its name', () async {
    final before = history();
    await repo.delete('tpl-beyond');
    expect((await repo.list()).map((t) => t.id), [
      'tpl-guide',
      'tpl-recipe-book',
    ]);
    expect(history(), [...before, 'Beyond the guide - Template changed']);
  });

  group('unknown ids throw RecordNotFound and write nothing', () {
    final notFound = throwsA(
      isA<RecordNotFound>()
          .having((e) => e.domain, 'domain', 'custom_templates')
          .having((e) => e.id, 'id', 'nope'),
    );

    test('get', () async {
      await expectLater(repo.get('nope'), notFound);
    });

    test('update', () async {
      final before = history();
      await expectLater(
        repo.update('nope', const UpdateTemplateInput(name: 'x')),
        notFound,
      );
      expect(history(), before);
    });

    test('delete', () async {
      final before = history();
      await expectLater(repo.delete('nope'), notFound);
      expect(history(), before);
      expect(await repo.list(), fixtureTemplates);
    });
  });
}
