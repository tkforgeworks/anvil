import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../editor/dirty_editors.dart';
import '../editor/exit_prompt.dart';
import '../shell/app_router.dart';
import '../shell/open_editor.dart';
import '../shell/shell_providers.dart';
import '../theme/anvil_metrics.dart';
import 'bulk_action_toolbar.dart';
import 'bulk_dialogs.dart';
import 'empty_state.dart';
import 'list_columns.dart';
import 'list_domain_adapter.dart';
import 'list_toolbar.dart';
import 'record_list_controller.dart';
import 'record_table.dart';
import 'undo_snackbar.dart';

/// A domain list page over [adapter] (0.1.6's `ItemsPage.tsx` and its
/// siblings): the page title, the [ListToolbar], the error line, the
/// [BulkActionToolbar] while records are selected, and the [RecordTable]
/// or the [EmptyState].
///
/// Active rows offer Edit, Duplicate and Delete; Delete soft-deletes at
/// once and Duplicate hands the copy to [onDuplicated]. Archived rows offer
/// Restore, at once, and Permanently Delete, confirmed. A bulk soft delete
/// shows the delete impact first, a bulk permanent delete confirms, a bulk
/// restore runs at once. A row tap opens the record through [onOpen],
/// `openEditor` by default.
///
/// Delete, Restore, Duplicate and the bulk delete and restore show the Undo
/// snackbar ([showUndoSnackBar], design §8.8) once they went through; its
/// Undo runs the inverse through the controller (restore, delete, a
/// permanent delete of the copy, or the bulk inverse over the same ids), so
/// it is one more write with its own history row and epoch bump. Permanent
/// deletes have no Undo. A Delete or Restore Undo needs this page, because
/// the adapter reads its repository through the domain page's `WidgetRef`,
/// so its snackbar is removed when the page goes away. A Duplicate Undo
/// outlives the page, since full-page mode opens the copy at once: it runs
/// through the container and `LifecycleRepository` instead.
///
/// The page keeps the first adapter it is given while the domain stays the
/// same, so a parent may build a fresh adapter on every build.
class RecordListPage<R> extends ConsumerStatefulWidget {
  const RecordListPage({
    super.key,
    required this.adapter,
    this.onNew,
    this.newLabel,
    this.filterSlot,
    this.filter,
    this.onOpen,
    this.onDuplicated,
    this.emptyTitle,
    this.emptyBody,
    this.emptyCtaLabel,
  });

  /// The error line, while one shows.
  static const errorKey = ValueKey('record-list-error');

  final ListDomainAdapter<R> adapter;

  /// The New button and the empty state's call to action (the page's
  /// create dialog); null hides both.
  final VoidCallback? onNew;

  /// Defaults to `+ New <Singular>`.
  final String? newLabel;

  /// The page's own filters in the toolbar; [filter] applies them.
  final Widget? filterSlot;
  final bool Function(R row)? filter;

  /// Opens record [id]; defaults to `openEditor` for the adapter's domain.
  final ValueChanged<String>? onOpen;
  final ValueChanged<R>? onDuplicated;

  /// The empty state with no records at all; defaults to 0.1.6's
  /// `No items yet` / `Create your first item to get started.` /
  /// `+ Create First Item`.
  final String? emptyTitle;
  final String? emptyBody;
  final String? emptyCtaLabel;

  @override
  ConsumerState<RecordListPage<R>> createState() => _RecordListPageState<R>();
}

class _RecordListPageState<R> extends ConsumerState<RecordListPage<R>> {
  late ListDomainAdapter<R> _adapter = widget.adapter;

  @override
  void didUpdateWidget(RecordListPage<R> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.adapter.domain != _adapter.domain) _adapter = widget.adapter;
  }

  RecordListController<R> get _controller =>
      ref.read(recordListProvider(_adapter).notifier);

  /// The Undo snackbar this page showed, while it is open.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _undoBar;
  ScaffoldMessengerState? _messenger;

  @override
  void dispose() {
    // An Undo after this page is gone would read through the adapter's dead
    // `WidgetRef`, so its snackbar goes with the page. The messenger cannot
    // be changed while the tree is locked for unmounting.
    final messenger = _messenger;
    if (_undoBar != null && messenger != null) {
      scheduleMicrotask(() {
        if (!messenger.mounted) return;
        messenger
          ..clearSnackBars()
          ..removeCurrentSnackBar();
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adapter = _adapter;
    final domain = adapter.domain;
    final async = ref.watch(recordListProvider(adapter));
    final state = async.value;
    final mode = state?.mode ?? ListViewMode.active;
    final sortOptions = listSortOptionsFor(adapter, mode);
    final filter = widget.filter;

    final Widget body;
    if (state == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final shown = filter == null
          ? state.visible
          : state.visible.where(filter).toList();
      body = _body(context, state, shown);
    }

    final lastError = state?.lastError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          domain.label,
          style: context.text.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AnvilSpacing.md),
        ListToolbar(
          search: state?.query ?? '',
          onSearchChanged: _controller.setQuery,
          sortLabels: [for (final o in sortOptions) o.label],
          sortLabel: state?.sortLabel ?? sortOptions.first.label,
          onSortChanged: _controller.sortBy,
          mode: mode,
          onModeChanged: _controller.setMode,
          newLabel: widget.newLabel ?? '+ New ${domain.singular}',
          onNew: widget.onNew,
          filterSlot: widget.filterSlot,
        ),
        const SizedBox(height: AnvilSpacing.md),
        if (lastError != null) ...[
          Semantics(
            liveRegion: true,
            child: ForgeErrorCard(
              key: RecordListPage.errorKey,
              message: lastError,
              onRetry: _controller.clearError,
              retryLabel: 'Dismiss',
            ),
          ),
          const SizedBox(height: AnvilSpacing.md),
        ],
        if (state != null && state.selection.isNotEmpty) ...[
          BulkActionToolbar(
            count: state.selection.length,
            mode: mode,
            onDelete: state.busy ? null : _bulkDelete,
            onRestore: state.busy ? null : _bulkRestore,
            onHardDelete: state.busy ? null : _bulkHardDelete,
          ),
          const SizedBox(height: AnvilSpacing.md),
        ],
        Expanded(child: body),
      ],
    );
  }

  Widget _body(BuildContext context, RecordListState<R> state, List<R> shown) {
    final adapter = _adapter;
    final domain = adapter.domain;
    final plural = lowerDomainLabel(domain.label);
    final singular = lowerDomainLabel(domain.singular);
    final archived = state.mode == ListViewMode.archived;

    if (archived && state.rows.isEmpty) {
      return Align(
        alignment: Alignment.topLeft,
        child: Text(
          'No archived $plural.',
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      );
    }

    final Widget content;
    if (state.rows.isEmpty) {
      content = EmptyState(
        icon: domain.icon,
        title: widget.emptyTitle ?? 'No $plural yet',
        body: widget.emptyBody ?? 'Create your first $singular to get started.',
        ctaLabel: widget.emptyCtaLabel ?? '+ Create First ${domain.singular}',
        onCta: widget.onNew,
      );
    } else if (shown.isEmpty) {
      content = EmptyState(
        title: widget.filterSlot == null
            ? 'No results match your search'
            : 'No results match your filters',
      );
    } else {
      final columns = listColumnsFor(adapter, state.mode);
      final sortIndex = columns.indexWhere((c) => c.label == state.sortLabel);
      content = RecordTable<R>(
        rows: shown,
        columns: columns,
        idOf: adapter.idOf,
        actionsFor: (row) => _actions(row, state),
        onOpen: archived ? null : _open,
        selection: state.selection,
        onToggleSelected: _controller.toggleSelected,
        onToggleAll: () => _controller.toggleAll(shown.map(adapter.idOf)),
        sortColumn: sortIndex < 0 ? null : sortIndex,
        ascending: state.ascending,
        onSort: (i, asc) =>
            _controller.sortBy(columns[i].label, ascending: asc),
      );
    }

    return SingleChildScrollView(
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: context.colors.outlineVariant),
          borderRadius: BorderRadius.circular(AnvilRadii.panel),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AnvilRadii.panel),
          child: content,
        ),
      ),
    );
  }

  List<RecordRowAction> _actions(R row, RecordListState<R> state) {
    final id = _adapter.idOf(row);
    final busy = state.busy;
    void guard(void Function() f) {
      if (!busy) f();
    }

    return switch (state.mode) {
      ListViewMode.active => [
        RecordRowAction(
          label: 'Edit',
          icon: Icons.edit,
          onPressed: () => _open(id),
        ),
        RecordRowAction(
          label: 'Duplicate',
          icon: Icons.content_copy,
          onPressed: () => guard(() => unawaited(_duplicate(row))),
        ),
        RecordRowAction(
          label: 'Delete',
          icon: Icons.delete,
          destructive: true,
          onPressed: () => guard(() => unawaited(_softDelete(row))),
        ),
      ],
      ListViewMode.archived => [
        RecordRowAction(
          label: 'Restore',
          icon: Icons.restore_from_trash,
          onPressed: () => guard(() => unawaited(_restore(row))),
        ),
        RecordRowAction(
          label: 'Permanently Delete',
          icon: Icons.delete_forever,
          destructive: true,
          onPressed: () => guard(() => unawaited(_hardDelete(row))),
        ),
      ],
    };
  }

  void _open(String id) {
    if (widget.onOpen case final onOpen?) {
      onOpen(id);
    } else {
      openEditor(context, ref, _adapter.domain, id);
    }
  }

  /// Shows the Undo snackbar for the action just applied. Unless [undo]
  /// [outlivesPage], it runs only while this page is still mounted and its
  /// snackbar goes with the page.
  void _offerUndo(
    String message,
    Future<void> Function() undo, {
    bool outlivesPage = false,
  }) {
    if (!mounted) return;
    final bar = showUndoSnackBar(
      context,
      message: message,
      undo: () async {
        if (outlivesPage || mounted) await undo();
      },
    );
    if (bar == null || outlivesPage) return;
    _messenger = ScaffoldMessenger.of(context);
    _undoBar = bar;
    unawaited(
      bar.closed.then((_) {
        if (identical(_undoBar, bar)) _undoBar = null;
      }),
    );
  }

  Future<void> _softDelete(R row) async {
    final id = _adapter.idOf(row);
    if (!await _controller.softDelete(id)) return;
    _offerUndo(
      'Deleted "${_adapter.displayNameOf(row)}"',
      () => _controller.restore(id),
    );
  }

  Future<void> _restore(R row) async {
    final id = _adapter.idOf(row);
    if (!await _controller.restore(id)) return;
    _offerUndo(
      'Restored "${_adapter.displayNameOf(row)}"',
      () => _controller.softDelete(id),
    );
  }

  Future<void> _duplicate(R row) async {
    final copy = await _controller.duplicate(_adapter.idOf(row));
    if (copy == null || !mounted) return;
    final copyId = _adapter.idOf(copy);
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.maybeOf(context);
    _offerUndo(
      'Duplicated "${_adapter.displayNameOf(row)}" '
      'as "${_adapter.displayNameOf(copy)}"',
      () => _undoDuplicate(copyId, container, messenger),
      outlivesPage: true,
    );
    widget.onDuplicated?.call(copy);
  }

  /// The inverse of a duplicate: the copy is new, so deleting it for good
  /// is exact. A dirty editor on the copy is discarded first so none
  /// survives it, and a full-page editor on the copy goes back to the list.
  ///
  /// While this page is mounted the delete goes through the controller,
  /// which shows a failure on the error line. Once the page is gone (the
  /// copy opened full page) the adapter's `WidgetRef` is dead, so the
  /// delete goes through [container] and the lifecycle repository, bumps
  /// the epoch itself and reports a failure on [messenger].
  Future<void> _undoDuplicate(
    String copyId,
    ProviderContainer container,
    ScaffoldMessengerState? messenger,
  ) async {
    final domain = _adapter.domain;
    findDirtyEditor(
      container.read(dirtyEditorsProvider),
      domain.saveDomain,
      copyId,
    )?.discard();
    if (mounted) {
      if (!await _controller.hardDelete(copyId)) return;
    } else {
      try {
        await container.read(lifecycleRepositoryProvider).bulkHardDelete(
          domain.lifecycleDomain,
          [copyId],
        );
      } catch (error) {
        if (messenger != null && messenger.mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text(listErrorMessage(error, 'Undo failed.'))),
          );
        }
        return;
      }
      container.read(writeEpochProvider.notifier).bump();
    }
    final router = container.read(routerProvider);
    final location = router.routerDelegate.currentConfiguration.uri.path;
    if (location == domain.editorLocation(copyId)) router.go(domain.location);
  }

  /// `3 abilities`, `1 ability`.
  String _records(int count) {
    final domain = _adapter.domain;
    return '$count ${lowerDomainLabel(count == 1 ? domain.singular : domain.label)}';
  }

  Future<void> _hardDelete(R row) async {
    final controller = _controller;
    final confirmed = await showPermanentDeleteDialog(
      context,
      domainLabel: _adapter.domain.singular,
      displayName: _adapter.displayNameOf(row),
    );
    if (confirmed) await controller.hardDelete(_adapter.idOf(row));
  }

  Future<void> _bulkDelete() async {
    final controller = _controller;
    final ids = _selectedIds();
    if (ids.isEmpty) return;
    final confirmed = await showBulkDeleteDialog(
      context,
      count: ids.length,
      impact: controller.selectionDeleteImpact,
    );
    if (!confirmed) return;
    final changed = await controller.softDeleteIds(ids);
    if (changed == null || changed == 0) return;
    _offerUndo(
      'Deleted ${_records(changed)}',
      () => _controller.restoreIds(ids),
    );
  }

  Future<void> _bulkRestore() async {
    final ids = _selectedIds();
    if (ids.isEmpty) return;
    final changed = await _controller.restoreIds(ids);
    if (changed == null || changed == 0) return;
    _offerUndo(
      'Restored ${_records(changed)}',
      () => _controller.softDeleteIds(ids),
    );
  }

  List<String> _selectedIds() =>
      ref.read(recordListProvider(_adapter)).value?.selection.toList() ??
      const [];

  Future<void> _bulkHardDelete() async {
    final controller = _controller;
    final count = ref
        .read(recordListProvider(_adapter))
        .value
        ?.selection
        .length;
    if (count == null || count == 0) return;
    final confirmed = await showBulkHardDeleteDialog(context, count: count);
    if (confirmed) await controller.bulkHardDelete();
  }
}
