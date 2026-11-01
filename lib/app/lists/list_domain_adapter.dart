/// What a domain list page (ANVL-191 to 197) supplies to the shared list
/// scaffold (design §13.7): its rows, their identity, its extra columns and
/// the single-record writes, over its repository.
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/widgets.dart';

import '../shell/shell_domain.dart';

/// One column of a record table: the header [label], the [cell] for a row
/// and, when the column is sortable, its [compare]. A sortable column is
/// also offered in the toolbar's sort menu under its label.
class ListColumn<R> {
  const ListColumn({required this.label, required this.cell, this.compare});

  final String label;
  final Widget Function(BuildContext context, R row) cell;

  /// Ascending order; null makes the column unsortable.
  final Comparator<R>? compare;
}

/// A sort the toolbar offers that is not a visible column, such as 0.1.6's
/// `Last Modified` (`updatedAt`, newest first). [ascendingFirst] false makes
/// the first pick of the option sort descending, as 0.1.6's did.
class ListSortOption<R> {
  const ListSortOption({
    required this.label,
    required this.compare,
    this.ascendingFirst = true,
  });

  final String label;

  /// Ascending order.
  final Comparator<R> compare;
  final bool ascendingFirst;
}

/// A domain's list page over its repository.
///
/// Name and Export Key are the scaffold's own leading columns (from
/// [displayNameOf] and [exportKeyOf]); [columns] are the domain columns
/// after them in the active view. The archived view shows Name, Export Key
/// and Deleted At (from [deletedAtOf]), as 0.1.6's `ArchiveTable` did.
/// Search matches [displayNameOf], [exportKeyOf] and [extraSearchText],
/// ignoring case.
///
/// The writes are single-record repository calls; the bulk ones go through
/// `LifecycleRepository`, which the scaffold reads itself. Implementations
/// throw what the repository throws (`RecordNotFound`, `SaveFailed`); the
/// controller turns that into its error line.
///
/// An adapter is usually built with the page's `WidgetRef` and reads its
/// repository provider (`ref.read(itemRepositoryProvider)`) inside each
/// method, never in a build, so it always reaches the open session's
/// repository. Mix in [ListAdapterDefaults] for the optional members.
abstract interface class ListDomainAdapter<R> {
  ShellDomain get domain;

  /// The rows in [mode], in the repository's order (display name ignoring
  /// case).
  Future<List<R>> list(RecordListMode mode);

  String idOf(R row);
  String displayNameOf(R row);
  String exportKeyOf(R row);

  /// The row's `deleted_at` text (SQLite `datetime('now')`), null while
  /// active.
  String? deletedAtOf(R row);

  /// The domain columns of the active view, after Name and Export Key.
  List<ListColumn<R>> get columns;

  /// Sorts offered in the toolbar besides the sortable columns.
  List<ListSortOption<R>> get extraSortOptions;

  /// More text the search matches for [row] (a category name, a type).
  String extraSearchText(R row);

  Future<void> softDelete(String id);
  Future<void> restore(String id);
  Future<void> hardDelete(String id);

  /// The copy, so the page can open it; null when nothing was copied.
  Future<R?> duplicate(String id);
}

/// The defaults of [ListDomainAdapter]'s optional members: no extra sorts
/// and no extra search text.
mixin ListAdapterDefaults<R> implements ListDomainAdapter<R> {
  @override
  List<ListSortOption<R>> get extraSortOptions => const [];

  @override
  String extraSearchText(R row) => '';
}

/// The lifecycle vocabulary's name for a shell domain, for the bulk
/// operations and the delete impact.
extension ShellDomainLifecycle on ShellDomain {
  LifecycleDomain get lifecycleDomain => switch (this) {
    ShellDomain.classes => LifecycleDomain.classes,
    ShellDomain.abilities => LifecycleDomain.abilities,
    ShellDomain.items => LifecycleDomain.items,
    ShellDomain.recipes => LifecycleDomain.recipes,
    ShellDomain.npcs => LifecycleDomain.npcs,
    ShellDomain.lootTables => LifecycleDomain.lootTables,
  };
}

/// Case-insensitive text order, 0.1.6's
/// `localeCompare(b, undefined, { sensitivity: 'base' })` for the names
/// Anvil holds.
int compareIgnoringCase(String a, String b) =>
    a.toLowerCase().compareTo(b.toLowerCase());
