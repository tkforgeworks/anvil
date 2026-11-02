/// The classes list over `ClassRepository` (0.1.6 `ClassesPage.tsx`).
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:forge_ui/forge_ui.dart';

import '../../lists/list_domain_adapter.dart';
import '../../shell/shell_domain.dart';
import '../../shell/shell_providers.dart';

/// 0.1.6's one column after Name and Export Key: Description, `—` when
/// empty and not sortable (0.1.6 sorted by Name and Last Modified only,
/// from the toolbar). Search matches the name and the export key, the
/// scaffold's own fields.
///
/// Reads the repository at call time through [read] (a `WidgetRef.read`),
/// so it always reaches the open session's repository.
class ClassListAdapter
    with ListAdapterDefaults<ClassRecord>
    implements ListDomainAdapter<ClassRecord> {
  ClassListAdapter(this._read);

  final T Function<T>(ProviderListenable<T> provider) _read;

  ClassRepository get _repository => _read(classRepositoryProvider);

  /// 0.1.6's Description cell: `maxWidth: 300`, one line with an ellipsis.
  static const descriptionMaxWidth = 300.0;

  @override
  ShellDomain get domain => ShellDomain.classes;

  @override
  Future<List<ClassRecord>> list(RecordListMode mode) =>
      _repository.list(mode: mode);

  @override
  String idOf(ClassRecord row) => row.id;

  @override
  String displayNameOf(ClassRecord row) => row.displayName;

  @override
  String exportKeyOf(ClassRecord row) => row.exportKey;

  @override
  String? deletedAtOf(ClassRecord row) => row.deletedAt;

  @override
  List<ListColumn<ClassRecord>> get columns => [
    ListColumn(
      label: 'Description',
      cell: (context, row) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: descriptionMaxWidth),
        child: Text(
          row.description.isEmpty ? '—' : row.description,
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
  ];

  /// 0.1.6's `Last Modified`: `updatedAt`, newest first on the first pick.
  @override
  List<ListSortOption<ClassRecord>> get extraSortOptions => [
    ListSortOption(
      label: 'Last Modified',
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
  Future<ClassRecord?> duplicate(String id) => _repository.duplicate(id);
}
