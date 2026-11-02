import 'package:anvil/app/editor/custom_field_scoping.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_test/flutter_test.dart';

CustomFieldDefinition definition(String id, {String? defaultValue}) =>
    CustomFieldDefinition(
      id: id,
      scopeType: CustomFieldScope.npcType,
      scopeId: 'type',
      fieldName: id,
      fieldType: CustomFieldType.text,
      defaultValue: defaultValue,
      enumOptions: const [],
      isRequired: false,
      isSearchable: false,
      sortOrder: 0,
      createdAt: '2026-10-30 10:00:00',
      updatedAt: '2026-10-30 10:00:00',
    );

void main() {
  final definitions = [
    definition('a', defaultValue: 'x'),
    definition('b', defaultValue: 'y'),
    definition('c', defaultValue: ''),
    definition('d'),
  ];

  test('keeps the values of the given definitions and fills the defaults '
      'only where there is no value row', () {
    expect(
      scopeCustomFieldValues(
        const {'a': 'kept', 'b': null, 'other': 'z'},
        definitions,
        keepOthers: false,
      ),
      {'a': 'kept', 'b': null},
    );
  });

  test('with keepOthers the values of other definitions stay', () {
    expect(
      scopeCustomFieldValues(
        const {'other': 'z'},
        definitions,
        keepOthers: true,
      ),
      {'other': 'z', 'a': 'x', 'b': 'y'},
    );
  });

  test('an empty default is not filled in', () {
    final scoped = scopeCustomFieldValues(
      const {},
      definitions,
      keepOthers: false,
    );
    expect(scoped.containsKey('c'), isFalse);
    expect(scoped.containsKey('d'), isFalse);
  });
}
