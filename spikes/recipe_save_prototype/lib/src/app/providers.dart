/// Riverpod 3 providers, hand-written (no riverpod_generator).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/project_database.dart';
import '../core/recipe_repository.dart';
import '../core/sqlite_recipe_repository.dart';

/// The open project. Overridden at the root (main.dart, tests); there is
/// exactly one per app run.
final projectDatabaseProvider = Provider<ProjectDatabase>(
  (ref) => throw UnimplementedError('override projectDatabaseProvider'),
);

/// Debug toggle: make the next saves fail right before COMMIT.
final forceSaveFailureProvider = NotifierProvider<ForceSaveFailure, bool>(
  ForceSaveFailure.new,
);

class ForceSaveFailure extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// Editors depend on this interface only.
///
/// It must not `watch` anything that changes while editing (the debug toggle
/// is read lazily by the fault hook instead): a rebuild here would rebuild
/// every editor notifier that watches it and throw their drafts away.
final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  final project = ref.watch(projectDatabaseProvider);
  project.debugFailBeforeCommit = () => ref.read(forceSaveFailureProvider);
  return SqliteRecipeRepository(project);
});

final saveHistoryProvider = FutureProvider.autoDispose<List<SaveHistoryEntry>>(
  (ref) => ref.watch(projectDatabaseProvider).recentSaves(),
);

final recipeListProvider = FutureProvider.autoDispose<List<RecipeSummary>>(
  (ref) => ref.watch(recipeRepositoryProvider).listRecipes(),
);

final recipeLookupsProvider = FutureProvider.autoDispose<RecipeLookups>(
  (ref) => ref.watch(recipeRepositoryProvider).loadLookups(),
);

/// Wall clock for undo coalescing; tests override it.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
