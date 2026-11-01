/// Custom field definitions and values.
///
/// Ported from the "Custom Field Definitions" section and `CustomFieldValue`
/// of 0.1.6's `src/shared/domain-types.ts`.
library;

/// What a custom field definition is scoped to; 0.1.6 `CustomFieldScope`.
enum CustomFieldScope {
  itemCategory('item_category'),
  npcType('npc_type');

  const CustomFieldScope(this.value);

  /// `custom_field_definitions.scope_type`.
  final String value;

  /// Parses a stored value; throws [ArgumentError] on anything else.
  static CustomFieldScope fromValue(String value) => values.firstWhere(
    (e) => e.value == value,
    orElse: () => throw ArgumentError.value(value, 'value', 'Unknown scope'),
  );
}

/// A custom field's value type; 0.1.6 `CustomFieldType`. Scalar and enum
/// only: there are no cross-domain reference types.
enum CustomFieldType {
  text('text'),
  integer('integer'),
  decimal('decimal'),
  boolean('boolean'),
  enumeration('enum');

  const CustomFieldType(this.value);

  /// `custom_field_definitions.field_type`.
  final String value;

  /// Parses a stored value; throws [ArgumentError] on anything else.
  static CustomFieldType fromValue(String value) => values.firstWhere(
    (e) => e.value == value,
    orElse: () =>
        throw ArgumentError.value(value, 'value', 'Unknown field type'),
  );
}

/// Ports 0.1.6 `CustomFieldDefinition`.
class CustomFieldDefinition {
  CustomFieldDefinition({
    required this.id,
    required this.scopeType,
    required this.scopeId,
    required this.fieldName,
    required this.fieldType,
    required this.defaultValue,
    required List<String> enumOptions,
    required this.isRequired,
    required this.isSearchable,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  }) : enumOptions = List.unmodifiable(enumOptions);

  final String id;
  final CustomFieldScope scopeType;

  /// The item category or NPC type id the field belongs to.
  final String scopeId;
  final String fieldName;

  /// Immutable after creation, as in 0.1.6.
  final CustomFieldType fieldType;

  /// Stored as text whatever the field type.
  final String? defaultValue;

  /// `enum_options_json` decoded; empty for non-enum fields.
  final List<String> enumOptions;
  final bool isRequired;
  final bool isSearchable;
  final int sortOrder;

  /// SQLite `datetime('now')` text, as 0.1.6 passes it through.
  final String createdAt;
  final String updatedAt;
}

/// Ports 0.1.6 `CreateCustomFieldDefinitionInput`; the defaults are the ones
/// 0.1.6's repository applies to omitted fields.
class CreateCustomFieldDefinitionInput {
  CreateCustomFieldDefinitionInput({
    required this.scopeType,
    required this.scopeId,
    required this.fieldName,
    required this.fieldType,
    this.defaultValue,
    List<String> enumOptions = const [],
    this.isRequired = false,
    this.isSearchable = false,
    this.sortOrder = 0,
  }) : enumOptions = List.unmodifiable(enumOptions);

  final CustomFieldScope scopeType;
  final String scopeId;
  final String fieldName;
  final CustomFieldType fieldType;
  final String? defaultValue;
  final List<String> enumOptions;
  final bool isRequired;
  final bool isSearchable;
  final int sortOrder;
}

/// Ports 0.1.6 `CustomFieldValue`: one `custom_field_values` row of a record.
///
/// Inside `ItemDraft` and `NpcDraft` the values are held as a map from
/// [fieldDefinitionId] to [value]; this type is the row form for code that
/// needs one.
class CustomFieldValue {
  const CustomFieldValue({
    required this.fieldDefinitionId,
    required this.value,
  });

  final String fieldDefinitionId;

  /// Stored as text whatever the field type; `null` when unset.
  final String? value;

  @override
  bool operator ==(Object other) =>
      other is CustomFieldValue &&
      other.fieldDefinitionId == fieldDefinitionId &&
      other.value == value;

  @override
  int get hashCode => Object.hash(fieldDefinitionId, value);

  @override
  String toString() => 'CustomFieldValue($fieldDefinitionId, $value)';
}
