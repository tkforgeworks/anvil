/// Character class record, create input and draft.
///
/// Ported from the "Character Classes" section of 0.1.6's
/// `src/shared/domain-types.ts`, with `ClassDerivedStatOverride` and
/// `ClassMetadataField` from its meta section.
library;

import 'equality.dart';

/// A list row of the classes table; ports 0.1.6 `ClassRecord`.
class ClassRecord {
  const ClassRecord({
    required this.id,
    required this.displayName,
    required this.exportKey,
    required this.description,
    required this.resourceMultiplier,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  final String id;
  final String displayName;
  final String exportKey;
  final String description;

  /// `classes.resource_multiplier` (REAL).
  final double resourceMultiplier;

  /// SQLite `datetime('now')` text, as 0.1.6 passes it through.
  final String createdAt;
  final String updatedAt;

  /// Set when the class is soft-deleted.
  final String? deletedAt;
}

/// Ports 0.1.6 `CreateClassInput`; the defaults are the ones 0.1.6's
/// repository applies to omitted fields.
class CreateClassInput {
  const CreateClassInput({
    required this.displayName,
    required this.exportKey,
    this.description = '',
    this.resourceMultiplier = 1,
  });

  final String displayName;
  final String exportKey;
  final String description;
  final double resourceMultiplier;
}

/// The key of a manual stat growth entry: `class_stat_growth`'s
/// `(stat_id, level)` within one class. 0.1.6 `StatGrowthEntry` without its
/// value.
class StatGrowthKey {
  const StatGrowthKey(this.statId, this.level);

  final String statId;

  /// 1-based level (`CHECK (level > 0)`).
  final int level;

  @override
  bool operator ==(Object other) =>
      other is StatGrowthKey && other.statId == statId && other.level == level;

  @override
  int get hashCode => Object.hash(statId, level);

  @override
  String toString() => 'StatGrowthKey($statId, $level)';
}

/// Ports 0.1.6 `ClassMetadataField`: a named number a class exposes to its
/// derived stat formulas.
class ClassMetadataField {
  const ClassMetadataField({required this.fieldKey, required this.value});

  /// Must match `^[a-zA-Z_][a-zA-Z0-9_]*$` to save; a draft may hold any text
  /// while the user types.
  final String fieldKey;

  /// `class_metadata_fields.value` (REAL).
  final double value;

  ClassMetadataField copyWith({String? fieldKey, double? value}) =>
      ClassMetadataField(
        fieldKey: fieldKey ?? this.fieldKey,
        value: value ?? this.value,
      );

  @override
  bool operator ==(Object other) =>
      other is ClassMetadataField &&
      other.fieldKey == fieldKey &&
      other.value == value;

  @override
  int get hashCode => Object.hash(fieldKey, value);

  @override
  String toString() => 'ClassMetadataField($fieldKey, $value)';
}

/// The editable value of one character class.
///
/// Ports 0.1.6 `ClassRecord`'s editable fields (`UpdateClassInput`) together
/// with the junction data the class editor loaded and saved separately:
/// `StatGrowthEntry` (manual entries), `StatGrowthFormula`,
/// `ClassAbilityAssignment`, `ClassDerivedStatOverride` and
/// `ClassMetadataField`.
class ClassDraft {
  ClassDraft({
    required this.displayName,
    required this.exportKey,
    this.description = '',
    this.resourceMultiplier = 1,
    Map<StatGrowthKey, double> statGrowth = const {},
    Map<String, String> statGrowthFormulas = const {},
    List<String> abilityIds = const [],
    Map<String, String> derivedStatOverrides = const {},
    List<ClassMetadataField> metadataFields = const [],
  }) : statGrowth = Map.unmodifiable(statGrowth),
       statGrowthFormulas = Map.unmodifiable(statGrowthFormulas),
       abilityIds = List.unmodifiable(abilityIds),
       derivedStatOverrides = Map.unmodifiable(derivedStatOverrides),
       metadataFields = List.unmodifiable(metadataFields);

  final String displayName;
  final String exportKey;
  final String description;
  final double resourceMultiplier;

  /// Manual stat growth values (`class_stat_growth`) by stat and level.
  /// Entries for a stat in [statGrowthFormulas] are kept as stored; 0.1.6
  /// ignores them while the stat is in formula mode.
  final Map<StatGrowthKey, double> statGrowth;

  /// Stat growth formulas (`class_stat_growth_formulas`) by stat id. A stat
  /// with a formula is in formula mode.
  final Map<String, String> statGrowthFormulas;

  /// Assigned ability ids (`class_ability_assignments`); the index is the
  /// `sort_order`.
  final List<String> abilityIds;

  /// Per-class formula overrides (`class_derived_stat_overrides`) by derived
  /// stat id.
  final Map<String, String> derivedStatOverrides;

  /// Metadata fields (`class_metadata_fields`) as the editor's rows, in
  /// order. A list, not a map, because 0.1.6 edits them as rows that may be
  /// blank, invalid or repeated until save; the repository reads them back
  /// ordered by `field_key`.
  final List<ClassMetadataField> metadataFields;

  ClassDraft copyWith({
    String? displayName,
    String? exportKey,
    String? description,
    double? resourceMultiplier,
    Map<StatGrowthKey, double>? statGrowth,
    Map<String, String>? statGrowthFormulas,
    List<String>? abilityIds,
    Map<String, String>? derivedStatOverrides,
    List<ClassMetadataField>? metadataFields,
  }) => ClassDraft(
    displayName: displayName ?? this.displayName,
    exportKey: exportKey ?? this.exportKey,
    description: description ?? this.description,
    resourceMultiplier: resourceMultiplier ?? this.resourceMultiplier,
    statGrowth: statGrowth ?? this.statGrowth,
    statGrowthFormulas: statGrowthFormulas ?? this.statGrowthFormulas,
    abilityIds: abilityIds ?? this.abilityIds,
    derivedStatOverrides: derivedStatOverrides ?? this.derivedStatOverrides,
    metadataFields: metadataFields ?? this.metadataFields,
  );

  @override
  bool operator ==(Object other) =>
      other is ClassDraft &&
      other.displayName == displayName &&
      other.exportKey == exportKey &&
      other.description == description &&
      other.resourceMultiplier == resourceMultiplier &&
      mapEquals(other.statGrowth, statGrowth) &&
      mapEquals(other.statGrowthFormulas, statGrowthFormulas) &&
      listEquals(other.abilityIds, abilityIds) &&
      mapEquals(other.derivedStatOverrides, derivedStatOverrides) &&
      listEquals(other.metadataFields, metadataFields);

  @override
  int get hashCode => Object.hash(
    displayName,
    exportKey,
    description,
    resourceMultiplier,
    mapHash(statGrowth),
    mapHash(statGrowthFormulas),
    listHash(abilityIds),
    mapHash(derivedStatOverrides),
    listHash(metadataFields),
  );

  @override
  String toString() =>
      'ClassDraft($displayName, $exportKey, $description, '
      '$resourceMultiplier, statGrowth: $statGrowth, '
      'statGrowthFormulas: $statGrowthFormulas, abilityIds: $abilityIds, '
      'derivedStatOverrides: $derivedStatOverrides, '
      'metadataFields: $metadataFields)';
}
