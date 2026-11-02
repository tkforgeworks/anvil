/// The providers behind the shell (design §6.6, §8.1, §10.2): the open
/// session as a non-null value, one provider per repository interface over
/// it, the write epoch that refreshes counts and badges, the sidebar's
/// counts and badges, and the sidebar's collapsed state.
///
/// Everything here watches `projectSessionProvider`, directly or through
/// [requireSessionProvider], so replacing or clearing the session disposes
/// and rebuilds all of it, and with it anything an editor built on top.
library;

import 'dart:async';

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// The open project. Throws [StateError] when none is open, so only widgets
/// inside the shell (which the router shows only while a session exists)
/// and providers they read may watch it.
final requireSessionProvider = Provider<ProjectSession>((ref) {
  final session = ref.watch(projectSessionProvider);
  if (session == null) {
    throw StateError('No project is open; the shell needs a session.');
  }
  return session;
});

final classRepositoryProvider = Provider<ClassRepository>(
  (ref) => ref.watch(requireSessionProvider).classes,
);

final abilityRepositoryProvider = Provider<AbilityRepository>(
  (ref) => ref.watch(requireSessionProvider).abilities,
);

final itemRepositoryProvider = Provider<ItemRepository>(
  (ref) => ref.watch(requireSessionProvider).items,
);

final recipeRepositoryProvider = Provider<RecipeRepository>(
  (ref) => ref.watch(requireSessionProvider).recipes,
);

final npcRepositoryProvider = Provider<NpcRepository>(
  (ref) => ref.watch(requireSessionProvider).npcs,
);

final lootTableRepositoryProvider = Provider<LootTableRepository>(
  (ref) => ref.watch(requireSessionProvider).lootTables,
);

final metaRepositoryProvider = Provider<MetaRepository>(
  (ref) => ref.watch(requireSessionProvider).meta,
);

final customFieldRepositoryProvider = Provider<CustomFieldRepository>(
  (ref) => ref.watch(requireSessionProvider).customFields,
);

final templateRepositoryProvider = Provider<TemplateRepository>(
  (ref) => ref.watch(requireSessionProvider).templates,
);

final saveHistoryRepositoryProvider = Provider<SaveHistoryRepository>(
  (ref) => ref.watch(requireSessionProvider).saveHistory,
);

final lifecycleRepositoryProvider = Provider<LifecycleRepository>(
  (ref) => ref.watch(requireSessionProvider).lifecycle,
);

/// A counter of completed writes to the open project.
///
/// **Contract:** every code path in the app that writes to the project
/// through a repository (an editor save, a create, duplicate, soft delete,
/// restore or hard delete, a bulk operation, Empty Trash, a project
/// settings or custom field change) calls
/// `ref.read(writeEpochProvider.notifier).bump()` once after the write
/// returns, whether or not it changed anything. [recordCountsProvider] and
/// [trashCountProvider] watch it and re-read; [validationIssuesProvider]
/// listens and re-runs the project pass after a debounce. This replaces
/// 0.1.6's two-second polling of the project state and trash count
/// (`AppShell.tsx`).
final writeEpochProvider = NotifierProvider<WriteEpochNotifier, int>(
  WriteEpochNotifier.new,
);

class WriteEpochNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Records that a write completed.
  void bump() => state++;
}

/// Active records per domain, for the sidebar and the dashboard.
final recordCountsProvider = FutureProvider<RecordCounts>((ref) async {
  ref.watch(writeEpochProvider);
  final classes = ref.watch(classRepositoryProvider).countActive();
  final abilities = ref.watch(abilityRepositoryProvider).countActive();
  final items = ref.watch(itemRepositoryProvider).countActive();
  final recipes = ref.watch(recipeRepositoryProvider).countActive();
  final npcs = ref.watch(npcRepositoryProvider).countActive();
  final lootTables = ref.watch(lootTableRepositoryProvider).countActive();
  return RecordCounts(
    classes: await classes,
    abilities: await abilities,
    items: await items,
    recipes: await recipes,
    npcs: await npcs,
    lootTables: await lootTables,
  );
});

/// Soft-deleted records across the six domains: the Recycle Bin badge.
/// `LifecycleRepository.countDeleted` answers per domain; 0.1.6's
/// `lifecycle:count-deleted` returned only this total.
final trashCountProvider = FutureProvider<int>((ref) async {
  ref.watch(writeEpochProvider);
  final c = await ref.watch(lifecycleRepositoryProvider).countDeleted();
  return c.classes + c.abilities + c.items + c.recipes + c.npcs + c.lootTables;
});

/// The project-wide validation issues (design §10.2): the sidebar badge
/// and the Validation page read the same list.
final validationIssuesProvider =
    AsyncNotifierProvider<ValidationIssuesNotifier, List<ValidationIssue>>(
      ValidationIssuesNotifier.new,
    );

/// Runs `ValidationService.runProject()` (a background isolate over its own
/// read-only connection) when built, so on project open, and again
/// [debounce] after the last [writeEpochProvider] bump. While a run is in
/// flight the previous list stays readable as the loading state's value; a
/// run superseded by a newer one is discarded.
class ValidationIssuesNotifier extends AsyncNotifier<List<ValidationIssue>> {
  /// How long after the last write the pass re-runs.
  static const debounce = Duration(milliseconds: 500);

  Timer? _pending;

  @override
  Future<List<ValidationIssue>> build() {
    final path = ref.watch(requireSessionProvider).filePath;
    ref.listen(writeEpochProvider, (_, _) => _schedule());
    ref.onDispose(_cancel);
    return ValidationService(projectPath: path).runProject();
  }

  /// Re-runs the pass now (the Validation page's Refresh) and completes with
  /// its result.
  Future<List<ValidationIssue>> refresh() {
    _cancel();
    ref.invalidateSelf();
    return future;
  }

  void _schedule() {
    _cancel();
    _pending = Timer(debounce, ref.invalidateSelf);
  }

  void _cancel() {
    _pending?.cancel();
    _pending = null;
  }
}

/// Whether the sidebar shows icons only (56 px) instead of labels (220 px).
/// Session-only and not persisted, as 0.1.6's `ui.store` `sidebarOpen`.
final sidebarCollapsedProvider =
    NotifierProvider<SidebarCollapsedNotifier, bool>(
      SidebarCollapsedNotifier.new,
    );

class SidebarCollapsedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}
