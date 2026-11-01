import 'package:anvil_core/anvil_core.dart';
import 'package:test/test.dart';

import '../db/support/fixture_copy.dart';

const String _damage = '18790df6-c2dc-4597-b0b2-679b538d7729';
const String _handedness = 'd62cfe4d-504e-4a84-b15f-af0d0b90bb9d';
const String _aggression = '3789fc46-bc57-4677-ad44-73d9b334788f';
const String _ironSword = '6069c26a-d758-4981-b29b-eed2c95fe6f3';

void main() {
  final fixture = FixtureCopy.setUpEach();

  late ProjectDatabase db;
  late CustomFieldRepository repo;

  setUp(() {
    db = fixture().openFixture();
    repo = SqliteCustomFieldRepository(db);
  });

  int historyCount() =>
      db
              .read((tx) => tx.select('SELECT COUNT(*) AS c FROM save_history'))
              .single['c']
          as int;

  String latestHistory() =>
      db
              .read(
                (tx) => tx.select(
                  'SELECT description FROM save_history '
                  'ORDER BY id DESC LIMIT 1',
                ),
              )
              .single['description']
          as String;

  Map<String, Object?>? definitionRow(String id) {
    final rows = db.read(
      (tx) => tx.select('SELECT * FROM custom_field_definitions WHERE id = ?', [
        id,
      ]),
    );
    return rows.isEmpty ? null : {...rows.single};
  }

  int valueRows(String id) =>
      db
              .read(
                (tx) => tx.select(
                  'SELECT COUNT(*) AS c FROM custom_field_values '
                  'WHERE field_definition_id = ?',
                  [id],
                ),
              )
              .single['c']
          as int;

  test('lists a scope in sort order with decoded fields', () async {
    final weapon = await repo.listDefinitions(
      CustomFieldScope.itemCategory,
      'item-category-weapon',
    );
    expect([for (final d in weapon) d.fieldName], ['damage', 'handedness']);
    final damage = weapon.first;
    expect(damage.id, _damage);
    expect(damage.fieldType, CustomFieldType.integer);
    expect(damage.isRequired, isTrue);
    expect(damage.isSearchable, isFalse);
    expect(damage.defaultValue, isNull);
    expect(damage.enumOptions, isEmpty);
    expect(damage.createdAt, '2026-10-31 20:58:16');
    final handedness = weapon.last;
    expect(handedness.fieldType, CustomFieldType.enumeration);
    expect(handedness.defaultValue, 'one-handed');
    expect(handedness.enumOptions, ['one-handed', 'two-handed']);

    final enemy = await repo.listDefinitions(
      CustomFieldScope.npcType,
      'npc-type-enemy',
    );
    expect([for (final d in enemy) d.id], [_aggression]);
    expect(
      await repo.listDefinitions(CustomFieldScope.npcType, 'npc-type-merchant'),
      isEmpty,
    );
  });

  test('equal sort order falls back to field name ignoring case', () async {
    for (final name in ['beta', 'Alpha', 'gamma']) {
      await repo.createDefinition(
        CreateCustomFieldDefinitionInput(
          scopeType: CustomFieldScope.itemCategory,
          scopeId: 'item-category-armor',
          fieldName: name,
          fieldType: CustomFieldType.text,
        ),
      );
    }
    final armor = await repo.listDefinitions(
      CustomFieldScope.itemCategory,
      'item-category-armor',
    );
    expect([for (final d in armor) d.fieldName], ['Alpha', 'beta', 'gamma']);
  });

  test('create then get', () async {
    final before = historyCount();
    final created = await repo.createDefinition(
      CreateCustomFieldDefinitionInput(
        scopeType: CustomFieldScope.npcType,
        scopeId: 'npc-type-merchant',
        fieldName: 'stock',
        fieldType: CustomFieldType.enumeration,
        defaultValue: 'low',
        enumOptions: ['low', 'high'],
        isSearchable: true,
        sortOrder: 3,
      ),
    );
    expect(
      created.id,
      matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab]')),
    );
    expect(created.id, hasLength(36));
    final got = await repo.getDefinition(created.id);
    expect(got.fieldName, 'stock');
    expect(got.scopeType, CustomFieldScope.npcType);
    expect(got.enumOptions, ['low', 'high']);
    expect(got.isSearchable, isTrue);
    expect(got.isRequired, isFalse);
    expect(got.sortOrder, 3);
    expect(definitionRow(created.id)!['enum_options_json'], '["low","high"]');
    expect(historyCount(), before + 1);
    expect(latestHistory(), 'Custom field definitions changed');
  });

  test('no enum options are stored as NULL', () async {
    final created = await repo.createDefinition(
      CreateCustomFieldDefinitionInput(
        scopeType: CustomFieldScope.itemCategory,
        scopeId: 'item-category-armor',
        fieldName: 'weight',
        fieldType: CustomFieldType.decimal,
      ),
    );
    expect(definitionRow(created.id)!['enum_options_json'], isNull);
    expect(created.enumOptions, isEmpty);
  });

  test('getDefinition of an unknown id throws RecordNotFound', () async {
    await expectLater(
      repo.getDefinition('missing'),
      throwsA(
        isA<RecordNotFound>().having(
          (e) => e.domain,
          'domain',
          'custom_field_definitions',
        ),
      ),
    );
  });

  test('update changes the given fields and keeps the type', () async {
    final updated = await repo.updateDefinition(
      _damage,
      UpdateCustomFieldDefinitionInput(
        fieldName: 'base damage',
        defaultValue: '5',
        isSearchable: true,
      ),
    );
    expect(updated.fieldName, 'base damage');
    expect(updated.defaultValue, '5');
    expect(updated.isSearchable, isTrue);
    expect(updated.isRequired, isTrue);
    expect(updated.fieldType, CustomFieldType.integer);
    expect(updated.updatedAt, isNot('2026-10-31 20:58:16'));
    expect(latestHistory(), 'Custom field definitions changed');

    final cleared = await repo.updateDefinition(
      _damage,
      UpdateCustomFieldDefinitionInput(defaultValue: null),
    );
    expect(cleared.defaultValue, isNull);
    expect(cleared.fieldName, 'base damage');
  });

  test('removing a used enum option is refused and changes nothing', () async {
    final before = definitionRow(_handedness);
    final history = historyCount();
    await expectLater(
      repo.updateDefinition(
        _handedness,
        UpdateCustomFieldDefinitionInput(
          fieldName: 'grip',
          enumOptions: ['two-handed'],
        ),
      ),
      throwsA(
        isA<SaveBlocked>().having((e) => e.blockers, 'blockers', [
          'Cannot remove enum option(s) that are in use: one-handed',
        ]),
      ),
    );
    expect(definitionRow(_handedness), before);
    expect(historyCount(), history);
  });

  test('removing an unused enum option succeeds', () async {
    final updated = await repo.updateDefinition(
      _handedness,
      UpdateCustomFieldDefinitionInput(
        enumOptions: ['one-handed', 'versatile'],
      ),
    );
    expect(updated.enumOptions, ['one-handed', 'versatile']);
    expect(
      definitionRow(_handedness)!['enum_options_json'],
      '["one-handed","versatile"]',
    );
  });

  test('update of an unknown id throws RecordNotFound', () async {
    await expectLater(
      repo.updateDefinition('missing', UpdateCustomFieldDefinitionInput()),
      throwsA(isA<RecordNotFound>()),
    );
  });

  test('valueCount and usedEnumValues on the weapon fields', () async {
    expect(await repo.valueCount(_damage), 1);
    expect(await repo.valueCount(_handedness), 1);
    expect(await repo.usedEnumValues(_handedness), ['one-handed']);
    expect(await repo.usedEnumValues(_aggression), ['hostile']);
    expect(await repo.valueCount('missing'), 0);
  });

  test('delete is refused while a record has a value', () async {
    final history = historyCount();
    await expectLater(
      repo.deleteDefinition(_damage),
      throwsA(
        isA<SaveBlocked>().having((e) => e.blockers, 'blockers', [
          'Cannot delete "damage": 1 record(s) currently have values for '
              'this field. Clear those values first.',
        ]),
      ),
    );
    expect(definitionRow(_damage), isNotNull);
    expect(valueRows(_damage), 1);
    expect(historyCount(), history);
  });

  test('delete removes the definition and its values', () async {
    // Clear the Iron Sword's damage, leaving an empty value row behind.
    db.saveTransaction('test', (tx) {
      tx.execute(
        "UPDATE custom_field_values SET value = '' "
        'WHERE field_definition_id = ? AND record_id = ?',
        [_damage, _ironSword],
      );
    });
    expect(await repo.valueCount(_damage), 0);
    expect(valueRows(_damage), 1);

    await repo.deleteDefinition(_damage);

    expect(definitionRow(_damage), isNull);
    expect(valueRows(_damage), 0);
    expect(valueRows(_handedness), 1);
    expect(latestHistory(), 'Custom field definitions changed');
    await expectLater(
      repo.getDefinition(_damage),
      throwsA(isA<RecordNotFound>()),
    );
  });

  test('delete of an unknown id throws RecordNotFound', () async {
    await expectLater(
      repo.deleteDefinition('missing'),
      throwsA(isA<RecordNotFound>()),
    );
  });
}
