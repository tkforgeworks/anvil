/// The state behind a record list page (design §13.7): the view, search,
/// sort and selection over the loaded rows, and every list action.
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../shell/shell_providers.dart';
import 'list_columns.dart';
import 'list_domain_adapter.dart';

/// What a list page shows. [rows] are everything loaded for [mode];
/// [visible] are the rows matching [query] in the chosen sort. A page's own
/// filters (its filter slot) narrow [visible] further.
class RecordListState<R> {
  const RecordListState({
    required this.mode,
    required this.query,
    required this.sortLabel,
    required this.ascending,
    required this.selection,
    required this.rows,
    required this.visible,
    required this.busy,
    required this.lastError,
  });

  final ListViewMode mode;
  final String query;

  /// The label of the active `ListSortOption`.
  final String sortLabel;
  final bool ascending;

  /// Selected record ids (multi-select).
  final Set<String> selection;
  final List<R> rows;
  final List<R> visible;

  /// A write is in flight; further actions are ignored until it returns.
  final bool busy;

  /// The last failed load or action, for the page's error line.
  final String? lastError;
}

/// The controller for one adapter's list.
///
/// Keyed by the adapter instance: [recordListProvider] hands out one
/// `autoDispose` provider per adapter object (held weakly in an [Expando]),
/// so the generic row type survives, which a top-level family cannot do.
/// `RecordListPage` keeps the first adapter it is given for as long as its
/// domain stays the same, so a parent rebuilding with a fresh adapter does
/// not reset the list.
///
/// [build] watches [writeEpochProvider], so every write anywhere reloads
/// the rows, and the nullable `projectSessionProvider`, so a replaced
/// project reloads too. View, search, sort, selection and the error line
/// live in fields and survive the reload. Every action here is a write
/// path: it bumps the epoch once after the write returns. Nothing throws to
/// widgets: a failure becomes [RecordListState.lastError].
class RecordListController<R> extends AsyncNotifier<RecordListState<R>> {
  RecordListController(this.adapter);

  final ListDomainAdapter<R> adapter;

  var _mode = ListViewMode.active;
  var _query = '';
  String? _sortLabel;
  var _ascending = true;
  var _selection = <String>{};
  var _rows = <R>[];
  var _busy = false;
  String? _loadError;
  String? _actionError;

  @override
  Future<RecordListState<R>> build() async {
    ref.watch(writeEpochProvider);
    ref.watch(projectSessionProvider);
    final mode = _mode;
    try {
      final rows = await adapter.list(_recordListMode(mode));
      if (!ref.mounted || mode != _mode) return _snapshot();
      _rows = rows;
      _loadError = null;
      final ids = {for (final r in rows) adapter.idOf(r)};
      _selection = _selection.where(ids.contains).toSet();
    } catch (error) {
      _loadError = listErrorMessage(
        error,
        'Failed to load ${_lowerPlural(adapter)}.',
      );
    }
    return _snapshot();
  }

  /// Switches between the active and archived rows; clears the selection
  /// and the error line.
  void setMode(ListViewMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    _selection = {};
    _rows = [];
    _actionError = null;
    _loadError = null;
    _emit();
    ref.invalidateSelf();
  }

  void setQuery(String query) {
    _query = query;
    _emit();
  }

  /// Sorts by the option labelled [label], ascending unless [ascending]
  /// says otherwise (an extra option's own first direction when omitted).
  void sortBy(String label, {bool? ascending}) {
    final option = _option(label);
    if (option == null) return;
    _sortLabel = option.label;
    _ascending = ascending ?? option.ascendingFirst;
    _emit();
  }

  void toggleSelected(String id) {
    final next = {..._selection};
    if (!next.remove(id)) next.add(id);
    _selection = next;
    _emit();
  }

  /// 0.1.6 `toggleAll`: clears the selection when every one of [ids] is
  /// selected, else selects exactly [ids].
  void toggleAll(Iterable<String> ids) {
    final all = ids.toSet();
    final allSelected = all.isNotEmpty && all.every(_selection.contains);
    _selection = allSelected ? {} : all;
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

  /// Moves [id] to the archive at once, with no confirmation and no Undo.
  /// ANVL-166 replaces this hook's caller with the instant action and its
  /// Undo snackbar (design §8.8).
  Future<void> softDelete(String id) => _run(
    () => adapter.softDelete(id),
    'Failed to delete ${_lowerSingular(adapter)}.',
  );

  /// Restores the archived [id] at once.
  Future<void> restore(String id) =>
      _run(() => adapter.restore(id), 'Restore failed.');

  /// Deletes [id] for good; the page confirms first.
  Future<void> hardDelete(String id) =>
      _run(() => adapter.hardDelete(id), 'Delete failed.');

  /// Copies [id] and returns the copy (opening it is the page's call), or
  /// null when the copy failed or nothing was copied.
  Future<R?> duplicate(String id) async {
    R? copy;
    await _run(() async {
      copy = await adapter.duplicate(id);
    }, 'Failed to duplicate ${_lowerSingular(adapter)}.');
    return copy;
  }

  /// What soft-deleting the selection would affect, for the bulk delete
  /// dialog. Throws what the repository throws; the dialog reports it.
  Future<DeleteImpact> selectionDeleteImpact() => ref
      .read(lifecycleRepositoryProvider)
      .computeDeleteImpact(adapter.domain.lifecycleDomain, _selection.toList());

  /// Soft-deletes the selection; the page shows the impact dialog first.
  Future<void> bulkSoftDelete() => _runBulk(
    (repo, domain, ids) => repo.bulkSoftDelete(domain, ids),
    'Bulk delete failed.',
  );

  /// Restores the selection at once.
  Future<void> bulkRestore() => _runBulk(
    (repo, domain, ids) => repo.bulkRestore(domain, ids),
    'Bulk restore failed.',
  );

  /// Deletes the selection for good; the page confirms first.
  Future<void> bulkHardDelete() => _runBulk(
    (repo, domain, ids) => repo.bulkHardDelete(domain, ids),
    'Bulk delete failed.',
  );

  Future<void> _runBulk(
    Future<int> Function(
      LifecycleRepository repo,
      LifecycleDomain domain,
      List<String> ids,
    )
    write,
    String fallback,
  ) {
    final ids = _selection.toList();
    if (ids.isEmpty) return Future.value();
    return _run(() async {
      await write(
        ref.read(lifecycleRepositoryProvider),
        adapter.domain.lifecycleDomain,
        ids,
      );
      _selection = {};
    }, fallback);
  }

  /// Runs one write: ignored while another is in flight; on success bumps
  /// the epoch once (which reloads this list); on failure sets the error
  /// line.
  Future<void> _run(Future<void> Function() write, String fallback) async {
    if (_busy) return;
    _busy = true;
    _actionError = null;
    _emit();
    try {
      await write();
      if (!ref.mounted) return;
      ref.read(writeEpochProvider.notifier).bump();
    } catch (error) {
      if (!ref.mounted) return;
      _actionError = listErrorMessage(error, fallback);
    } finally {
      if (ref.mounted) {
        _busy = false;
        _emit();
      }
    }
  }

  ListSortOption<R>? _option(String label) {
    for (final option in listSortOptionsFor(adapter, _mode)) {
      if (option.label == label) return option;
    }
    return null;
  }

  void _emit() => state = AsyncData(_snapshot());

  RecordListState<R> _snapshot() {
    final options = listSortOptionsFor(adapter, _mode);
    final sort =
        (_sortLabel == null ? null : _option(_sortLabel!)) ?? options.first;
    final needle = _query.trim().toLowerCase();
    final matching = needle.isEmpty
        ? _rows
        : _rows.where((r) => _haystack(r).contains(needle)).toList();
    return RecordListState(
      mode: _mode,
      query: _query,
      sortLabel: sort.label,
      ascending: _ascending,
      selection: Set.unmodifiable(_selection),
      rows: List.unmodifiable(_rows),
      visible: List.unmodifiable(
        _stableSort<R>(matching, sort.compare, ascending: _ascending),
      ),
      busy: _busy,
      lastError: _actionError ?? _loadError,
    );
  }

  String _haystack(R row) => [
    adapter.displayNameOf(row),
    adapter.exportKeyOf(row),
    adapter.extraSearchText(row),
  ].join('\n').toLowerCase();
}

/// The list controller for [adapter]: one `autoDispose` provider per
/// adapter object, so the same adapter always reaches the same list state
/// while anything watches it.
AsyncNotifierProvider<RecordListController<R>, RecordListState<R>>
recordListProvider<R>(ListDomainAdapter<R> adapter) =>
    (_providers[adapter] ??=
            AsyncNotifierProvider.autoDispose<
              RecordListController<R>,
              RecordListState<R>
            >(
              () => RecordListController<R>(adapter),
              name: 'recordList(${adapter.domain.name})',
            ))
        as AsyncNotifierProvider<RecordListController<R>, RecordListState<R>>;

final _providers = Expando<Object>('recordListProvider');

/// The text the error line shows for [error]: the boundary types' meaning,
/// else [fallback] (0.1.6 showed `cause.message` or the fallback).
String listErrorMessage(Object error, String fallback) => switch (error) {
  SaveFailed(:final message) => message,
  RecordNotFound() => 'This record no longer exists. It may have been deleted.',
  DuplicateExportKey() => 'The export key is already used by another record.',
  _ => fallback,
};

RecordListMode _recordListMode(ListViewMode mode) => switch (mode) {
  ListViewMode.active => RecordListMode.active,
  ListViewMode.archived => RecordListMode.deletedOnly,
};

List<R> _stableSort<R>(
  List<R> rows,
  Comparator<R> compare, {
  required bool ascending,
}) {
  final indexed = [for (var i = 0; i < rows.length; i++) (i, rows[i])];
  indexed.sort((a, b) {
    final c = compare(a.$2, b.$2);
    if (c != 0) return ascending ? c : -c;
    return a.$1.compareTo(b.$1);
  });
  return [for (final (_, row) in indexed) row];
}

String _lowerPlural(ListDomainAdapter<Object?> adapter) =>
    lowerDomainLabel(adapter.domain.label);

String _lowerSingular(ListDomainAdapter<Object?> adapter) =>
    lowerDomainLabel(adapter.domain.singular);

/// A domain label in running text: `loot tables`, but `NPCs` and `NPC`
/// keep their capitals as 0.1.6's texts did.
String lowerDomainLabel(String label) =>
    label.startsWith('NPC') ? label : label.toLowerCase();
