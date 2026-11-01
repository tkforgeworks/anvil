/// The recipes list page (0.1.6 `RecipesPage.tsx`) on the shared list
/// scaffold (ANVL-188).
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../lists/record_list_page.dart';
import '../../shell/open_editor.dart';
import '../../shell/shell_domain.dart';
import 'recipes_create_dialog.dart';
import 'recipes_fields.dart';
import 'recipes_list_adapter.dart';
import 'recipes_lookups.dart';

/// The station and specialization filter value that matches every recipe;
/// the empty value matches recipes with none, as 0.1.6's `all` and `''`.
const recipeFilterAll = 'all';

/// [RecordListPage] over [RecipeListAdapter] with 0.1.6's Station and
/// Specialization filters, the New Recipe dialog (which opens the new
/// recipe's editor) and Duplicate opening the copy.
class RecipeListPage extends ConsumerStatefulWidget {
  const RecipeListPage({super.key});

  static const stationFilterKey = ValueKey('recipe-filter-station');
  static const specializationFilterKey = ValueKey(
    'recipe-filter-specialization',
  );

  @override
  ConsumerState<RecipeListPage> createState() => _RecipeListPageState();
}

class _RecipeListPageState extends ConsumerState<RecipeListPage> {
  late final _adapter = RecipeListAdapter(ref);
  var _station = recipeFilterAll;
  var _specialization = recipeFilterAll;

  void _open(String id) => openEditor(context, ref, ShellDomain.recipes, id);

  Future<void> _new() async {
    final created = await showCreateRecipeDialog(context);
    if (created != null && mounted) _open(created.id);
  }

  bool _matches(RecipeRecord row) =>
      (_station == recipeFilterAll ||
          (row.craftingStationId ?? '') == _station) &&
      (_specialization == recipeFilterAll ||
          (row.craftingSpecializationId ?? '') == _specialization);

  @override
  Widget build(BuildContext context) {
    final lookups =
        ref.watch(recipeLookupsProvider).value ?? RecipeLookups.empty;
    final filters = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 190,
          child: RecipePicker(
            key: RecipeListPage.stationFilterKey,
            label: 'Station',
            dense: true,
            value: _station,
            options: [
              (value: recipeFilterAll, label: 'All Stations'),
              (value: '', label: 'No Station'),
              for (final s in lookups.stations)
                (value: s.id, label: s.displayName),
            ],
            onChanged: (v) => setState(() => _station = v),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 210,
          child: RecipePicker(
            key: RecipeListPage.specializationFilterKey,
            label: 'Specialization',
            dense: true,
            value: _specialization,
            options: [
              (value: recipeFilterAll, label: 'All Specializations'),
              (value: '', label: 'No Specialization'),
              for (final s in lookups.specializations)
                (value: s.id, label: s.displayName),
            ],
            onChanged: (v) => setState(() => _specialization = v),
          ),
        ),
      ],
    );
    return RecordListPage<RecipeRecord>(
      adapter: _adapter,
      onNew: _new,
      newLabel: '+ New Recipe',
      filterSlot: filters,
      filter: _matches,
      onOpen: _open,
      onDuplicated: (copy) => _open(copy.id),
      emptyBody: 'Create your first crafting recipe to get started.',
    );
  }
}
