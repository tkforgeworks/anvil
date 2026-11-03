import 'dart:io';

import 'package:anvil_core/anvil_core.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import '../db/support/fixture_copy.dart';

final _now = DateTime.utc(2026, 11, 3, 9, 0, 0, 1);
final _exportKey = RegExp(r'^[a-z0-9_-]+$');
final _hex = RegExp(r'^#[0-9A-F]{6}$');

/// The tables a template writes, with the columns compared (no timestamps).
const _tables = {
  'stats': 'id, display_name, export_key, description, sort_order',
  'rarities': 'id, display_name, export_key, color_hex, sort_order',
  'item_categories': 'id, display_name, export_key, description, sort_order',
  'npc_types': 'id, display_name, export_key, description, sort_order',
  'crafting_stations': 'id, display_name, export_key, description, sort_order',
  'crafting_specializations':
      'id, display_name, export_key, description, sort_order',
  'derived_stat_definitions':
      'id, display_name, export_key, formula, output_type, rounding_mode, '
      'sort_order',
};

List<Map<String, Object?>> _rows(Database db, String table) => [
  for (final row in db.select(
    'SELECT ${_tables[table]} FROM $table ORDER BY sort_order, id',
  ))
    Map.of(row),
];

/// What [content] should leave in each table.
Map<String, List<Map<String, Object?>>> _expected(
  ProjectTemplateContent content,
) {
  Map<String, Object?> named(
    String id,
    String name,
    String key,
    String description,
    int sort,
  ) => {
    'id': id,
    'display_name': name,
    'export_key': key,
    'description': description,
    'sort_order': sort,
  };
  return {
    'stats': [
      for (final s in content.stats)
        named(s.id, s.displayName, s.exportKey, '', s.sortOrder),
    ],
    'rarities': [
      for (final r in content.rarities)
        {
          'id': r.id,
          'display_name': r.displayName,
          'export_key': r.exportKey,
          'color_hex': r.colorHex,
          'sort_order': r.sortOrder,
        },
    ],
    'item_categories': [
      for (final c in content.itemCategories)
        named(c.id, c.displayName, c.exportKey, c.description, c.sortOrder),
    ],
    'npc_types': [
      for (final t in content.npcTypes)
        named(t.id, t.displayName, t.exportKey, t.description, t.sortOrder),
    ],
    'crafting_stations': [
      for (final s in content.craftingStations)
        named(s.id, s.displayName, s.exportKey, s.description, s.sortOrder),
    ],
    'crafting_specializations': [
      for (final s in content.craftingSpecializations)
        named(s.id, s.displayName, s.exportKey, s.description, s.sortOrder),
    ],
    'derived_stat_definitions': [
      for (final d in content.derivedStats)
        {
          'id': d.id,
          'display_name': d.displayName,
          'export_key': d.exportKey,
          'formula': d.formula,
          'output_type': d.outputType.value,
          'rounding_mode': d.roundingMode.value,
          'sort_order': d.sortOrder,
        },
    ],
  };
}

/// Every (id, export key) pair of [content], per table.
Map<String, List<(String, String)>> _identities(
  ProjectTemplateContent content,
) => {
  'stats': [for (final r in content.stats) (r.id, r.exportKey)],
  'rarities': [for (final r in content.rarities) (r.id, r.exportKey)],
  'item_categories': [
    for (final r in content.itemCategories) (r.id, r.exportKey),
  ],
  'npc_types': [for (final r in content.npcTypes) (r.id, r.exportKey)],
  'crafting_stations': [
    for (final r in content.craftingStations) (r.id, r.exportKey),
  ],
  'crafting_specializations': [
    for (final r in content.craftingSpecializations) (r.id, r.exportKey),
  ],
  'derived_stat_definitions': [
    for (final r in content.derivedStats) (r.id, r.exportKey),
  ],
};

/// Migration 002's id prefix per table.
const _idPrefix = {
  'stats': 'stat-',
  'rarities': 'rarity-',
  'item_categories': 'item-category-',
  'npc_types': 'npc-type-',
  'crafting_stations': 'crafting-station-',
  'crafting_specializations': 'crafting-specialization-',
  'derived_stat_definitions': 'derived-stat-',
};

/// A service whose Fantasy template carries two stats with one export key,
/// so the template's insert fails on the `UNIQUE` constraint.
class _BrokenTemplateService extends ProjectService {
  _BrokenTemplateService({required super.supportDirectory, super.clock});

  @override
  ProjectTemplateContent templateContentFor(
    ProjectTemplate template,
  ) => const ProjectTemplateContent(
    stats: [
      MetaStat(id: 'stat-a', displayName: 'A', exportKey: 'a', sortOrder: 1),
      MetaStat(id: 'stat-b', displayName: 'B', exportKey: 'a', sortOrder: 2),
    ],
  );
}

void main() {
  final fixture = FixtureCopy.setUpEach();
  late ProjectService service;
  late String support;

  setUp(() {
    support = fixture().pathFor('support');
    service = ProjectService(supportDirectory: support, clock: () => _now);
  });

  Future<ProjectSession> create(ProjectTemplate template) => service.create(
    projectName: 'World ${template.id}',
    gameTitle: 'Saga',
    parentFolder: fixture().pathFor('projects'),
    template: template,
  );

  int count(ProjectSession session, String sql) =>
      session.database.handle.select(sql).single.values.first! as int;

  group('registry', () {
    test('carries the 0.1.6 template ids in order', () {
      expect(ProjectTemplate.values.map((t) => t.id), [
        'blank',
        'fantasy-rpg',
        'sci-fi-rpg',
      ]);
      expect(ProjectTemplate.values.map((t) => t.displayName), [
        'Blank',
        'Fantasy RPG',
        'Sci-Fi RPG',
      ]);
      for (final t in ProjectTemplate.values) {
        expect(ProjectTemplate.fromId(t.id), t);
        expect(t.description, isNotEmpty);
      }
      expect(ProjectTemplate.fromId('space-opera'), isNull);
      expect(ProjectTemplate.blank.content.isEmpty, isTrue);
    });

    for (final template in [
      ProjectTemplate.fantasyRpg,
      ProjectTemplate.sciFiRpg,
    ]) {
      test('${template.id} has a coherent meta layer', () {
        final content = template.content;
        expect(content.isEmpty, isFalse);
        expect(content.stats.length, inInclusiveRange(5, 8));
        expect(content.rarities.length, inInclusiveRange(4, 6));
        expect(content.itemCategories.length, inInclusiveRange(5, 8));
        expect(content.npcTypes.length, inInclusiveRange(3, 5));
        expect(content.craftingStations.length, inInclusiveRange(3, 5));
        expect(content.craftingSpecializations.length, inInclusiveRange(2, 4));
        expect(content.derivedStats.length, inInclusiveRange(2, 3));
        expect(content.maxLevel, isNotNull);

        for (final MapEntry(key: table, value: rows) in _identities(
          content,
        ).entries) {
          final ids = rows.map((r) => r.$1).toList();
          final keys = rows.map((r) => r.$2).toList();
          expect(ids.toSet(), hasLength(ids.length), reason: table);
          expect(keys.toSet(), hasLength(keys.length), reason: table);
          for (final (id, key) in rows) {
            expect(id, startsWith(_idPrefix[table]!), reason: table);
            expect(key, matches(_exportKey), reason: table);
          }
        }

        final colours = content.rarities.map((r) => r.colorHex).toList();
        expect(colours, everyElement(matches(_hex)));
        expect(colours.toSet(), hasLength(colours.length));

        final statKeys = content.stats.map((s) => s.exportKey).toSet();
        for (final d in content.derivedStats) {
          expect(validateFormula(d.formula), isNull, reason: d.formula);
          expect(
            statKeys.containsAll(extractVariableNames(d.formula)),
            isTrue,
            reason: '${d.formula} names only this template\'s stats',
          );
        }
      });
    }

    test('the two templates and migration 002 share no stat or rarity key '
        'set', () {
      final fantasy = ProjectTemplate.fantasyRpg.content;
      final sciFi = ProjectTemplate.sciFiRpg.content;
      Set<String> stats(ProjectTemplateContent c) =>
          c.stats.map((s) => s.exportKey).toSet();
      Set<String> rarities(ProjectTemplateContent c) =>
          c.rarities.map((s) => s.exportKey).toSet();
      const seededStats = {'str', 'con', 'dex', 'int', 'wis', 'res', 'cha'};
      expect(stats(fantasy).intersection(stats(sciFi)), isEmpty);
      expect(stats(fantasy).intersection(seededStats), isEmpty);
      expect(stats(sciFi).intersection(seededStats), isEmpty);
      expect(rarities(fantasy), isNot(rarities(sciFi)));
    });
  });

  group('create', () {
    test('blank yields exactly what migration 002 seeds', () async {
      final session = await create(ProjectTemplate.blank);
      final reference = ProjectDatabase.open(fixture().pathFor('ref.anvil'));
      addTearDown(reference.close);
      runMigrations(reference);

      for (final table in _tables.keys) {
        expect(
          _rows(session.database.handle, table),
          _rows(reference.handle, table),
          reason: table,
        );
      }
      expect(
        _rows(
          session.database.handle,
          'stats',
        ).map((r) => r['export_key']).toList(),
        ['str', 'con', 'dex', 'int', 'wis', 'res', 'cha'],
      );
      expect(count(session, 'SELECT max_level FROM project_info'), 50);
      expect(count(session, 'SELECT COUNT(*) FROM save_history'), 0);
      await service.close(session);
    });

    for (final template in [
      ProjectTemplate.fantasyRpg,
      ProjectTemplate.sciFiRpg,
    ]) {
      test('${template.id} replaces the meta layer once, with no history, '
          'and validates clean', () async {
        final session = await create(template);
        final content = template.content;
        final expected = _expected(content);
        for (final table in _tables.keys) {
          expect(
            _rows(session.database.handle, table),
            expected[table],
            reason: table,
          );
        }
        expect(
          count(session, 'SELECT max_level FROM project_info'),
          content.maxLevel,
        );
        expect(count(session, 'SELECT COUNT(*) FROM save_history'), 0);
        expect(count(session, 'SELECT COUNT(*) FROM schema_migrations'), 7);
        expect(session.metadata.recordCounts, RecordCounts.empty);
        expect(validateProject(session.database), isEmpty);

        // A class makes the validation engine evaluate every derived stat
        // formula at level 1 against this template's stats.
        session.database.handle.execute(
          'INSERT INTO classes (id, display_name, export_key) '
          "VALUES ('class-probe', 'Probe', 'probe')",
        );
        expect(validateProject(session.database), isEmpty);
        session.database.handle.execute(
          "DELETE FROM classes WHERE id = 'class-probe'",
        );

        // Reopening applies nothing again.
        final file = session.filePath;
        await service.close(session);
        final reopened = await service.open(file);
        final again = (reopened as ProjectOpened).session;
        for (final table in _tables.keys) {
          expect(
            _rows(again.database.handle, table),
            expected[table],
            reason: table,
          );
        }
        expect(count(again, 'SELECT COUNT(*) FROM save_history'), 0);
        await service.close(again);
      });
    }

    test('a template that fails to insert removes the project and its '
        'lock', () async {
      final broken = _BrokenTemplateService(
        supportDirectory: support,
        clock: () => _now,
      );
      final parent = fixture().pathFor('projects');
      Object? thrown;
      try {
        await broken.create(
          projectName: 'Broken',
          gameTitle: 'T',
          parentFolder: parent,
          template: ProjectTemplate.fantasyRpg,
        );
      } catch (e) {
        thrown = e;
      }
      expect(thrown, isA<ProjectCreateFailed>());
      expect(
        (thrown as ProjectCreateFailed).cause,
        isA<SqliteException>().having(
          (e) => e.message,
          'message',
          contains('UNIQUE'),
        ),
      );
      expect(Directory(p.join(parent, 'Broken')).existsSync(), isFalse);
      expect(
        File(p.join(parent, 'Broken', 'database', 'Broken.anvil.lock'))
            .existsSync(),
        isFalse,
      );
      expect(broken.recentProjects(), isEmpty);

      // The name is free again: a working create succeeds there.
      final session = await service.create(
        projectName: 'Broken',
        gameTitle: 'T',
        parentFolder: parent,
        template: ProjectTemplate.fantasyRpg,
      );
      await service.close(session);
    });
  });
}
