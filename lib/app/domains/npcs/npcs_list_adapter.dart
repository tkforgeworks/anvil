/// The NPCs list over `NpcRepository` (0.1.6 `NpcsPage.tsx`).
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../../lists/list_domain_adapter.dart';
import '../../shell/shell_domain.dart';
import '../../shell/shell_providers.dart';
import 'npcs_providers.dart';

/// The widest a Type or Loot Table cell grows before it ellipsizes, so
/// long names do not squeeze the table's headers at the minimum window.
const _nameCellMaxWidth = 140.0;

/// A muted single-line cell capped at [_nameCellMaxWidth].
Widget _nameCell(BuildContext context, String text) => ConstrainedBox(
  constraints: const BoxConstraints(maxWidth: _nameCellMaxWidth),
  child: Tooltip(
    message: text,
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.text.bodyMedium?.copyWith(
        color: context.colors.onSurfaceVariant,
      ),
    ),
  ),
);

/// The columns after Name and Export Key: NPC Type (its name, the id when
/// it no longer exists) and Loot Table (its name, `-` for none, the id
/// when it no longer exists), each capped at 140 px with an ellipsis and
/// the full name as a tooltip. 0.1.6 sorted by Name or Last Modified only,
/// so these columns do not sort; Last Modified is the extra sort, newest
/// first.
///
/// Search also matches the type name once the types have loaded; 0.1.6
/// searched the display name only.
///
/// The repository is read through [ref] in each call, never held.
class NpcListAdapter
    with ListAdapterDefaults<NpcRecord>
    implements ListDomainAdapter<NpcRecord> {
  NpcListAdapter(this.ref);

  final WidgetRef ref;

  NpcRepository get _repository => ref.read(npcRepositoryProvider);

  @override
  ShellDomain get domain => ShellDomain.npcs;

  @override
  Future<List<NpcRecord>> list(RecordListMode mode) =>
      _repository.list(mode: mode);

  @override
  String idOf(NpcRecord row) => row.id;

  @override
  String displayNameOf(NpcRecord row) => row.displayName;

  @override
  String exportKeyOf(NpcRecord row) => row.exportKey;

  @override
  String? deletedAtOf(NpcRecord row) => row.deletedAt;

  @override
  List<ListColumn<NpcRecord>> get columns => [
    ListColumn(label: 'NPC Type', cell: (context, row) => _TypeCell(row)),
    ListColumn(
      label: 'Loot Table',
      cell: (context, row) => _LootTableCell(row),
    ),
  ];

  @override
  List<ListSortOption<NpcRecord>> get extraSortOptions => [
    ListSortOption(
      label: 'Last Modified',
      compare: (a, b) => a.updatedAt.compareTo(b.updatedAt),
      ascendingFirst: false,
    ),
  ];

  @override
  String extraSearchText(NpcRecord row) =>
      ref
          .read(npcTypesProvider)
          .value
          ?.where((t) => t.id == row.npcTypeId)
          .firstOrNull
          ?.displayName ??
      '';

  @override
  Future<void> softDelete(String id) => _repository.softDelete(id);

  @override
  Future<void> restore(String id) => _repository.restore(id);

  @override
  Future<void> hardDelete(String id) => _repository.hardDelete(id);

  @override
  Future<NpcRecord?> duplicate(String id) => _repository.duplicate(id);
}

class _TypeCell extends ConsumerWidget {
  const _TypeCell(this.row);

  final NpcRecord row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final types = ref.watch(npcTypesProvider).value ?? const [];
    final type = types.where((t) => t.id == row.npcTypeId).firstOrNull;
    return _nameCell(context, type?.displayName ?? row.npcTypeId);
  }
}

class _LootTableCell extends ConsumerWidget {
  const _LootTableCell(this.row);

  final NpcRecord row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = row.lootTableId;
    final tables = ref.watch(npcLootTablesProvider).value ?? const [];
    final table = id == null
        ? null
        : tables.where((t) => t.id == id).firstOrNull;
    return _nameCell(context, id == null ? '-' : table?.displayName ?? id);
  }
}
