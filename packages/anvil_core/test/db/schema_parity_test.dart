import 'dart:io';

import 'package:anvil_core/anvil_core.dart';
import 'package:anvil_core/src/db/migrations/migration_runner.dart'
    show applyMigrations;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/fixture_copy.dart';

List<String> _ids(ProjectDatabase db, String table) => [
  for (final row in db.handle.select(
    'SELECT id FROM $table ORDER BY sort_order',
  ))
    row['id'] as String,
];

void main() {
  final fixture = FixtureCopy.setUpEach();

  ProjectDatabase freshProject() {
    final db = fixture().openEmpty();
    runMigrations(db);
    return db;
  }

  test('a fresh Dart project has the Electron 0.1.6 sqlite_master', () {
    final db = freshProject();
    expect(masterRows(db.handle), loadMasterJson('schema-sqlite-master.json'));
  });

  test('a fresh Dart project has the same sqlite_master as the fixture', () {
    final db = freshProject();
    final electron = fixture().openFixture();
    expect(
      masterRows(db.handle, withTableName: true),
      masterRows(electron.handle, withTableName: true),
    );
  });

  test('a fresh Dart project has the 002 seed rows', () {
    final db = freshProject();

    expect(_ids(db, 'stats'), [
      'stat-strength',
      'stat-constitution',
      'stat-dexterity',
      'stat-intelligence',
      'stat-wisdom',
      'stat-resilience',
      'stat-charisma',
    ]);
    expect(_ids(db, 'item_categories'), [
      'item-category-weapon',
      'item-category-armor',
      'item-category-accessory',
      'item-category-consumable',
      'item-category-quest-item',
      'item-category-crafting-resource',
      'item-category-blueprint',
    ]);
    expect(_ids(db, 'npc_types'), [
      'npc-type-enemy',
      'npc-type-merchant',
      'npc-type-quest-giver',
    ]);
    expect(_ids(db, 'crafting_stations'), [
      'crafting-station-forge',
      'crafting-station-workbench',
      'crafting-station-alchemy-table',
      'crafting-station-enchanting-table',
    ]);
    expect(_ids(db, 'crafting_specializations'), [
      'crafting-specialization-blacksmithing',
      'crafting-specialization-carpentry',
      'crafting-specialization-alchemy',
      'crafting-specialization-enchanting',
    ]);
    expect(_ids(db, 'derived_stat_definitions'), [
      'derived-stat-max-hp',
      'derived-stat-attack-power',
      'derived-stat-magic-power',
    ]);
    expect(
      rowsOf(
        db.handle,
        'SELECT id, display_name, export_key, color_hex, sort_order '
        'FROM rarities ORDER BY sort_order',
      ),
      [
        {
          'id': 'rarity-common',
          'display_name': 'Common',
          'export_key': 'common',
          'color_hex': '#D8DEE9',
          'sort_order': 10,
        },
        {
          'id': 'rarity-uncommon',
          'display_name': 'Uncommon',
          'export_key': 'uncommon',
          'color_hex': '#A3BE8C',
          'sort_order': 20,
        },
        {
          'id': 'rarity-rare',
          'display_name': 'Rare',
          'export_key': 'rare',
          'color_hex': '#5E81AC',
          'sort_order': 30,
        },
        {
          'id': 'rarity-epic',
          'display_name': 'Epic',
          'export_key': 'epic',
          'color_hex': '#B48EAD',
          'sort_order': 40,
        },
        {
          'id': 'rarity-legendary',
          'display_name': 'Legendary',
          'export_key': 'legendary',
          'color_hex': '#EBCB8B',
          'sort_order': 50,
        },
      ],
    );
    expect(
      rowsOf(
        db.handle,
        'SELECT export_key, formula, output_type, rounding_mode '
        'FROM derived_stat_definitions ORDER BY sort_order',
      ),
      [
        {
          'export_key': 'max_hp',
          'formula': 'con * 10',
          'output_type': 'integer',
          'rounding_mode': 'round',
        },
        {
          'export_key': 'attack_power',
          'formula': 'str * 2',
          'output_type': 'integer',
          'rounding_mode': 'round',
        },
        {
          'export_key': 'magic_power',
          'formula': 'int * 2',
          'output_type': 'integer',
          'rounding_mode': 'round',
        },
      ],
    );
    expect(
      db.handle
          .select("SELECT COUNT(*) AS n FROM stats WHERE description = ''")
          .single['n'],
      7,
    );

    final info = db.handle.select('SELECT * FROM project_info').single;
    expect(info['id'], 1);
    expect(info['max_level'], 50);
    expect(info['soft_delete_reference_severity'], 'Warning');
    expect(info['schema_version'], 7);
  });

  group('each migration matches Electron step by step', () {
    for (var n = 1; n <= 7; n++) {
      final name = 'schema-step-0$n.json';
      final present = File(p.join(fixturesDir, name)).existsSync();
      test('after migration $n', () {
        final db = fixture().openEmpty();
        applyMigrations(db, allMigrations.take(n));
        expect(
          masterRows(db.handle, withTableName: true),
          loadMasterJson(name),
        );
      }, skip: present ? false : '$name not generated yet (T-007)');
    }
  });
}
