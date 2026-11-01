import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../db/errors.dart';
import '../db/project_database.dart';
import '../db/save_descriptions.dart';
import '../domain/custom_fields.dart';
import 'custom_field_repository.dart';
import 'record_id.dart';

/// `SELECT` through a [ReadScope] or a [SaveScope].
typedef _Select = ResultSet Function(String sql, [List<Object?> parameters]);

const String _table = 'custom_field_definitions';

CustomFieldDefinition _definition(Row r) {
  final enumJson = r['enum_options_json'] as String?;
  return CustomFieldDefinition(
    id: r['id'] as String,
    scopeType: CustomFieldScope.fromValue(r['scope_type'] as String),
    scopeId: r['scope_id'] as String,
    fieldName: r['field_name'] as String,
    fieldType: CustomFieldType.fromValue(r['field_type'] as String),
    defaultValue: r['default_value'] as String?,
    // 0.1.6 treated NULL and '' alike (`row.enum_options_json ? … : []`).
    enumOptions: enumJson == null || enumJson.isEmpty
        ? const []
        : (jsonDecode(enumJson) as List<Object?>).cast<String>(),
    isRequired: r['is_required'] == 1,
    isSearchable: r['is_searchable'] == 1,
    sortOrder: r['sort_order'] as int,
    createdAt: r['created_at'] as String,
    updatedAt: r['updated_at'] as String,
  );
}

/// `enum_options_json` is NULL for an empty list, as in 0.1.6.
String? _enumJson(List<String> options) =>
    options.isEmpty ? null : jsonEncode(options);

CustomFieldDefinition? _find(_Select select, String id) {
  final rows = select('SELECT * FROM $_table WHERE id = ?', [id]);
  return rows.isEmpty ? null : _definition(rows.single);
}

CustomFieldDefinition _get(_Select select, String id) =>
    _find(select, id) ?? (throw RecordNotFound(_table, id));

int _valueCount(_Select select, String id) =>
    select(
          'SELECT COUNT(*) AS count FROM custom_field_values '
          "WHERE field_definition_id = ? AND value IS NOT NULL AND value != ''",
          [id],
        ).single['count']
        as int;

List<String> _usedEnumValues(_Select select, String id) => [
  for (final r in select(
    'SELECT DISTINCT value FROM custom_field_values '
    "WHERE field_definition_id = ? AND value IS NOT NULL AND value != ''",
    [id],
  ))
    r['value'] as String,
];

/// `CustomFieldRepository` on a [ProjectDatabase], porting 0.1.6's
/// `custom-field-definition.repository.ts`.
final class SqliteCustomFieldRepository implements CustomFieldRepository {
  SqliteCustomFieldRepository(this._db);

  final ProjectDatabase _db;

  @override
  Future<List<CustomFieldDefinition>> listDefinitions(
    CustomFieldScope scopeType,
    String scopeId,
  ) async => _db.read(
    (tx) => [
      for (final r in tx.select(
        'SELECT * FROM $_table WHERE scope_type = ? AND scope_id = ? '
        'ORDER BY sort_order, field_name COLLATE NOCASE',
        [scopeType.value, scopeId],
      ))
        _definition(r),
    ],
  );

  @override
  Future<CustomFieldDefinition> getDefinition(String id) async =>
      _db.read((tx) => _get(tx.select, id));

  @override
  Future<CustomFieldDefinition> createDefinition(
    CreateCustomFieldDefinitionInput input,
  ) async => _db.saveTransaction(customFieldDefinitionsChanged, (tx) {
    final id = newRecordId();
    tx.execute(
      'INSERT INTO $_table (id, scope_type, scope_id, field_name, field_type, '
      'default_value, enum_options_json, is_required, is_searchable, '
      'sort_order) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        id,
        input.scopeType.value,
        input.scopeId,
        input.fieldName,
        input.fieldType.value,
        input.defaultValue,
        _enumJson(input.enumOptions),
        input.isRequired ? 1 : 0,
        input.isSearchable ? 1 : 0,
        input.sortOrder,
      ],
    );
    return _get(tx.select, id);
  });

  @override
  Future<CustomFieldDefinition> updateDefinition(
    String id,
    UpdateCustomFieldDefinitionInput input,
  ) async => _db.saveTransaction(customFieldDefinitionsChanged, (tx) {
    final current = _get(tx.select, id);
    final newOptions = input.enumOptions;

    if (newOptions != null &&
        current.fieldType == CustomFieldType.enumeration) {
      final keep = newOptions.toSet();
      final blocked = [
        for (final v in _usedEnumValues(tx.select, id))
          if (!keep.contains(v)) v,
      ];
      if (blocked.isNotEmpty) {
        throw SaveBlocked([
          'Cannot remove enum option(s) that are in use: ${blocked.join(', ')}',
        ]);
      }
    }

    tx.execute(
      'UPDATE $_table SET field_name = ?, default_value = ?, '
      'enum_options_json = ?, is_required = ?, is_searchable = ?, '
      "sort_order = ?, updated_at = datetime('now') WHERE id = ?",
      [
        input.fieldName ?? current.fieldName,
        input.setsDefaultValue ? input.defaultValue : current.defaultValue,
        _enumJson(newOptions ?? current.enumOptions),
        (input.isRequired ?? current.isRequired) ? 1 : 0,
        (input.isSearchable ?? current.isSearchable) ? 1 : 0,
        input.sortOrder ?? current.sortOrder,
        id,
      ],
    );
    return _get(tx.select, id);
  });

  @override
  Future<void> deleteDefinition(String id) async =>
      _db.saveTransaction(customFieldDefinitionsChanged, (tx) {
        final current = _get(tx.select, id);
        final count = _valueCount(tx.select, id);
        if (count > 0) {
          // 0.1.6's repository returned `{deleted: false, affectedCount}` and
          // the Custom Fields tab showed this message.
          throw SaveBlocked([
            'Cannot delete "${current.fieldName}": $count record(s) currently '
                'have values for this field. Clear those values first.',
          ]);
        }
        tx.execute('DELETE FROM $_table WHERE id = ?', [id]);
      });

  @override
  Future<int> valueCount(String id) async =>
      _db.read((tx) => _valueCount(tx.select, id));

  @override
  Future<List<String>> usedEnumValues(String id) async =>
      _db.read((tx) => _usedEnumValues(tx.select, id));
}
