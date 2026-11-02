/// The loot tables list over `LootTableRepository` (0.1.6
/// `LootTablesPage.tsx`).
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../../lists/list_domain_adapter.dart';
import '../../shell/shell_domain.dart';
import '../../shell/shell_providers.dart';
import 'loot_tables_providers.dart';

/// 0.1.6's columns after Name and Export Key, less Entries and Last
/// Modified: Assigned (`Used by N NPCs`, the active NPCs dropping from the
/// table). 0.1.6's Entries column counted each table's entries, which
/// `LootTableRecord` does not carry. Its Last Modified column is the
/// toolbar's sort only (newest first), as on the other domain lists: with
/// it the table does not fit the page at the minimum window. 0.1.6 sorted
/// by Name or Last Modified only.
///
/// The repository is read through [ref] in each call, never held.
class LootTableListAdapter
    with ListAdapterDefaults<LootTableRecord>
    implements ListDomainAdapter<LootTableRecord> {
  LootTableListAdapter(this.ref);

  static const assignedLabel = 'Assigned';
  static const lastModifiedLabel = 'Last Modified';

  final WidgetRef ref;

  LootTableRepository get _repository => ref.read(lootTableRepositoryProvider);

  @override
  ShellDomain get domain => ShellDomain.lootTables;

  @override
  Future<List<LootTableRecord>> list(RecordListMode mode) =>
      _repository.list(mode: mode);

  @override
  String idOf(LootTableRecord row) => row.id;

  @override
  String displayNameOf(LootTableRecord row) => row.displayName;

  @override
  String exportKeyOf(LootTableRecord row) => row.exportKey;

  @override
  String? deletedAtOf(LootTableRecord row) => row.deletedAt;

  @override
  List<ListColumn<LootTableRecord>> get columns => [
    ListColumn(
      label: assignedLabel,
      cell: (context, row) => _AssignedCell(row.id),
    ),
  ];

  @override
  List<ListSortOption<LootTableRecord>> get extraSortOptions => [
    ListSortOption(
      label: lastModifiedLabel,
      compare: (a, b) => a.updatedAt.compareTo(b.updatedAt),
      ascendingFirst: false,
    ),
  ];

  @override
  Future<void> softDelete(String id) => _repository.softDelete(id);

  @override
  Future<void> restore(String id) => _repository.restore(id);

  @override
  Future<void> hardDelete(String id) => _repository.hardDelete(id);

  @override
  Future<LootTableRecord?> duplicate(String id) => _repository.duplicate(id);
}

/// 0.1.6's `Used by N NPCs`; 0 until the counts load.
class _AssignedCell extends ConsumerWidget {
  const _AssignedCell(this.id);

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts =
        ref.watch(lootTableAssignmentCountsProvider).value ?? const {};
    return Text(
      'Used by ${counts[id] ?? 0} NPCs',
      style: context.text.bodyMedium?.copyWith(
        color: context.colors.onSurfaceVariant,
      ),
    );
  }
}
