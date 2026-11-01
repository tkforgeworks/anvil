// ExportService against Electron 0.1.6: gate, assembly and render on a
// background isolate over a read-only connection, byte for byte against
// the preset and template fixtures.
import 'dart:convert';
import 'dart:io';

import 'package:anvil_core/anvil_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../db/support/fixture_copy.dart';
import 'support/fixtures.dart';

/// Iron Sword and Healing Potion, the items of the selection fixtures.
const List<String> _selectedItems = [
  '6069c26a-d758-4981-b29b-eed2c95fe6f3',
  'a4b66c54-05d2-4007-bed7-8f13bee1f087',
];

const String _macroTemplate =
    '{% for i in items %}{{ i.display_name }}{% endfor %}\n'
    '  {% macro label(x) %}{{ x }}{% endmacro %}';

/// A fresh fixture copy with validation-mutations.sql applied (split on
/// `;\n`, as the validation oracle splits it), left open read-write.
ProjectDatabase _mutatedFixture(FixtureCopy copy) {
  final db = copy.openFixture();
  final sql = File(
    p.join(fixturesDir, 'validation', 'validation-mutations.sql'),
  ).readAsStringSync();
  for (final statement in sql.split(';\n')) {
    if (statement.trim().isEmpty) continue;
    // ignore: invalid_use_of_internal_member
    db.handle.execute(statement.trim());
  }
  return db;
}

int _errorCount(List<ValidationIssue> issues) =>
    issues.where((i) => i.severity == ValidationSeverity.error).length;

void main() {
  final copy = FixtureCopy.setUpEach();

  /// A service over a fresh copy that no connection on this isolate opens.
  ExportService service() => ExportService(projectPath: copy().copyFixture());

  group('listSelectors', () {
    test('the three presets verbatim, then the templates by name', () async {
      final selectors = await service().listSelectors();
      expect(selectors.take(3), [
        const ExportSelector(
          id: 'nested-json',
          name: 'Nested JSON',
          description:
              'Hierarchical JSON with nested sub-objects for referenced '
              'records',
          format: 'json',
          builtIn: true,
        ),
        const ExportSelector(
          id: 'flat-json',
          name: 'Flat JSON',
          description:
              'Flat JSON with all reference fields resolved to export keys',
          format: 'json',
          builtIn: true,
        ),
        const ExportSelector(
          id: 'csv',
          name: 'CSV',
          description:
              'One CSV file per domain, references resolved to export keys',
          format: 'csv',
          builtIn: true,
        ),
      ]);
      expect(selectors.skip(3), [
        const ExportSelector(
          id: 'tpl-beyond',
          name: 'Beyond the guide',
          description: 'Nunjucks idioms outside the documented subset',
          format: 'text',
          builtIn: false,
        ),
        const ExportSelector(
          id: 'tpl-guide',
          name: 'Items (guide example)',
          description: 'The example from the writing guide',
          format: 'text',
          builtIn: false,
        ),
        const ExportSelector(
          id: 'tpl-recipe-book',
          name: 'Recipe Book',
          description: 'Nested loops, set, json filter',
          format: 'text',
          builtIn: false,
        ),
      ]);
    });

    test('an unsupported template is listed with its check', () async {
      final db = copy().openFixture();
      final created = await SqliteTemplateRepository(db).create(
        const CreateTemplateInput(
          name: 'Macros',
          templateSource: _macroTemplate,
        ),
      );
      final selectors = await ExportService(projectPath: db.path)
          .listSelectors();
      final entry = selectors.singleWhere((s) => s.id == created.id);
      expect(entry.builtIn, isFalse);
      expect(entry.unsupported, checkTemplate(_macroTemplate));
      expect(entry.unsupported!.kind, TemplateErrorKind.unsupported);
      expect(entry.unsupported!.line, 2);
      expect(selectors.where((s) => s.unsupported != null).map((s) => s.id), [
        created.id,
      ]);
    });
  });

  group('presets', () {
    test('nested JSON, full project', () async {
      final out = await service().render(
        'nested-json',
        const ExportScope.full(),
      );
      expectSameBytes(out.text, readFixture('preset-nested-json.txt'));
      expect(out.files, isEmpty);
      expect(out.suggestedFileName, 'export.json');
    });

    test('flat JSON, full project', () async {
      final out = await service().render('flat-json', const ExportScope.full());
      expectSameBytes(out.text, readFixture('preset-flat-json.txt'));
      expect(out.files, isEmpty);
      expect(out.suggestedFileName, 'export.json');
    });

    test('flat JSON, item selection', () async {
      final out = await service().render(
        'flat-json',
        ExportScope.selection(ExportDomain.items, _selectedItems),
      );
      expectSameBytes(out.text, readFixture('preset-flat-json-selection.txt'));
    });

    test('nested JSON, domain scope prints only that domain', () async {
      final out = await service().render(
        'nested-json',
        const ExportScope.domain(ExportDomain.lootTables),
      );
      final decoded = jsonDecode(out.text) as Map<String, Object?>;
      expect(decoded.keys, ['loot_tables']);
    });

    test('CSV summary and all six files', () async {
      final out = await service().render('csv', const ExportScope.full());
      expectSameBytes(out.text, readFixture('preset-csv.txt'));
      expect(out.files.map((f) => f.filename), [
        'classes.csv',
        'abilities.csv',
        'items.csv',
        'recipes.csv',
        'npcs.csv',
        'loot_tables.csv',
      ]);
      for (final f in out.files) {
        expectSameBytes(
          f.content,
          readFixture('preset-csv-${f.filename}'),
          reason: f.filename,
        );
      }
      expect(out.suggestedFileName, 'export.txt');
    });
  });

  group('custom templates', () {
    for (final (id, name) in [
      ('tpl-guide', 'guide'),
      ('tpl-recipe-book', 'recipe-book'),
      ('tpl-beyond', 'beyond-guide'),
    ]) {
      test(
        '$id renders byte-identical to template-$name.expected.txt',
        () async {
          final out = await service().render(id, const ExportScope.full());
          expectSameBytes(out.text, readFixture('template-$name.expected.txt'));
          expect(out.files, isEmpty);
          expect(out.suggestedFileName, 'export.txt');
        },
      );
    }

    test(
      'a json-format template still suggests export.txt, as 0.1.6',
      () async {
        final db = copy().openFixture();
        final t = await SqliteTemplateRepository(db).create(
          const CreateTemplateInput(
            name: 'Json',
            templateSource: '{{ items | length }}',
            format: 'json',
          ),
        );
        final out = await ExportService(projectPath: db.path)
            .render(t.id, const ExportScope.full());
        expect(out.text, '5');
        expect(out.suggestedFileName, 'export.txt');
      },
    );

    test('an unsupported template fails with the renderer error', () async {
      final db = copy().openFixture();
      final t = await SqliteTemplateRepository(db).create(
        const CreateTemplateInput(
          name: 'Macros',
          templateSource: _macroTemplate,
        ),
      );
      await expectLater(
        ExportService(projectPath: db.path)
            .render(t.id, const ExportScope.full()),
        throwsA(
          isA<AnvilTemplateError>()
              .having((e) => e.kind, 'kind', TemplateErrorKind.unsupported)
              .having((e) => e.line, 'line', 2),
        ),
      );
    });

    test('a render error comes back with its kind', () async {
      final db = copy().openFixture();
      final t = await SqliteTemplateRepository(db).create(
        const CreateTemplateInput(
          name: 'Undefined',
          templateSource: '{{ nope }}',
        ),
      );
      await expectLater(
        ExportService(projectPath: db.path)
            .render(t.id, const ExportScope.full()),
        throwsA(
          isA<AnvilTemplateError>().having(
            (e) => e.kind,
            'kind',
            TemplateErrorKind.render,
          ),
        ),
      );
    });

    test('a runaway template is stopped by the render timeout', () async {
      final db = copy().openFixture();
      const loop =
          '{% for a in [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,'
          '19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40]'
          ' %}';
      final t = await SqliteTemplateRepository(db).create(
        CreateTemplateInput(
          name: 'Runaway',
          templateSource:
              '${List.filled(4, loop).join()}x'
              '${List.filled(4, '{% endfor %}').join()}',
        ),
      );
      await expectLater(
        ExportService(
          projectPath: db.path,
          renderTimeout: const Duration(milliseconds: 100),
        ).render(t.id, const ExportScope.full()),
        throwsA(isA<RenderTimeout>()),
      );
    });

    test('an unknown selector id throws RecordNotFound', () async {
      await expectLater(
        service().render('no-such-template', const ExportScope.full()),
        throwsA(
          isA<RecordNotFound>()
              .having((e) => e.domain, 'domain', 'custom_templates')
              .having((e) => e.id, 'id', 'no-such-template'),
        ),
      );
    });
  });

  group('validation gate', () {
    test('the pristine fixture has no error-severity issue', () {
      final db = copy().track(
        ProjectDatabase.openReadOnly(copy().copyFixture()),
      );
      final issues = validateProject(db);
      expect(issues, isNotEmpty);
      expect(_errorCount(issues), 0);
    });

    test('the mutated fixture blocks every export with the count', () async {
      final db = _mutatedFixture(copy());
      final errors = _errorCount(validateProject(db));
      expect(errors, 33);
      final svc = ExportService(projectPath: db.path);
      for (final id in ['nested-json', 'csv', 'tpl-guide', 'no-such-id']) {
        await expectLater(
          svc.render(id, const ExportScope.full()),
          throwsA(
            isA<ExportBlocked>().having(
              (e) => e.message,
              'message',
              'Export blocked: 33 validation errors must be resolved before '
                  'exporting.',
            ),
          ),
          reason: id,
        );
      }
    });

    test('one error uses the singular, as 0.1.6', () async {
      final db = copy().openFixture();
      // ignore: invalid_use_of_internal_member
      db.handle
        ..execute('PRAGMA foreign_keys = OFF')
        ..execute(
          "UPDATE items SET rarity_id = 'missing-rarity' "
          "WHERE id = '${_selectedItems.first}'",
        );
      expect(_errorCount(validateProject(db)), 1);
      await expectLater(
        ExportService(projectPath: db.path)
            .render('flat-json', const ExportScope.full()),
        throwsA(
          isA<ExportBlocked>().having(
            (e) => e.message,
            'message',
            'Export blocked: 1 validation error must be resolved before '
                'exporting.',
          ),
        ),
      );
    });
  });

  test('works with no connection on this isolate and leaves the file '
      'byte-identical', () async {
    final path = copy().copyFixture();
    final before = File(path).readAsBytesSync();
    final svc = ExportService(projectPath: path);

    expect(await svc.listSelectors(), hasLength(6));
    await svc.render('nested-json', const ExportScope.full());
    await svc.render('tpl-recipe-book', const ExportScope.full());

    expect(File(path).readAsBytesSync(), before);
    for (final sidecar in ['-wal', '-shm', '-journal']) {
      expect(File('$path$sidecar').existsSync(), isFalse, reason: sidecar);
    }
  });

  test('sees committed writes of an open read-write handle', () async {
    final db = copy().openFixture();
    final repo = SqliteTemplateRepository(db);
    final t = await repo.create(
      const CreateTemplateInput(
        name: 'Count',
        templateSource: '{{ classes | length }}',
      ),
    );
    final out = await ExportService(projectPath: db.path)
        .render(t.id, const ExportScope.full());
    expect(out.text, '2');
  });
}
