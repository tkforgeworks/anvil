import '../../domain/meta.dart';

/// The meta layer a `ProjectTemplate` seeds into a new project.
///
/// Rows carry the three-part identity (internal id, display name, export
/// key) and their sort order; ids follow migration 002's style
/// (`stat-<name>`, `rarity-<name>`, `item-category-<name>`, …) and export
/// keys match `^[a-z0-9_-]+$`. Derived stat formulas name stats by export
/// key, as the formula engine binds them.
///
/// A content that [isEmpty] changes nothing; any other content replaces
/// every row of all seven meta tables and sets `project_info.max_level`
/// when [maxLevel] is given.
class ProjectTemplateContent {
  const ProjectTemplateContent({
    this.stats = const [],
    this.rarities = const [],
    this.itemCategories = const [],
    this.npcTypes = const [],
    this.craftingStations = const [],
    this.craftingSpecializations = const [],
    this.derivedStats = const [],
    this.maxLevel,
  });

  /// Keeps what the migrations seeded.
  static const empty = ProjectTemplateContent();

  final List<MetaStat> stats;
  final List<MetaRarity> rarities;

  /// The description is stored; the templates leave it empty as migration
  /// 002 did.
  final List<MetaItemCategory> itemCategories;
  final List<MetaNpcType> npcTypes;
  final List<MetaCraftingStation> craftingStations;
  final List<MetaCraftingSpecialization> craftingSpecializations;
  final List<DerivedStatDefinition> derivedStats;

  /// `project_info.max_level`, or null to keep migration 002's 50.
  final int? maxLevel;

  bool get isEmpty =>
      stats.isEmpty &&
      rarities.isEmpty &&
      itemCategories.isEmpty &&
      npcTypes.isEmpty &&
      craftingStations.isEmpty &&
      craftingSpecializations.isEmpty &&
      derivedStats.isEmpty &&
      maxLevel == null;
}
