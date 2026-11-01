/// Meta-layer reference types and the project settings draft.
///
/// Ported from the "Meta-layer reference types" section of 0.1.6's
/// `src/shared/domain-types.ts`.
library;

import 'equality.dart';

/// Ports 0.1.6 `MetaStat`.
class MetaStat {
  const MetaStat({
    required this.id,
    required this.displayName,
    required this.exportKey,
    required this.sortOrder,
  });

  final String id;
  final String displayName;
  final String exportKey;
  final int sortOrder;
}

/// Ports 0.1.6 `MetaRarity`.
class MetaRarity {
  const MetaRarity({
    required this.id,
    required this.displayName,
    required this.exportKey,
    required this.colorHex,
    required this.sortOrder,
  });

  final String id;
  final String displayName;
  final String exportKey;

  /// `rarities.color_hex`, `#RRGGBB` as stored (default `#FFFFFF`).
  final String colorHex;
  final int sortOrder;
}

/// Ports 0.1.6 `MetaItemCategory`.
class MetaItemCategory {
  const MetaItemCategory({
    required this.id,
    required this.displayName,
    required this.exportKey,
    required this.description,
    required this.sortOrder,
  });

  final String id;
  final String displayName;
  final String exportKey;
  final String description;
  final int sortOrder;
}

/// Ports 0.1.6 `MetaNpcType`.
class MetaNpcType {
  const MetaNpcType({
    required this.id,
    required this.displayName,
    required this.exportKey,
    required this.description,
    required this.sortOrder,
  });

  final String id;
  final String displayName;
  final String exportKey;
  final String description;
  final int sortOrder;
}

/// Ports 0.1.6 `MetaCraftingStation`.
class MetaCraftingStation {
  const MetaCraftingStation({
    required this.id,
    required this.displayName,
    required this.exportKey,
    required this.description,
    required this.sortOrder,
  });

  final String id;
  final String displayName;
  final String exportKey;
  final String description;
  final int sortOrder;
}

/// Ports 0.1.6 `MetaCraftingSpecialization`.
class MetaCraftingSpecialization {
  const MetaCraftingSpecialization({
    required this.id,
    required this.displayName,
    required this.exportKey,
    required this.description,
    required this.sortOrder,
  });

  final String id;
  final String displayName;
  final String exportKey;
  final String description;
  final int sortOrder;
}

/// `derived_stat_definitions.output_type`; 0.1.6
/// `DerivedStatDefinition['outputType']`.
enum DerivedStatOutputType {
  integer('integer'),
  float('float');

  const DerivedStatOutputType(this.value);

  /// The string stored in SQLite and used by 0.1.6.
  final String value;

  /// Parses a stored value; throws [ArgumentError] on anything else.
  static DerivedStatOutputType fromValue(String value) => values.firstWhere(
    (e) => e.value == value,
    orElse: () =>
        throw ArgumentError.value(value, 'value', 'Unknown output type'),
  );
}

/// `derived_stat_definitions.rounding_mode`; 0.1.6
/// `DerivedStatDefinition['roundingMode']`.
enum RoundingMode {
  floor('floor'),
  round('round'),
  none('none');

  const RoundingMode(this.value);

  /// The string stored in SQLite and used by 0.1.6.
  final String value;

  /// Parses a stored value; throws [ArgumentError] on anything else.
  static RoundingMode fromValue(String value) => values.firstWhere(
    (e) => e.value == value,
    orElse: () =>
        throw ArgumentError.value(value, 'value', 'Unknown rounding mode'),
  );
}

/// Ports 0.1.6 `DerivedStatDefinition`.
class DerivedStatDefinition {
  const DerivedStatDefinition({
    required this.id,
    required this.displayName,
    required this.exportKey,
    required this.formula,
    required this.outputType,
    required this.roundingMode,
    required this.sortOrder,
  });

  final String id;
  final String displayName;
  final String exportKey;
  final String formula;
  final DerivedStatOutputType outputType;
  final RoundingMode roundingMode;
  final int sortOrder;
}

/// Ports 0.1.6 `MetaItemInput`: add/update input for stats, item categories,
/// NPC types, crafting stations and crafting specializations.
class MetaItemInput {
  const MetaItemInput({required this.displayName, required this.exportKey});

  final String displayName;
  final String exportKey;
}

/// Ports 0.1.6 `MetaRarityInput`.
class MetaRarityInput {
  const MetaRarityInput({
    required this.displayName,
    required this.exportKey,
    required this.colorHex,
  });

  final String displayName;
  final String exportKey;
  final String colorHex;
}

/// Ports 0.1.6 `DerivedStatInput`.
class DerivedStatInput {
  const DerivedStatInput({
    required this.displayName,
    required this.exportKey,
    required this.formula,
    required this.outputType,
    required this.roundingMode,
  });

  final String displayName;
  final String exportKey;
  final String formula;
  final DerivedStatOutputType outputType;
  final RoundingMode roundingMode;
}

/// Ports 0.1.6 `MetaInUseKind`: the meta lists whose rows domain records can
/// reference, for `checkInUse(kind, id)`.
enum MetaInUseKind {
  stat('stat'),
  rarity('rarity'),
  itemCategory('item-category'),
  npcType('npc-type'),
  craftingStation('crafting-station'),
  craftingSpecialization('crafting-specialization'),
  derivedStat('derived-stat');

  const MetaInUseKind(this.value);

  /// The 0.1.6 string.
  final String value;
}

/// `project_info.soft_delete_reference_severity`; 0.1.6
/// `ProjectSettings['softDeleteReferenceSeverity']`.
enum SoftDeleteReferenceSeverity {
  warning('Warning'),
  error('Error');

  const SoftDeleteReferenceSeverity(this.value);

  /// The string stored in SQLite (capitalised, as the `CHECK` requires).
  final String value;

  /// Parses a stored value; throws [ArgumentError] on anything else.
  static SoftDeleteReferenceSeverity fromValue(String value) =>
      values.firstWhere(
        (e) => e.value == value,
        orElse: () =>
            throw ArgumentError.value(value, 'value', 'Unknown severity'),
      );
}

/// Prefix of the client-side id a buffered meta row carries until the save
/// that inserts it assigns its real id (0.1.6 `meta-buffer.ts`, `new:`).
const String newMetaIdPrefix = 'new:';

/// Whether [id] marks a buffered row that is not in the database yet.
bool isNewMetaId(String id) => id.startsWith(newMetaIdPrefix);

/// One row of a buffered stats, crafting stations or crafting
/// specializations list: the fields 0.1.6 edits through `MetaItemInput`.
/// Its position in the list is its `sort_order`.
class MetaRowDraft {
  const MetaRowDraft({
    required this.id,
    required this.displayName,
    required this.exportKey,
  });

  /// The row's id, or a `new:` id ([isNewMetaId]) for a row added in this
  /// session.
  final String id;
  final String displayName;
  final String exportKey;

  MetaRowDraft copyWith({String? id, String? displayName, String? exportKey}) =>
      MetaRowDraft(
        id: id ?? this.id,
        displayName: displayName ?? this.displayName,
        exportKey: exportKey ?? this.exportKey,
      );

  @override
  bool operator ==(Object other) =>
      other is MetaRowDraft &&
      other.id == id &&
      other.displayName == displayName &&
      other.exportKey == exportKey;

  @override
  int get hashCode => Object.hash(id, displayName, exportKey);

  @override
  String toString() => 'MetaRowDraft($id, $displayName, $exportKey)';
}

/// One row of the buffered rarities list (0.1.6 `MetaRarityInput` plus id).
class RarityRowDraft {
  const RarityRowDraft({
    required this.id,
    required this.displayName,
    required this.exportKey,
    required this.colorHex,
  });

  final String id;
  final String displayName;
  final String exportKey;
  final String colorHex;

  RarityRowDraft copyWith({
    String? id,
    String? displayName,
    String? exportKey,
    String? colorHex,
  }) => RarityRowDraft(
    id: id ?? this.id,
    displayName: displayName ?? this.displayName,
    exportKey: exportKey ?? this.exportKey,
    colorHex: colorHex ?? this.colorHex,
  );

  @override
  bool operator ==(Object other) =>
      other is RarityRowDraft &&
      other.id == id &&
      other.displayName == displayName &&
      other.exportKey == exportKey &&
      other.colorHex == colorHex;

  @override
  int get hashCode => Object.hash(id, displayName, exportKey, colorHex);

  @override
  String toString() =>
      'RarityRowDraft($id, $displayName, $exportKey, $colorHex)';
}

/// One row of the buffered derived stat definitions list (0.1.6
/// `DerivedStatInput` plus id).
class DerivedStatRowDraft {
  const DerivedStatRowDraft({
    required this.id,
    required this.displayName,
    required this.exportKey,
    required this.formula,
    required this.outputType,
    required this.roundingMode,
  });

  final String id;
  final String displayName;
  final String exportKey;
  final String formula;
  final DerivedStatOutputType outputType;
  final RoundingMode roundingMode;

  DerivedStatRowDraft copyWith({
    String? id,
    String? displayName,
    String? exportKey,
    String? formula,
    DerivedStatOutputType? outputType,
    RoundingMode? roundingMode,
  }) => DerivedStatRowDraft(
    id: id ?? this.id,
    displayName: displayName ?? this.displayName,
    exportKey: exportKey ?? this.exportKey,
    formula: formula ?? this.formula,
    outputType: outputType ?? this.outputType,
    roundingMode: roundingMode ?? this.roundingMode,
  );

  @override
  bool operator ==(Object other) =>
      other is DerivedStatRowDraft &&
      other.id == id &&
      other.displayName == displayName &&
      other.exportKey == exportKey &&
      other.formula == formula &&
      other.outputType == outputType &&
      other.roundingMode == roundingMode;

  @override
  int get hashCode => Object.hash(
    id,
    displayName,
    exportKey,
    formula,
    outputType,
    roundingMode,
  );

  @override
  String toString() =>
      'DerivedStatRowDraft($id, $displayName, $exportKey, $formula, '
      '${outputType.value}, ${roundingMode.value})';
}

/// The editable value of the Project Settings dialog.
///
/// Ports 0.1.6 `ProjectSettings` (game title, max level, soft-delete
/// reference severity) plus the five meta lists that 0.1.6's
/// `ProjectSettingsModal` buffers in `MetaBuffers` and commits on one Save
/// (ANVL-121). Item categories and NPC types are not here: they live on the
/// Custom Fields tab, which persists immediately, as in 0.1.6. Each list's
/// order is its `sort_order`.
class ProjectSettingsDraft {
  ProjectSettingsDraft({
    required this.gameTitle,
    required this.maxLevel,
    required this.softDeleteReferenceSeverity,
    List<MetaRowDraft> stats = const [],
    List<RarityRowDraft> rarities = const [],
    List<MetaRowDraft> craftingStations = const [],
    List<MetaRowDraft> craftingSpecializations = const [],
    List<DerivedStatRowDraft> derivedStats = const [],
  }) : stats = List.unmodifiable(stats),
       rarities = List.unmodifiable(rarities),
       craftingStations = List.unmodifiable(craftingStations),
       craftingSpecializations = List.unmodifiable(craftingSpecializations),
       derivedStats = List.unmodifiable(derivedStats);

  /// `project_info.game_title`.
  final String gameTitle;

  /// `project_info.max_level`.
  final int maxLevel;

  /// `project_info.soft_delete_reference_severity`.
  final SoftDeleteReferenceSeverity softDeleteReferenceSeverity;

  final List<MetaRowDraft> stats;
  final List<RarityRowDraft> rarities;
  final List<MetaRowDraft> craftingStations;
  final List<MetaRowDraft> craftingSpecializations;
  final List<DerivedStatRowDraft> derivedStats;

  ProjectSettingsDraft copyWith({
    String? gameTitle,
    int? maxLevel,
    SoftDeleteReferenceSeverity? softDeleteReferenceSeverity,
    List<MetaRowDraft>? stats,
    List<RarityRowDraft>? rarities,
    List<MetaRowDraft>? craftingStations,
    List<MetaRowDraft>? craftingSpecializations,
    List<DerivedStatRowDraft>? derivedStats,
  }) => ProjectSettingsDraft(
    gameTitle: gameTitle ?? this.gameTitle,
    maxLevel: maxLevel ?? this.maxLevel,
    softDeleteReferenceSeverity:
        softDeleteReferenceSeverity ?? this.softDeleteReferenceSeverity,
    stats: stats ?? this.stats,
    rarities: rarities ?? this.rarities,
    craftingStations: craftingStations ?? this.craftingStations,
    craftingSpecializations:
        craftingSpecializations ?? this.craftingSpecializations,
    derivedStats: derivedStats ?? this.derivedStats,
  );

  @override
  bool operator ==(Object other) =>
      other is ProjectSettingsDraft &&
      other.gameTitle == gameTitle &&
      other.maxLevel == maxLevel &&
      other.softDeleteReferenceSeverity == softDeleteReferenceSeverity &&
      listEquals(other.stats, stats) &&
      listEquals(other.rarities, rarities) &&
      listEquals(other.craftingStations, craftingStations) &&
      listEquals(other.craftingSpecializations, craftingSpecializations) &&
      listEquals(other.derivedStats, derivedStats);

  @override
  int get hashCode => Object.hash(
    gameTitle,
    maxLevel,
    softDeleteReferenceSeverity,
    listHash(stats),
    listHash(rarities),
    listHash(craftingStations),
    listHash(craftingSpecializations),
    listHash(derivedStats),
  );

  @override
  String toString() =>
      'ProjectSettingsDraft($gameTitle, $maxLevel, '
      '${softDeleteReferenceSeverity.value}, stats: $stats, '
      'rarities: $rarities, craftingStations: $craftingStations, '
      'craftingSpecializations: $craftingSpecializations, '
      'derivedStats: $derivedStats)';
}
