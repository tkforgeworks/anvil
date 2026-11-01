import 'package:meta/meta.dart';

import '../db/project_database.dart';
import '../repositories/ability_repository.dart';
import '../repositories/class_repository.dart';
import '../repositories/custom_field_repository.dart';
import '../repositories/item_repository.dart';
import '../repositories/lifecycle_repository.dart';
import '../repositories/loot_table_repository.dart';
import '../repositories/meta_repository.dart';
import '../repositories/npc_repository.dart';
import '../repositories/recipe_repository.dart';
import '../repositories/save_history_repository.dart';
import '../repositories/sqlite_ability_repository.dart';
import '../repositories/sqlite_class_repository.dart';
import '../repositories/sqlite_custom_field_repository.dart';
import '../repositories/sqlite_item_repository.dart';
import '../repositories/sqlite_lifecycle_repository.dart';
import '../repositories/sqlite_loot_table_repository.dart';
import '../repositories/sqlite_meta_repository.dart';
import '../repositories/sqlite_npc_repository.dart';
import '../repositories/sqlite_recipe_repository.dart';
import '../repositories/sqlite_save_history_repository.dart';
import '../repositories/sqlite_template_repository.dart';
import '../repositories/template_repository.dart';
import 'project_lock.dart';
import 'project_metadata.dart';

/// One open project: its metadata, its read-write [ProjectDatabase] and one
/// instance of every repository interface over that database (design
/// §6.6).
///
/// Made only by `ProjectService` (`create`, `open`, `upgradeCopy`,
/// `saveAs`) and closed only through `ProjectService.close`, which also
/// releases the lock. The repositories are only usable while [isOpen].
final class ProjectSession {
  @internal
  ProjectSession(this.metadata, this.database, this.lock)
    : classes = SqliteClassRepository(database),
      abilities = SqliteAbilityRepository(database),
      items = SqliteItemRepository(database),
      recipes = SqliteRecipeRepository(database),
      npcs = SqliteNpcRepository(database),
      lootTables = SqliteLootTableRepository(database),
      meta = SqliteMetaRepository(database),
      customFields = SqliteCustomFieldRepository(database),
      templates = SqliteTemplateRepository(database),
      saveHistory = SqliteSaveHistoryRepository(database),
      lifecycle = SqliteLifecycleRepository(database);

  /// The metadata as read when the session was opened.
  final ProjectMetadata metadata;

  /// The project's read-write connection on the UI isolate.
  final ProjectDatabase database;

  /// The lock held for [filePath] while the session is open.
  @internal
  final ProjectLock lock;

  final ClassRepository classes;
  final AbilityRepository abilities;
  final ItemRepository items;
  final RecipeRepository recipes;
  final NpcRepository npcs;
  final LootTableRepository lootTables;
  final MetaRepository meta;
  final CustomFieldRepository customFields;
  final TemplateRepository templates;
  final SaveHistoryRepository saveHistory;
  final LifecycleRepository lifecycle;

  String get filePath => metadata.filePath;

  bool get isOpen => database.isOpen;
}
