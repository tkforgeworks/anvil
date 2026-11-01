import 'm001_init.dart';
import 'm002_seed_meta_layer.dart';
import 'm003_class_overrides_and_metadata.dart';
import 'm004_ability_resource_type.dart';
import 'm005_custom_templates.dart';
import 'm006_stat_growth_formulas.dart';
import 'm007_save_history.dart';
import 'migration.dart';

/// All migrations in version order, as `MIGRATIONS` in `runner.ts`.
///
/// A new migration is `008_...` in both the filename and the Dart file, and
/// ends two-way compatibility with 0.1.6, so it is a decision for its own
/// ticket.
const List<Migration> allMigrations = [
  m001Init,
  m002SeedMetaLayer,
  m003ClassOverridesAndMetadata,
  m004AbilityResourceType,
  m005CustomTemplates,
  m006StatGrowthFormulas,
  m007SaveHistory,
];

/// `CURRENT_SCHEMA_VERSION` in `runner.ts`: the number of migrations, written
/// to `project_info.schema_version` after any migration runs.
const int currentSchemaVersion = 7;
