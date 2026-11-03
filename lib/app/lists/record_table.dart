import 'package:flutter/material.dart';
import 'package:forge_ui/forge_ui.dart';

import 'list_domain_adapter.dart';

/// One icon button in a row's Actions cell, or one row of a row's context
/// menu.
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
///
/// With [contextMenuFor], a right-click on a data cell of a row it returns
/// actions for opens the table's one context menu at the pointer
/// (ANVL-117): a [MenuAnchor] over the whole table, so opening the menu for
/// another row closes the first, and click-outside, Esc, the arrow keys and
/// Enter come from the anchor. Focus lands on the first row when it opens.
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
    this.contextMenuFor,
  });

  /// The select-all checkbox in the header.
  static const selectAllKey = ValueKey('record-table-select-all');

  /// The checkbox of row [id].
  static Key selectKey(String id) => ValueKey('record-table-select-$id');

  /// Action [label] (its tooltip) of row [id].
  static Key actionKey(String label, String id) =>
      ValueKey('record-table-action-$label-$id');

  /// Context menu row [label] for row [id].
  static Key contextMenuKey(String label, String id) =>
      ValueKey('record-table-menu-$label-$id');

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

  /// The context menu rows of [row]; null (or a null or empty result for a
  /// row) gives no menu.
  final List<RecordRowAction>? Function(R row)? contextMenuFor;

  @override
  Widget build(BuildContext context) {
    if (contextMenuFor == null) return _table(context, null);
    return _ContextMenuRegion(builder: _table);
  }

  Widget _table(BuildContext context, _OpenContextMenu? openMenu) {
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

    // The table fills the available width and, when its columns need more
    // (long names or six columns at the 1400 px minimum window), scrolls
    // sideways instead of overflowing: a `DataTable` cannot shrink its
    // headers below their text.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
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
            rows: [
              for (final row in rows) _row(context, row, idOf(row), openMenu),
            ],
          ),
        ),
      ),
    );
  }

  DataRow _row(
    BuildContext context,
    R row,
    String id,
    _OpenContextMenu? openMenu,
  ) {
    final selection = this.selection;
    final open = onOpen == null ? null : () => onOpen!(id);
    final menu = openMenu == null ? null : contextMenuFor!(row);
    Widget cell(Widget child) {
      if (menu == null || menu.isEmpty) return child;
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapUp: (details) =>
            openMenu!(id, menu, details.globalPosition),
        // Fills the cell's content area, so a right-click beside a short
        // value still reaches the row.
        child: Align(alignment: AlignmentDirectional.centerStart, child: child),
      );
    }

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
          DataCell(cell(column.cell(context, row)), onTap: open),
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

/// Opens the context menu of row [id] with [actions] at [globalPosition].
typedef _OpenContextMenu = void Function(
  String id,
  List<RecordRowAction> actions,
  Offset globalPosition,
);

/// The [MenuAnchor] around a [RecordTable] and the row its menu is open
/// for.
class _ContextMenuRegion extends StatefulWidget {
  const _ContextMenuRegion({required this.builder});

  final Widget Function(BuildContext context, _OpenContextMenu open) builder;

  @override
  State<_ContextMenuRegion> createState() => _ContextMenuRegionState();
}

class _ContextMenuRegionState extends State<_ContextMenuRegion> {
  final _controller = MenuController();
  final _firstItem = FocusNode(debugLabel: 'record-table-menu-first');
  String? _id;
  List<RecordRowAction> _actions = const [];

  @override
  void dispose() {
    _firstItem.dispose();
    super.dispose();
  }

  void _open(String id, List<RecordRowAction> actions, Offset globalPosition) {
    final box = context.findRenderObject();
    if (box is! RenderBox) return;
    setState(() {
      _id = id;
      _actions = actions;
    });
    _controller.open(position: box.globalToLocal(globalPosition));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.isOpen) _firstItem.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final id = _id;
    return MenuAnchor(
      controller: _controller,
      menuChildren: [
        if (id != null)
          for (final (i, action) in _actions.indexed)
            MenuItemButton(
              key: RecordTable.contextMenuKey(action.label, id),
              focusNode: i == 0 ? _firstItem : null,
              leadingIcon: Icon(action.icon, size: 18),
              style: action.destructive
                  ? MenuItemButton.styleFrom(
                      foregroundColor: colors.error,
                      iconColor: colors.error,
                    )
                  : null,
              onPressed: action.onPressed,
              child: Text(action.label),
            ),
      ],
      child: widget.builder(context, _open),
    );
  }
}
