/// NPC record, create input and draft.
///
/// Ported from the "NPCs" section of 0.1.6's `src/shared/domain-types.ts`.
library;

import 'equality.dart';

/// A list row of the NPCs table; ports 0.1.6 `NpcRecord`.
class NpcRecord {
  NpcRecord({
    required this.id,
    required this.displayName,
    required this.exportKey,
    required this.description,
    required this.npcTypeId,
    required this.lootTableId,
    required Map<String, double?> combatStats,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  }) : combatStats = Map.unmodifiable(combatStats);

  final String id;
  final String displayName;
  final String exportKey;
  final String description;
  final String npcTypeId;
  final String? lootTableId;

  /// `combat_stats_json` decoded: stat override by stat id.
  final Map<String, double?> combatStats;

  /// SQLite `datetime('now')` text, as 0.1.6 passes it through.
  final String createdAt;
  final String updatedAt;

  /// Set when the NPC is soft-deleted.
  final String? deletedAt;
}

/// Ports 0.1.6 `CreateNpcInput`; the defaults are the ones 0.1.6's
/// repository applies to omitted fields.
class CreateNpcInput {
  CreateNpcInput({
    required this.displayName,
    required this.exportKey,
    this.description = '',
    required this.npcTypeId,
    this.lootTableId,
    Map<String, double?> combatStats = const {},
  }) : combatStats = Map.unmodifiable(combatStats);

  final String displayName;
  final String exportKey;
  final String description;
  final String npcTypeId;
  final String? lootTableId;
  final Map<String, double?> combatStats;
}

/// Ports 0.1.6 `NpcClassAssignment` without its `sortOrder`, which is the
/// assignment's index in [NpcDraft.classAssignments].
class NpcClassAssignment {
  const NpcClassAssignment({required this.classId, required this.level});

  final String classId;

  /// The level the NPC has in this class (`CHECK (level > 0)`).
  final int level;

  NpcClassAssignment copyWith({String? classId, int? level}) =>
      NpcClassAssignment(
        classId: classId ?? this.classId,
        level: level ?? this.level,
      );

  @override
  bool operator ==(Object other) =>
      other is NpcClassAssignment &&
      other.classId == classId &&
      other.level == level;

  @override
  int get hashCode => Object.hash(classId, level);

  @override
  String toString() => 'NpcClassAssignment($classId, $level)';
}

/// The editable value of one NPC; ports the fields of 0.1.6
/// `UpdateNpcInput` plus the junction data its editor loaded and saved
/// separately: `NpcClassAssignment`, `NpcAbilityAssignment` and its
/// `CustomFieldValue` rows.
class NpcDraft {
  NpcDraft({
    required this.displayName,
    required this.exportKey,
    this.description = '',
    required this.npcTypeId,
    this.lootTableId,
    Map<String, double?> combatStats = const {},
    List<NpcClassAssignment> classAssignments = const [],
    List<String> abilityIds = const [],
    Map<String, String?> customFieldValues = const {},
  }) : combatStats = Map.unmodifiable(combatStats),
       classAssignments = List.unmodifiable(classAssignments),
       abilityIds = List.unmodifiable(abilityIds),
       customFieldValues = Map.unmodifiable(customFieldValues);

  final String displayName;
  final String exportKey;
  final String description;
  final String npcTypeId;
  final String? lootTableId;

  /// Combat stat overrides by stat id (`combat_stats_json`). A key mapped to
  /// `null` is kept as 0.1.6 stores it and means no override; 0.1.6's editor
  /// removes the key when an override is cleared.
  final Map<String, double?> combatStats;

  /// Class assignments in order; the index is the `sort_order`.
  final List<NpcClassAssignment> classAssignments;

  /// Assigned ability ids (`npc_ability_assignments`); the index is the
  /// `sort_order`.
  final List<String> abilityIds;

  /// Type-scoped custom field values by field definition id; values are
  /// text whatever the field type, `null` when unset.
  final Map<String, String?> customFieldValues;

  /// Pass `null` for [lootTableId] to clear it; omit it to keep the current
  /// value.
  NpcDraft copyWith({
    String? displayName,
    String? exportKey,
    String? description,
    String? npcTypeId,
    Object? lootTableId = unset,
    Map<String, double?>? combatStats,
    List<NpcClassAssignment>? classAssignments,
    List<String>? abilityIds,
    Map<String, String?>? customFieldValues,
  }) => NpcDraft(
    displayName: displayName ?? this.displayName,
    exportKey: exportKey ?? this.exportKey,
    description: description ?? this.description,
    npcTypeId: npcTypeId ?? this.npcTypeId,
    lootTableId: identical(lootTableId, unset)
        ? this.lootTableId
        : lootTableId as String?,
    combatStats: combatStats ?? this.combatStats,
    classAssignments: classAssignments ?? this.classAssignments,
    abilityIds: abilityIds ?? this.abilityIds,
    customFieldValues: customFieldValues ?? this.customFieldValues,
  );

  @override
  bool operator ==(Object other) =>
      other is NpcDraft &&
      other.displayName == displayName &&
      other.exportKey == exportKey &&
      other.description == description &&
      other.npcTypeId == npcTypeId &&
      other.lootTableId == lootTableId &&
      mapEquals(other.combatStats, combatStats) &&
      listEquals(other.classAssignments, classAssignments) &&
      listEquals(other.abilityIds, abilityIds) &&
      mapEquals(other.customFieldValues, customFieldValues);

  @override
  int get hashCode => Object.hash(
    displayName,
    exportKey,
    description,
    npcTypeId,
    lootTableId,
    mapHash(combatStats),
    listHash(classAssignments),
    listHash(abilityIds),
    mapHash(customFieldValues),
  );

  @override
  String toString() =>
      'NpcDraft($displayName, $exportKey, $description, $npcTypeId, '
      '$lootTableId, combatStats: $combatStats, '
      'classAssignments: $classAssignments, abilityIds: $abilityIds, '
      'customFieldValues: $customFieldValues)';
}
