/// The items list over `ItemRepository` (0.1.6 `ItemsPage.tsx`).
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../../lists/list_domain_adapter.dart';
import '../../settings/project/rarity_section.dart' show rarityHexPattern;
import '../../shell/shell_domain.dart';
import '../../shell/shell_providers.dart';
import '../../theme/color_math.dart';
import 'item_meta_providers.dart';

/// 0.1.6's `maxWidth: 260` on the description cell.
const _descriptionMaxWidth = 260.0;

/// 0.1.6's columns after Name and Export Key: Category (its name, the id
/// when it no longer exists), Rarity (an outlined chip in the rarity's
/// colour, the id when it no longer exists) and Description (`-` when
/// empty). 0.1.6 sorted by Name or Last Modified only, so these columns do
/// not sort; Last Modified is the extra sort, newest first.
///
/// Search also matches the category and rarity names; 0.1.6 searched the
/// display name only.
///
/// The repository is read through [ref] in each call, never held.
class ItemListAdapter
    with ListAdapterDefaults<ItemRecord>
    implements ListDomainAdapter<ItemRecord> {
  ItemListAdapter(this.ref);

  final WidgetRef ref;

  ItemRepository get _repository => ref.read(itemRepositoryProvider);

  @override
  ShellDomain get domain => ShellDomain.items;

  @override
  Future<List<ItemRecord>> list(RecordListMode mode) =>
      _repository.list(mode: mode);

  @override
  String idOf(ItemRecord row) => row.id;

  @override
  String displayNameOf(ItemRecord row) => row.displayName;

  @override
  String exportKeyOf(ItemRecord row) => row.exportKey;

  @override
  String? deletedAtOf(ItemRecord row) => row.deletedAt;

  @override
  List<ListColumn<ItemRecord>> get columns => [
    ListColumn(
      label: 'Category',
      cell: (context, row) => _CategoryCell(row.itemCategoryId),
    ),
    ListColumn(
      label: 'Rarity',
      cell: (context, row) => _RarityCell(row.rarityId),
    ),
    ListColumn(
      label: 'Description',
      cell: (context, row) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _descriptionMaxWidth),
        child: Text(
          row.description.isEmpty ? '-' : row.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ),
    ),
  ];

  @override
  List<ListSortOption<ItemRecord>> get extraSortOptions => [
    ListSortOption(
      label: 'Last Modified',
      compare: (a, b) => a.updatedAt.compareTo(b.updatedAt),
      ascendingFirst: false,
    ),
  ];

  @override
  String extraSearchText(ItemRecord row) {
    final category = ref
        .read(itemCategoriesProvider)
        .value
        ?.where((c) => c.id == row.itemCategoryId)
        .firstOrNull;
    final rarity = ref
        .read(itemRaritiesProvider)
        .value
        ?.where((r) => r.id == row.rarityId)
        .firstOrNull;
    return [?category?.displayName, ?rarity?.displayName].join('\n');
  }

  @override
  Future<void> softDelete(String id) => _repository.softDelete(id);

  @override
  Future<void> restore(String id) => _repository.restore(id);

  @override
  Future<void> hardDelete(String id) => _repository.hardDelete(id);

  @override
  Future<ItemRecord?> duplicate(String id) => _repository.duplicate(id);
}

class _CategoryCell extends ConsumerWidget {
  const _CategoryCell(this.id);

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(itemCategoriesProvider).value ?? const [];
    final category = categories.where((c) => c.id == id).firstOrNull;
    return Text(
      category?.displayName ?? id,
      style: context.text.bodyMedium?.copyWith(
        color: context.colors.onSurfaceVariant,
      ),
    );
  }
}

class _RarityCell extends ConsumerWidget {
  const _RarityCell(this.id);

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rarities = ref.watch(itemRaritiesProvider).value ?? const [];
    final rarity = rarities.where((r) => r.id == id).firstOrNull;
    if (rarity == null) {
      return Text(
        id,
        style: context.text.bodyMedium?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      );
    }
    final hex = rarity.colorHex.trim();
    // The rarity's colour is the user's data, built through `hexToColor`,
    // not a theme colour (as the project settings' swatch).
    final border = rarityHexPattern.hasMatch(hex)
        ? hexToColor(hex)
        : context.colors.outline;
    return Chip(
      label: Text(rarity.displayName),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: BorderSide(color: border),
      backgroundColor: Colors.transparent,
    );
  }
}
