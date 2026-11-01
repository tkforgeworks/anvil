import '../domain/custom_fields.dart';
import '../domain/equality.dart' show unset;

/// Ports 0.1.6 `UpdateCustomFieldDefinitionInput`: every field is optional
/// and an omitted one keeps its stored value. There is no field type, which
/// is immutable after creation.
class UpdateCustomFieldDefinitionInput {
  /// Pass `defaultValue: null` to clear the default; omit it to keep it.
  UpdateCustomFieldDefinitionInput({
    this.fieldName,
    Object? defaultValue = unset,
    List<String>? enumOptions,
    this.isRequired,
    this.isSearchable,
    this.sortOrder,
  }) : _defaultValue = defaultValue,
       enumOptions = enumOptions == null
           ? null
           : List.unmodifiable(enumOptions) {
    if (!identical(defaultValue, unset) && defaultValue is! String?) {
      throw ArgumentError.value(
        defaultValue,
        'defaultValue',
        'Must be a String or null',
      );
    }
  }

  final String? fieldName;
  final Object? _defaultValue;
  final List<String>? enumOptions;
  final bool? isRequired;
  final bool? isSearchable;
  final int? sortOrder;

  /// Whether this input sets the default value (possibly to null).
  bool get setsDefaultValue => !identical(_defaultValue, unset);

  /// The new default value; meaningful only when [setsDefaultValue].
  String? get defaultValue =>
      setsDefaultValue ? _defaultValue as String? : null;
}

/// Custom field definitions: replaces 0.1.6's four `custom-fields:*`
/// definition channels (`custom-field-definition.repository.ts`). Values
/// belong to the item and NPC repositories.
///
/// Mutations are one save transaction each, recorded as
/// `Custom field definitions changed`.
abstract interface class CustomFieldRepository {
  /// Ordered by `sort_order`, then field name ignoring case.
  Future<List<CustomFieldDefinition>> listDefinitions(
    CustomFieldScope scopeType,
    String scopeId,
  );

  /// Throws `RecordNotFound('custom_field_definitions', id)`.
  Future<CustomFieldDefinition> getDefinition(String id);

  /// Stores no enum options as `NULL`. A field name already used in the
  /// same scope throws `SaveFailed` (the `UNIQUE` constraint).
  Future<CustomFieldDefinition> createDefinition(
    CreateCustomFieldDefinitionInput input,
  );

  /// Keeps the field type. Removing enum options that stored values still
  /// use throws `SaveBlocked(['Cannot remove enum option(s) that are in
  /// use: a, b'])` and changes nothing. Throws `RecordNotFound` for an
  /// unknown id.
  Future<CustomFieldDefinition> updateDefinition(
    String id,
    UpdateCustomFieldDefinitionInput input,
  );

  /// Refused with `SaveBlocked` while any record has a non-empty value for
  /// the field, as 0.1.6 refused it; otherwise deletes the definition, and
  /// the schema's `ON DELETE CASCADE` removes its remaining (empty) value
  /// rows. Throws `RecordNotFound` for an unknown id.
  Future<void> deleteDefinition(String id);

  /// Records holding a non-empty value for the field.
  Future<int> valueCount(String id);

  /// The distinct non-empty values stored for the field.
  Future<List<String>> usedEnumValues(String id);
}
