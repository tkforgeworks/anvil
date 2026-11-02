import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../lists/bulk_action_toolbar.dart';
import '../lists/bulk_dialogs.dart';
import '../lists/empty_state.dart';
import '../lists/list_columns.dart';
import '../lists/record_list_controller.dart';
import '../lists/undo_snackbar.dart';
import '../shell/shell_domain.dart';
import '../theme/anvil_metrics.dart';
import 'empty_trash_dialog.dart';
import 'recycle_bin_controller.dart';
import 'trash_group_table.dart';

/// The Recycle Bin at `/recycle-bin` (0.1.6 `RecycleBinPage.tsx`): every
/// soft-deleted record grouped by domain, multi-select across the groups
/// with the bulk toolbar, per-row Restore and Permanently Delete, and the
/// two-step Empty Trash.
///
/// Restores (single and bulk) apply at once and show the Undo snackbar
/// (design §8.8), whose Undo soft-deletes the same ids again through the
/// controller; it runs only while this page is mounted, and the snackbar
/// goes with the page. Permanent deletes and Empty Trash are confirmed and
/// have no Undo. Every write bumps the write epoch, which reloads this page,
/// the sidebar's trash badge and the domain lists.
class RecycleBinPage extends ConsumerStatefulWidget {
  const RecycleBinPage({super.key});

  static const emptyTrashKey = ValueKey('recycle-bin-empty-trash');

  /// The error line, while one shows.
  static const errorKey = ValueKey('recycle-bin-error');

  /// The header of [domain]'s section.
  static Key groupHeaderKey(ShellDomain domain) =>
      ValueKey('trash-group-header-${domain.name}');

  @override
  ConsumerState<RecycleBinPage> createState() => _RecycleBinPageState();
}

class _RecycleBinPageState extends ConsumerState<RecycleBinPage> {
  RecycleBinController get _controller => ref.read(recycleBinProvider.notifier);

  /// The Undo snackbar this page showed, while it is open.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _undoBar;
  ScaffoldMessengerState? _messenger;

  @override
  void dispose() {
    // An Undo after this page is gone would reach a disposed controller, so
    // its snackbar goes with the page. The messenger cannot be changed while
    // the tree is locked for unmounting.
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
    final state = ref.watch(recycleBinProvider).value;
    final total = state?.total ?? 0;
    final busy = state?.busy ?? false;
    final c = context.colors;

    final Widget body;
    if (state == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (total == 0) {
      body = Align(
        alignment: Alignment.topCenter,
        child: _Panel(
          child: const SizedBox(
            width: double.infinity,
            child: EmptyState(
              icon: Icons.restore_from_trash,
              title: 'Trash is empty',
              body: 'Deleted records will appear here.',
            ),
          ),
        ),
      );
    } else {
      body = SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, group) in state.groups.indexed) ...[
              if (i > 0) const SizedBox(height: AnvilSpacing.lg),
              _groupSection(context, state, group),
            ],
          ],
        ),
      );
    }

    final lastError = state?.lastError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Recycle Bin',
                style: context.text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            OutlinedButton.icon(
              key: RecycleBinPage.emptyTrashKey,
              style: OutlinedButton.styleFrom(
                foregroundColor: c.error,
                side: BorderSide(
                  color: total == 0 || busy ? c.outlineVariant : c.error,
                ),
              ),
              onPressed: total == 0 || busy ? null : () => _emptyTrash(total),
              icon: const Icon(Icons.delete_sweep, size: 18),
              label: const Text('Empty Trash'),
            ),
          ],
        ),
        const SizedBox(height: AnvilSpacing.md),
        if (lastError != null) ...[
          Semantics(
            liveRegion: true,
            child: ForgeErrorCard(
              key: RecycleBinPage.errorKey,
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
            mode: ListViewMode.archived,
            onRestore: busy ? null : _bulkRestore,
            onHardDelete: busy ? null : _bulkHardDelete,
          ),
          const SizedBox(height: AnvilSpacing.md),
        ],
        Expanded(child: body),
      ],
    );
  }

  Widget _groupSection(
    BuildContext context,
    RecycleBinState state,
    TrashGroup group,
  ) {
    final domain = group.domain;
    final busy = state.busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          key: RecycleBinPage.groupHeaderKey(domain),
          TextSpan(
            children: [
              TextSpan(text: trashGroupLabel(domain)),
              TextSpan(
                text: '  (${group.rows.length})',
                style: context.text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w400,
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          style: context.text.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AnvilSpacing.sm),
        _Panel(
          child: TrashGroupTable(
            domain: domain,
            rows: group.rows,
            selection: state.selectedIn(domain),
            onToggle: (id) => _controller.toggle(domain, id),
            onToggleAll: () => _controller.toggleAllIn(domain),
            onRestore: busy ? null : (row) => unawaited(_restore(domain, row)),
            onHardDelete: busy
                ? null
                : (row) => unawaited(_hardDelete(domain, row)),
          ),
        ),
      ],
    );
  }

  /// Shows the Undo snackbar for a restore just applied; [undo] runs only
  /// while this page is mounted.
  void _offerUndo(String message, Future<void> Function() undo) {
    if (!mounted) return;
    final bar = showUndoSnackBar(
      context,
      message: message,
      undo: () async {
        if (mounted) await undo();
      },
    );
    if (bar == null) return;
    _messenger = ScaffoldMessenger.of(context);
    _undoBar = bar;
    unawaited(
      bar.closed.then((_) {
        if (identical(_undoBar, bar)) _undoBar = null;
      }),
    );
  }

  Future<void> _restore(ShellDomain domain, TrashRow row) async {
    if (!await _controller.restore(domain, row.id)) return;
    _offerUndo(
      'Restored "${row.displayName}"',
      () => _controller.softDeleteIds(domain, [row.id]),
    );
  }

  Future<void> _hardDelete(ShellDomain domain, TrashRow row) async {
    final controller = _controller;
    final confirmed = await showPermanentDeleteDialog(
      context,
      domainLabel: 'Record',
      displayName: row.displayName,
    );
    if (confirmed) await controller.hardDelete(domain, row.id);
  }

  Future<void> _bulkRestore() async {
    final controller = _controller;
    final groups = controller.selectedByDomain();
    if (groups.isEmpty) return;
    final changed = await controller.restoreGroups(groups);
    if (changed == null || changed == 0) return;
    _offerUndo(
      'Restored ${_records(changed, groups.keys)}',
      () => _controller.softDeleteGroups(groups),
    );
  }

  Future<void> _bulkHardDelete() async {
    final controller = _controller;
    final count = ref.read(recycleBinProvider).value?.selection.length ?? 0;
    if (count == 0) return;
    final confirmed = await showBulkHardDeleteDialog(context, count: count);
    if (confirmed) await controller.hardDeleteSelected();
  }

  Future<void> _emptyTrash(int total) async {
    final controller = _controller;
    final confirmed = await showEmptyTrashDialog(context, count: total);
    if (confirmed) await controller.emptyTrash();
  }

  /// `3 abilities` when every record came from one domain, else
  /// `5 records`; singular for one.
  String _records(int count, Iterable<ShellDomain> domains) {
    if (domains.length == 1) {
      final domain = domains.first;
      return '$count '
          '${lowerDomainLabel(count == 1 ? domain.singular : domain.label)}';
    }
    return '$count record${count == 1 ? '' : 's'}';
  }
}

/// The outlined, rounded panel 0.1.6 drew around each table and the empty
/// state (`Paper variant="outlined"`).
class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: context.colors.outlineVariant),
      borderRadius: BorderRadius.circular(AnvilRadii.panel),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(AnvilRadii.panel),
      child: child,
    ),
  );
}
