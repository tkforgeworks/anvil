import 'package:flutter/material.dart';
import 'package:forge_ui/forge_ui.dart';

import 'list_domain_adapter.dart';

/// One icon button in a row's Actions cell.
class RecordRowAction {
  const RecordRowAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
  });

  /// The tooltip, as 0.1.6's (`Duplicate`, `Permanently Delete`).
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  /// Drawn in the error colour.
  final bool destructive;
}

/// A record list's table (0.1.6's list page `Table size="small"` and
/// `ArchiveTable`): a [DataTable] at the theme's density (forge_ui's
/// desktop density makes rows 40 px), an optional checkbox column, sortable
/// headers, a tap on any data cell calling [onOpen], and per-row actions in
/// a right-aligned last column.
class RecordTable<R> extends StatelessWidget {
  const RecordTable({
    super.key,
    required this.rows,
    required this.columns,
    required this.idOf,
    required this.actionsFor,
    this.onOpen,
    this.selection,
    this.onToggleSelected,
    this.onToggleAll,
    this.sortColumn,
    this.ascending = true,
    this.onSort,
  });

  /// The select-all checkbox in the header.
  static const selectAllKey = ValueKey('record-table-select-all');

  /// The checkbox of row [id].
  static Key selectKey(String id) => ValueKey('record-table-select-$id');

  /// Action [label] (its tooltip) of row [id].
  static Key actionKey(String label, String id) =>
      ValueKey('record-table-action-$label-$id');

  final List<R> rows;
  final List<ListColumn<R>> columns;
  final String Function(R row) idOf;
  final List<RecordRowAction> Function(R row) actionsFor;

  /// Called with the id of a tapped row; null leaves rows inert.
  final ValueChanged<String>? onOpen;

  /// Selected ids; null hides the checkbox column.
  final Set<String>? selection;
  final ValueChanged<String>? onToggleSelected;
  final VoidCallback? onToggleAll;

  /// The index into [columns] of the sorted column, or null.
  final int? sortColumn;
  final bool ascending;

  /// Called with the index into [columns] and the new direction when a
  /// sortable header is tapped (the same column flips, another starts
  /// ascending).
  final void Function(int column, bool ascending)? onSort;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rowHeight =
        kMinInteractiveDimension + theme.visualDensity.baseSizeAdjustment.dy;
    final selection = this.selection;
    final multiSelect = selection != null;
    final offset = multiSelect ? 1 : 0;
    final ids = [for (final r in rows) idOf(r)];
    final selectedCount = multiSelect
        ? ids.where(selection.contains).length
        : 0;

    return LayoutBuilder(
      builder: (context, constraints) => ConstrainedBox(
        constraints: BoxConstraints(minWidth: constraints.maxWidth),
        child: DataTable(
          showCheckboxColumn: false,
          dataRowMinHeight: rowHeight,
          dataRowMaxHeight: rowHeight,
          headingRowHeight: rowHeight,
          sortColumnIndex: sortColumn == null ? null : sortColumn! + offset,
          sortAscending: ascending,
          columns: [
            if (multiSelect)
              DataColumn(
                label: Checkbox(
                  key: selectAllKey,
                  tristate: true,
                  value: selectedCount == 0
                      ? false
                      : selectedCount == ids.length
                      ? true
                      : null,
                  onChanged: ids.isEmpty ? null : (_) => onToggleAll?.call(),
                ),
              ),
            for (final (i, column) in columns.indexed)
              DataColumn(
                label: Text(column.label),
                onSort: column.compare == null || onSort == null
                    ? null
                    : (_, asc) => onSort!(i, asc),
              ),
            const DataColumn(
              label: Text('Actions'),
              headingRowAlignment: MainAxisAlignment.end,
            ),
          ],
          rows: [for (final row in rows) _row(context, row, idOf(row))],
        ),
      ),
    );
  }

  DataRow _row(BuildContext context, R row, String id) {
    final selection = this.selection;
    final open = onOpen == null ? null : () => onOpen!(id);
    return DataRow(
      selected: selection?.contains(id) ?? false,
      cells: [
        if (selection != null)
          DataCell(
            Checkbox(
              key: selectKey(id),
              value: selection.contains(id),
              onChanged: (_) => onToggleSelected?.call(id),
            ),
          ),
        for (final column in columns)
          DataCell(column.cell(context, row), onTap: open),
        DataCell(
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final action in actionsFor(row))
                  IconButton(
                    key: actionKey(action.label, id),
                    tooltip: action.label,
                    iconSize: 20,
                    color: action.destructive ? context.colors.error : null,
                    onPressed: action.onPressed,
                    icon: Icon(action.icon),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
