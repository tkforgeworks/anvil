/// The reference data the items list and editor show beside the item rows
/// and drafts: categories, rarities, the custom field definitions of one
/// category and an item's Used By. Each is re-read on every
/// `writeEpochProvider` bump, so a write anywhere refreshes it, and keeps
/// its previous value readable while it reloads.
///
/// Only these providers watch the repository providers; the widgets watch
/// these (the ANVL-185 rule).
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shell/shell_providers.dart';

/// The project's item categories in their settings order.
final itemCategoriesProvider =
    FutureProvider.autoDispose<List<MetaItemCategory>>((ref) {
      ref.watch(writeEpochProvider);
      return ref.watch(metaRepositoryProvider).listItemCategories();
    });

/// The project's rarities in their settings order.
final itemRaritiesProvider = FutureProvider.autoDispose<List<MetaRarity>>((
  ref,
) {
  ref.watch(writeEpochProvider);
  return ref.watch(metaRepositoryProvider).listRarities();
});

/// The custom field definitions scoped to one item category, in their
/// `sort_order`.
final itemCustomFieldDefinitionsProvider = FutureProvider.autoDispose
    .family<List<CustomFieldDefinition>, String>((ref, categoryId) {
      ref.watch(writeEpochProvider);
      return ref
          .watch(customFieldRepositoryProvider)
          .listDefinitions(CustomFieldScope.itemCategory, categoryId);
    });

/// The active recipes and loot tables that reference item `id`.
final itemUsedByProvider = FutureProvider.autoDispose
    .family<ItemUsedBy, String>((ref, id) {
      ref.watch(writeEpochProvider);
      return ref.watch(itemRepositoryProvider).usedBy(id);
    });
