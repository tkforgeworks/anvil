/// The columns and sorts a record list shows in each view: the scaffold's
/// own Name, Export Key and Deleted At, and the adapter's domain columns.
library;

import 'package:flutter/material.dart';
import 'package:forge_ui/forge_ui.dart';

import 'list_domain_adapter.dart';

/// Which rows a list page shows: the Active/Archived toggle.
enum ListViewMode {
  active('Active'),
  archived('Archived');

  const ListViewMode(this.label);

  final String label;
}

/// The column labels the scaffold owns.
abstract final class ListColumnLabels {
  static const name = 'Name';
  static const exportKey = 'Export Key';
  static const deletedAt = 'Deleted At';
}

/// The table columns for [mode]: Name and Export Key, then the adapter's
/// columns when active or Deleted At when archived (0.1.6 `ArchiveTable`).
List<ListColumn<R>> listColumnsFor<R>(
  ListDomainAdapter<R> adapter,
  ListViewMode mode,
) {
  final archived = mode == ListViewMode.archived;
  return [
    ListColumn<R>(
      label: ListColumnLabels.name,
      compare: (a, b) => compareIgnoringCase(
        adapter.displayNameOf(a),
        adapter.displayNameOf(b),
      ),
      cell: (context, row) => Text(
        adapter.displayNameOf(row),
        style: context.text.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: archived ? context.colors.onSurfaceVariant : null,
        ),
      ),
    ),
    ListColumn<R>(
      label: ListColumnLabels.exportKey,
      compare: (a, b) =>
          adapter.exportKeyOf(a).compareTo(adapter.exportKeyOf(b)),
      cell: (context, row) => Text(
        adapter.exportKeyOf(row),
        style: ForgeType.code(size: 13, color: context.colors.onSurfaceVariant),
      ),
    ),
    if (archived)
      ListColumn<R>(
        label: ListColumnLabels.deletedAt,
        compare: (a, b) => (adapter.deletedAtOf(a) ?? '').compareTo(
          adapter.deletedAtOf(b) ?? '',
        ),
        cell: (context, row) => Text(
          formatDeletedAt(adapter.deletedAtOf(row)),
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      )
    else
      ...adapter.columns,
  ];
}

/// The sorts the toolbar offers in [mode]: every sortable column of
/// [listColumnsFor], then the adapter's extra options.
List<ListSortOption<R>> listSortOptionsFor<R>(
  ListDomainAdapter<R> adapter,
  ListViewMode mode,
) => [
  for (final column in listColumnsFor(adapter, mode))
    if (column.compare case final compare?)
      ListSortOption<R>(label: column.label, compare: compare),
  ...adapter.extraSortOptions,
];

/// 0.1.6's `formatDeletedAt`: `new Date(iso + 'Z').toLocaleString()` in
/// the en-US form (`10/31/2026, 2:05:09 PM`, local time), `—` when unset,
/// the text itself when it does not parse.
String formatDeletedAt(String? text) {
  if (text == null || text.isEmpty) return '—';
  final utc = DateTime.tryParse(text.endsWith('Z') ? text : '${text}Z');
  if (utc == null) return text;
  final t = utc.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final meridiem = t.hour < 12 ? 'AM' : 'PM';
  return '${t.month}/${t.day}/${t.year}, '
      '$hour12:${two(t.minute)}:${two(t.second)} $meridiem';
}
