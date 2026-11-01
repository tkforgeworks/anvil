/// The recipes list over [RecipeRepository] (0.1.6 `RecipesPage.tsx`).
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../../lists/list_domain_adapter.dart';
import '../../shell/shell_domain.dart';
import '../../shell/shell_providers.dart';
import 'recipes_lookups.dart';

/// 0.1.6's columns after Name and Export Key: Output (`<item> x<n>`),
/// Station and Specialization (`-` when unset). 0.1.6 sorted by name only,
/// so these columns are not sortable. The repository is read through
/// [ref] inside each call, never in a build.
class RecipeListAdapter
    with ListAdapterDefaults<RecipeRecord>
    implements ListDomainAdapter<RecipeRecord> {
  RecipeListAdapter(this.ref);

  final WidgetRef ref;

  RecipeRepository get _repository => ref.read(recipeRepositoryProvider);

  @override
  ShellDomain get domain => ShellDomain.recipes;

  @override
  Future<List<RecipeRecord>> list(RecordListMode mode) =>
      _repository.list(mode: mode);

  @override
  String idOf(RecipeRecord row) => row.id;

  @override
  String displayNameOf(RecipeRecord row) => row.displayName;

  @override
  String exportKeyOf(RecipeRecord row) => row.exportKey;

  @override
  String? deletedAtOf(RecipeRecord row) => row.deletedAt;

  @override
  List<ListColumn<RecipeRecord>> get columns => [
    ListColumn(
      label: 'Output',
      cell: (context, row) => _LookupCell(
        (l) => '${l.itemName(row.outputItemId)} x${row.outputQuantity}',
      ),
    ),
    ListColumn(
      label: 'Station',
      cell: (context, row) =>
          _LookupCell((l) => l.stationName(row.craftingStationId)),
    ),
    ListColumn(
      label: 'Specialization',
      cell: (context, row) => _LookupCell(
        (l) => l.specializationName(row.craftingSpecializationId),
      ),
    ),
  ];

  @override
  Future<void> softDelete(String id) => _repository.softDelete(id);

  @override
  Future<void> restore(String id) => _repository.restore(id);

  @override
  Future<void> hardDelete(String id) => _repository.hardDelete(id);

  @override
  Future<RecipeRecord?> duplicate(String id) => _repository.duplicate(id);
}

/// A secondary-text cell resolved through [recipeLookupsProvider]; the
/// ids show until the lookups load.
class _LookupCell extends ConsumerWidget {
  const _LookupCell(this.text);

  final String Function(RecipeLookups lookups) text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lookups =
        ref.watch(recipeLookupsProvider).value ?? RecipeLookups.empty;
    return Text(
      text(lookups),
      overflow: TextOverflow.ellipsis,
      style: context.text.bodyMedium?.copyWith(
        color: context.colors.onSurfaceVariant,
      ),
    );
  }
}
