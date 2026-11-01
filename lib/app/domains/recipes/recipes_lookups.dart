/// The other records a recipe names (items, crafting stations and crafting
/// specializations), loaded once for the list page, the editor and the
/// create dialog.
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shell/shell_providers.dart';

/// Every item (active and soft-deleted, so a reference to a deleted item
/// still shows its name), the crafting stations and the crafting
/// specializations, with lookups by id.
class RecipeLookups {
  RecipeLookups({
    required this.items,
    required this.stations,
    required this.specializations,
  }) : _items = {for (final i in items) i.id: i},
       _stations = {for (final s in stations) s.id: s},
       _specializations = {for (final s in specializations) s.id: s};

  /// Nothing loaded yet.
  static final empty = RecipeLookups(
    items: const [],
    stations: const [],
    specializations: const [],
  );

  /// Ordered by display name ignoring case, as the repository lists them.
  final List<ItemRecord> items;
  final List<MetaCraftingStation> stations;
  final List<MetaCraftingSpecialization> specializations;

  final Map<String, ItemRecord> _items;
  final Map<String, MetaCraftingStation> _stations;
  final Map<String, MetaCraftingSpecialization> _specializations;

  /// The items a picker offers: the ones not soft-deleted.
  List<ItemRecord> get activeItems => [
    for (final i in items)
      if (i.deletedAt == null) i,
  ];

  ItemRecord? item(String id) => _items[id];

  /// The item's display name, or the id when the item is unknown, as
  /// 0.1.6's list fell back to the id.
  String itemName(String id) => _items[id]?.displayName ?? id;

  /// The station's display name, the id when unknown, `-` for none.
  String stationName(String? id) =>
      id == null ? '-' : _stations[id]?.displayName ?? id;

  /// The specialization's display name, the id when unknown, `-` for none.
  String specializationName(String? id) =>
      id == null ? '-' : _specializations[id]?.displayName ?? id;
}

/// The recipe pages' [RecipeLookups], re-read after every write.
///
/// Watches the repository providers, so only providers and the pages'
/// `ref.watch` of this provider see them (the ANVL-185 rule: widgets never
/// watch a repository provider directly).
final recipeLookupsProvider = FutureProvider.autoDispose<RecipeLookups>((
  ref,
) async {
  ref.watch(writeEpochProvider);
  final items = ref
      .watch(itemRepositoryProvider)
      .list(mode: RecordListMode.all);
  final meta = ref.watch(metaRepositoryProvider);
  final stations = meta.listCraftingStations();
  final specializations = meta.listCraftingSpecializations();
  return RecipeLookups(
    items: await items,
    stations: await stations,
    specializations: await specializations,
  );
});

/// 0.1.6's `slugify` (`src/renderer/src/utils/slugify.ts`), which its
/// create dialogs filled the export key with: lower case, every run of
/// characters outside `a-z0-9` one `-`, no leading or trailing `-`. The
/// core's copy is `@internal`.
String slugifyExportKey(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-|-$'), '');
