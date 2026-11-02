/// The state behind the Recycle Bin page (design §13.7, 0.1.6
/// `RecycleBinPage.tsx`): every soft-deleted record of the six domains,
/// grouped by domain, the multi-select over them and every write the page
/// makes through `LifecycleRepository`.
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../lists/list_domain_adapter.dart';
import '../lists/record_list_controller.dart';
import '../providers.dart';
import '../shell/shell_domain.dart';
import '../shell/shell_providers.dart';

/// One soft-deleted record as the recycle bin lists it.
class TrashRow {
  const TrashRow({
    required this.id,
    required this.displayName,
    required this.exportKey,
    required this.deletedAt,
  });

  final String id;
  final String displayName;
  final String exportKey;

  /// The row's `deleted_at` text (SQLite `datetime('now')`).
  final String? deletedAt;

  @override
  bool operator ==(Object other) =>
      other is TrashRow &&
      other.id == id &&
      other.displayName == displayName &&
      other.exportKey == exportKey &&
      other.deletedAt == deletedAt;

  @override
  int get hashCode => Object.hash(id, displayName, exportKey, deletedAt);

  @override
  String toString() => 'TrashRow($id, $displayName)';
}

/// The soft-deleted records of one domain, in the repository's order
/// (display name ignoring case).
class TrashGroup {
  const TrashGroup(this.domain, this.rows);

  final ShellDomain domain;
  final List<TrashRow> rows;
}

/// A selected record: ids are unique only within their domain's table.
typedef TrashKey = (ShellDomain domain, String id);

/// What the page shows. [groups] hold only the domains with soft-deleted
/// records, in 0.1.6's order (`ShellDomain.values`), as 0.1.6 filtered out
/// the empty ones.
class RecycleBinState {
  const RecycleBinState({
    required this.groups,
    required this.selection,
    required this.busy,
    required this.lastError,
  });

  final List<TrashGroup> groups;
  final Set<TrashKey> selection;

  /// A write is in flight; further actions are ignored until it returns.
  final bool busy;

  /// The last failed load or action, for the page's error line.
  final String? lastError;

  /// Soft-deleted records across every domain.
  int get total => groups.fold(0, (sum, g) => sum + g.rows.length);

  /// The selected ids of [domain].
  Set<String> selectedIn(ShellDomain domain) => {
    for (final (d, id) in selection)
      if (d == domain) id,
  };
}

/// The recycle bin's controller.
final recycleBinProvider =
    AsyncNotifierProvider.autoDispose<RecycleBinController, RecycleBinState>(
      RecycleBinController.new,
      name: 'recycleBin',
    );

/// Loads the six deleted lists in [build], which watches [writeEpochProvider]
/// and the nullable `projectSessionProvider`, so every write anywhere (and a
/// replaced project) reloads the page while the selection and the error line
/// survive in fields. The selection is pruned to the rows still in the trash.
///
/// Every write here goes through `LifecycleRepository`, as 0.1.6's page
/// called `lifecycle:*` for single records too, so the history rows are
/// 0.1.6's nameless `Recipe restored` / `3 items permanently deleted`. Each
/// write bumps the epoch once after it returns and clears the selection, as
/// 0.1.6 cleared it after every action; a failure sets the error line with
/// 0.1.6's fallback texts. A bulk action over several domains is one write
/// per domain, as in 0.1.6; when a later domain fails, the epoch is still
/// bumped once for the domains already written.
class RecycleBinController extends AsyncNotifier<RecycleBinState> {
  var _groups = <TrashGroup>[];
  var _selection = <TrashKey>{};
  var _busy = false;
  String? _loadError;
  String? _actionError;

  @override
  Future<RecycleBinState> build() async {
    ref.watch(writeEpochProvider);
    ref.watch(projectSessionProvider);
    try {
      final lists = await Future.wait([
        for (final domain in ShellDomain.values) _deleted(domain),
      ]);
      if (!ref.mounted) return _snapshot();
      _groups = [
        for (final (i, domain) in ShellDomain.values.indexed)
          if (lists[i].isNotEmpty)
            TrashGroup(domain, List.unmodifiable(lists[i])),
      ];
      _loadError = null;
      final keys = {
        for (final g in _groups)
          for (final r in g.rows) (g.domain, r.id),
      };
      _selection = _selection.where(keys.contains).toSet();
    } catch (error) {
      _loadError = listErrorMessage(error, 'Failed to load archived records.');
    }
    return _snapshot();
  }

  Future<List<TrashRow>> _deleted(ShellDomain domain) async {
    const mode = RecordListMode.deletedOnly;
    TrashRow row(String id, String name, String key, String? deletedAt) =>
        TrashRow(
          id: id,
          displayName: name,
          exportKey: key,
          deletedAt: deletedAt,
        );
    return switch (domain) {
      ShellDomain.classes => [
        for (final r
            in await ref.read(classRepositoryProvider).list(mode: mode))
          row(r.id, r.displayName, r.exportKey, r.deletedAt),
      ],
      ShellDomain.abilities => [
        for (final r
            in await ref.read(abilityRepositoryProvider).list(mode: mode))
          row(r.id, r.displayName, r.exportKey, r.deletedAt),
      ],
      ShellDomain.items => [
        for (final r in await ref.read(itemRepositoryProvider).list(mode: mode))
          row(r.id, r.displayName, r.exportKey, r.deletedAt),
      ],
      ShellDomain.recipes => [
        for (final r
            in await ref.read(recipeRepositoryProvider).list(mode: mode))
          row(r.id, r.displayName, r.exportKey, r.deletedAt),
      ],
      ShellDomain.npcs => [
        for (final r in await ref.read(npcRepositoryProvider).list(mode: mode))
          row(r.id, r.displayName, r.exportKey, r.deletedAt),
      ],
      ShellDomain.lootTables => [
        for (final r
            in await ref.read(lootTableRepositoryProvider).list(mode: mode))
          row(r.id, r.displayName, r.exportKey, r.deletedAt),
      ],
    };
  }

  void toggle(ShellDomain domain, String id) {
    final next = {..._selection};
    if (!next.remove((domain, id))) next.add((domain, id));
    _selection = next;
    _emit();
  }

  /// The header checkbox of [domain]'s table: deselects that domain's rows
  /// when all of them are selected, else selects all of them. Other domains'
  /// selections stay (0.1.6's `toggleAll` replaced the whole selection).
  void toggleAllIn(ShellDomain domain) {
    final keys = {
      for (final g in _groups)
        if (g.domain == domain)
          for (final r in g.rows) (domain, r.id),
    };
    if (keys.isEmpty) return;
    final allSelected = keys.every(_selection.contains);
    _selection = allSelected
        ? _selection.difference(keys)
        : {..._selection, ...keys};
    _emit();
  }

  void clearSelection() {
    _selection = {};
    _emit();
  }

  /// Dismisses the error line.
  void clearError() {
    _actionError = null;
    _loadError = null;
    _emit();
  }

  /// The selection grouped by domain, in `ShellDomain.values` order.
  Map<ShellDomain, List<String>> selectedByDomain() {
    final groups = <ShellDomain, List<String>>{};
    for (final domain in ShellDomain.values) {
      final ids = [
        for (final (d, id) in _selection)
          if (d == domain) id,
      ];
      if (ids.isNotEmpty) groups[domain] = ids;
    }
    return groups;
  }

  /// Restores one record at once; the page offers the Undo
  /// ([softDeleteIds]). True when the write went through.
  Future<bool> restore(ShellDomain domain, String id) => _run(
    (repo, _) => repo.bulkRestore(domain.lifecycleDomain, [id]),
    'Restore failed.',
  );

  /// Deletes one record for good; the page confirms first.
  Future<bool> hardDelete(ShellDomain domain, String id) => _run(
    (repo, _) => repo.bulkHardDelete(domain.lifecycleDomain, [id]),
    'Delete failed.',
  );

  /// Restores the selection, one write per domain. Returns the rows
  /// changed, or null when nothing ran or a write failed.
  Future<int?> restoreSelected() => restoreGroups(selectedByDomain());

  /// Deletes the selection for good, one write per domain; the page
  /// confirms first. Returns the rows changed, or null.
  Future<int?> hardDeleteSelected() => _runGroups(
    selectedByDomain(),
    (repo, domain, ids) => repo.bulkHardDelete(domain, ids),
    'Bulk delete failed.',
  );

  /// Restores [groups]: a bulk restore of the selection.
  Future<int?> restoreGroups(Map<ShellDomain, List<String>> groups) =>
      _runGroups(
        groups,
        (repo, domain, ids) => repo.bulkRestore(domain, ids),
        'Bulk restore failed.',
      );

  /// Restores [ids] of [domain] in one write.
  Future<int?> restoreIds(ShellDomain domain, List<String> ids) =>
      restoreGroups({domain: ids});

  /// Soft-deletes [groups] again: the Undo of a bulk restore over the same
  /// ids.
  Future<int?> softDeleteGroups(Map<ShellDomain, List<String>> groups) =>
      _runGroups(
        groups,
        (repo, domain, ids) => repo.bulkSoftDelete(domain, ids),
        'Undo failed.',
      );

  /// Soft-deletes [ids] of [domain] again: the Undo of a restore.
  Future<int?> softDeleteIds(ShellDomain domain, List<String> ids) =>
      softDeleteGroups({domain: ids});

  /// Deletes every soft-deleted record of the six domains in one
  /// transaction; the page asks twice first. True when it went through.
  Future<bool> emptyTrash() =>
      _run((repo, _) => repo.emptyTrash(), 'Failed to empty trash.');

  Future<int?> _runGroups(
    Map<ShellDomain, List<String>> groups,
    Future<int> Function(
      LifecycleRepository repo,
      LifecycleDomain domain,
      List<String> ids,
    )
    write,
    String fallback,
  ) async {
    final entries = [
      for (final e in groups.entries)
        if (e.value.isNotEmpty) e,
    ];
    if (entries.isEmpty) return null;
    var changed = 0;
    final ok = await _run((repo, committed) async {
      for (final MapEntry(key: domain, value: ids) in entries) {
        changed += await write(repo, domain.lifecycleDomain, ids);
        committed();
      }
    }, fallback);
    return ok ? changed : null;
  }

  /// Runs one write: ignored while another is in flight; on success clears
  /// the selection and bumps the epoch once (which reloads this page); on
  /// failure sets the error line, still bumping once if [write] reported a
  /// committed part through its second argument. True when it went through.
  Future<bool> _run(
    Future<void> Function(LifecycleRepository repo, void Function() committed)
    write,
    String fallback,
  ) async {
    if (_busy) return false;
    _busy = true;
    _actionError = null;
    _emit();
    var wrote = false;
    try {
      await write(ref.read(lifecycleRepositoryProvider), () => wrote = true);
      if (!ref.mounted) return false;
      _selection = {};
      ref.read(writeEpochProvider.notifier).bump();
      return true;
    } catch (error) {
      if (!ref.mounted) return false;
      _actionError = listErrorMessage(error, fallback);
      if (wrote) ref.read(writeEpochProvider.notifier).bump();
      return false;
    } finally {
      if (ref.mounted) {
        _busy = false;
        _emit();
      }
    }
  }

  void _emit() => state = AsyncData(_snapshot());

  RecycleBinState _snapshot() => RecycleBinState(
    groups: List.unmodifiable(_groups),
    selection: Set.unmodifiable(_selection),
    busy: _busy,
    lastError: _actionError ?? _loadError,
  );
}
