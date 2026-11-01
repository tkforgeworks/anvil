/// Ability record, create input and draft.
///
/// Ported from the "Abilities" section of 0.1.6's
/// `src/shared/domain-types.ts`.
library;

import 'equality.dart';

/// A list row of the abilities table; ports 0.1.6 `AbilityRecord`.
class AbilityRecord {
  AbilityRecord({
    required this.id,
    required this.displayName,
    required this.exportKey,
    required this.description,
    required this.abilityType,
    required this.resourceType,
    required this.resourceCost,
    required this.cooldown,
    required Map<String, double> statModifiers,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  }) : statModifiers = Map.unmodifiable(statModifiers);

  final String id;
  final String displayName;
  final String exportKey;
  final String description;

  /// Free text in 0.1.6 (`ability_type TEXT NOT NULL DEFAULT ''`), shown in
  /// the list's Type column.
  final String abilityType;

  /// Free text in 0.1.6 (`resource_type TEXT NOT NULL DEFAULT ''`).
  final String resourceType;

  /// `abilities.resource_cost` (REAL).
  final double resourceCost;

  /// `abilities.cooldown` (REAL).
  final double cooldown;

  /// `stat_modifiers_json` decoded: modifier by stat id.
  final Map<String, double> statModifiers;

  /// SQLite `datetime('now')` text, as 0.1.6 passes it through.
  final String createdAt;
  final String updatedAt;

  /// Set when the ability is soft-deleted.
  final String? deletedAt;
}

/// Ports 0.1.6 `CreateAbilityInput`; the defaults are the ones 0.1.6's
/// repository applies to omitted fields.
class CreateAbilityInput {
  CreateAbilityInput({
    required this.displayName,
    required this.exportKey,
    this.description = '',
    this.abilityType = '',
    this.resourceType = '',
    this.resourceCost = 0,
    this.cooldown = 0,
    Map<String, double> statModifiers = const {},
  }) : statModifiers = Map.unmodifiable(statModifiers);

  final String displayName;
  final String exportKey;
  final String description;
  final String abilityType;
  final String resourceType;
  final double resourceCost;
  final double cooldown;
  final Map<String, double> statModifiers;
}

/// The editable value of one ability; ports the fields of 0.1.6
/// `UpdateAbilityInput` (`AbilityRecord` without identity and timestamps).
class AbilityDraft {
  AbilityDraft({
    required this.displayName,
    required this.exportKey,
    this.description = '',
    this.abilityType = '',
    this.resourceType = '',
    this.resourceCost = 0,
    this.cooldown = 0,
    Map<String, double> statModifiers = const {},
  }) : statModifiers = Map.unmodifiable(statModifiers);

  final String displayName;
  final String exportKey;
  final String description;

  /// Free text, as in 0.1.6.
  final String abilityType;

  /// Free text, as in 0.1.6.
  final String resourceType;
  final double resourceCost;
  final double cooldown;

  /// Modifier by stat id (`stat_modifiers_json`).
  final Map<String, double> statModifiers;

  AbilityDraft copyWith({
    String? displayName,
    String? exportKey,
    String? description,
    String? abilityType,
    String? resourceType,
    double? resourceCost,
    double? cooldown,
    Map<String, double>? statModifiers,
  }) => AbilityDraft(
    displayName: displayName ?? this.displayName,
    exportKey: exportKey ?? this.exportKey,
    description: description ?? this.description,
    abilityType: abilityType ?? this.abilityType,
    resourceType: resourceType ?? this.resourceType,
    resourceCost: resourceCost ?? this.resourceCost,
    cooldown: cooldown ?? this.cooldown,
    statModifiers: statModifiers ?? this.statModifiers,
  );

  @override
  bool operator ==(Object other) =>
      other is AbilityDraft &&
      other.displayName == displayName &&
      other.exportKey == exportKey &&
      other.description == description &&
      other.abilityType == abilityType &&
      other.resourceType == resourceType &&
      other.resourceCost == resourceCost &&
      other.cooldown == cooldown &&
      mapEquals(other.statModifiers, statModifiers);

  @override
  int get hashCode => Object.hash(
    displayName,
    exportKey,
    description,
    abilityType,
    resourceType,
    resourceCost,
    cooldown,
    mapHash(statModifiers),
  );

  @override
  String toString() =>
      'AbilityDraft($displayName, $exportKey, $description, $abilityType, '
      '$resourceType, $resourceCost, $cooldown, $statModifiers)';
}
