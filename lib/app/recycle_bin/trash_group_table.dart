import 'package:flutter/material.dart';
import 'package:forge_ui/forge_ui.dart';

import '../lists/list_columns.dart';
import '../lists/list_domain_adapter.dart';
import '../lists/record_table.dart';
import '../shell/shell_domain.dart';
import 'recycle_bin_controller.dart';

/// 0.1.6's section label for [domain] in the recycle bin
/// (`DOMAIN_FETCHERS` in `RecycleBinPage.tsx`), which says
/// `Character Classes` and `Crafting Recipes` where the sidebar says
/// `Classes` and `Recipes`.
String trashGroupLabel(ShellDomain domain) => switch (domain) {
  ShellDomain.classes => 'Character Classes',
  ShellDomain.recipes => 'Crafting Recipes',
  _ => domain.label,
};

/// One domain's soft-deleted records (0.1.6's per-domain `Table` in
/// `RecycleBinPage.tsx`): the select-all checkbox, Name, Export Key,
/// Deleted At and the Restore and Permanently Delete actions, on the list
/// scaffold's [RecordTable] at the theme's density. The headers do not
/// sort and the rows do not open, as in 0.1.6.
class TrashGroupTable extends StatelessWidget {
  const TrashGroupTable({
    super.key,
    required this.domain,
    required this.rows,
    required this.selection,
    required this.onToggle,
    required this.onToggleAll,
    required this.onRestore,
    required this.onHardDelete,
  });

  /// The table of [domain]; the row keys inside it are [RecordTable]'s.
  static Key groupKey(ShellDomain domain) =>
      ValueKey('trash-group-${domain.name}');

  final ShellDomain domain;
  final List<TrashRow> rows;

  /// The selected ids of this domain.
  final Set<String> selection;
  final ValueChanged<String> onToggle;
  final VoidCallback onToggleAll;

  /// Null disables the action (a write is in flight).
  final ValueChanged<TrashRow>? onRestore;
  final ValueChanged<TrashRow>? onHardDelete;

  @override
  Widget build(BuildContext context) {
    final muted = context.colors.onSurfaceVariant;
    return RecordTable<TrashRow>(
      key: groupKey(domain),
      rows: rows,
      idOf: (row) => row.id,
      selection: selection,
      onToggleSelected: onToggle,
      onToggleAll: onToggleAll,
      columns: [
        ListColumn(
          label: ListColumnLabels.name,
          cell: (context, row) => Text(
            row.displayName,
            style: context.text.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: muted,
            ),
          ),
        ),
        ListColumn(
          label: ListColumnLabels.exportKey,
          cell: (context, row) => Text(
            row.exportKey,
            style: ForgeType.code(size: 13, color: muted),
          ),
        ),
        ListColumn(
          label: ListColumnLabels.deletedAt,
          cell: (context, row) => Text(
            formatDeletedAt(row.deletedAt),
            style: context.text.bodyMedium?.copyWith(color: muted),
          ),
        ),
      ],
      actionsFor: (row) => [
        RecordRowAction(
          label: 'Restore',
          icon: Icons.restore_from_trash,
          onPressed: () => onRestore?.call(row),
        ),
        RecordRowAction(
          label: 'Permanently Delete',
          icon: Icons.delete_forever,
          destructive: true,
          onPressed: () => onHardDelete?.call(row),
        ),
      ],
    );
  }
}
