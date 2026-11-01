/// The abilities list over `AbilityRepository` (0.1.6 `AbilitiesPage.tsx`).
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:forge_ui/forge_ui.dart';

import '../../lists/list_domain_adapter.dart';
import '../../shell/shell_domain.dart';
import '../../shell/shell_providers.dart';

/// 0.1.6's columns after Name and Export Key: Type and Description, each
/// `—` when empty, neither sortable (0.1.6 sorted by Name and Last
/// Modified only, from the toolbar). Search matches the name and the
/// export key, the scaffold's own fields.
///
/// Reads the repository at call time through [read] (a `WidgetRef.read`),
/// so it always reaches the open session's repository.
class AbilityListAdapter
    with ListAdapterDefaults<AbilityRecord>
    implements ListDomainAdapter<AbilityRecord> {
  AbilityListAdapter(this._read);

  final T Function<T>(ProviderListenable<T> provider) _read;

  AbilityRepository get _repository => _read(abilityRepositoryProvider);

  /// 0.1.6's Description cell: `maxWidth: 260`, one line with an ellipsis.
  static const descriptionMaxWidth = 260.0;

  @override
  ShellDomain get domain => ShellDomain.abilities;

  @override
  Future<List<AbilityRecord>> list(RecordListMode mode) =>
      _repository.list(mode: mode);

  @override
  String idOf(AbilityRecord row) => row.id;

  @override
  String displayNameOf(AbilityRecord row) => row.displayName;

  @override
  String exportKeyOf(AbilityRecord row) => row.exportKey;

  @override
  String? deletedAtOf(AbilityRecord row) => row.deletedAt;

  @override
  List<ListColumn<AbilityRecord>> get columns => [
    ListColumn(
      label: 'Type',
      cell: (context, row) => Text(
        row.abilityType.isEmpty ? '—' : row.abilityType,
        style: _secondary(context),
      ),
    ),
    ListColumn(
      label: 'Description',
      cell: (context, row) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: descriptionMaxWidth),
        child: Text(
          row.description.isEmpty ? '—' : row.description,
          style: _secondary(context),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
  ];

  /// 0.1.6's `Last Modified`: `updatedAt`, newest first on the first pick.
  @override
  List<ListSortOption<AbilityRecord>> get extraSortOptions => [
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
  Future<AbilityRecord?> duplicate(String id) => _repository.duplicate(id);

  static TextStyle? _secondary(BuildContext context) =>
      context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant);
}
