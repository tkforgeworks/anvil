/// The items list page (0.1.6 `ItemsPage.tsx`) on the shared list
/// scaffold.
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../lists/record_list_page.dart';
import '../../shell/open_editor.dart';
import '../../shell/shell_domain.dart';
import '../../theme/anvil_metrics.dart';
import 'item_create_dialog.dart';
import 'item_meta_providers.dart';
import 'items_list_adapter.dart';

import 'package:anvil/app/editor/widgets/draft_picker.dart';

/// The Items page: the scaffold's toolbar with 0.1.6's Category and Rarity
/// filters (`All Categories` / `All Rarities` first) in its filter slot,
/// applied by the page through `RecordListPage.filter`; `+ New Item`
/// opens the New Item dialog and then the new item, and Duplicate opens
/// the copy (0.1.6 only listed it).
///
/// [onOpen] opens an item; `openEditor` by default, so the editing mode
/// applies.
class ItemListPage extends ConsumerStatefulWidget {
  const ItemListPage({super.key, this.onOpen});

  static const categoryFilterKey = ValueKey('items-category-filter');
  static const rarityFilterKey = ValueKey('items-rarity-filter');

  /// 0.1.6's `minWidth: 180` and `160` on the two filters.
  static const categoryFilterWidth = 180.0;
  static const rarityFilterWidth = 160.0;

  final ValueChanged<String>? onOpen;

  @override
  ConsumerState<ItemListPage> createState() => _ItemListPageState();
}

class _ItemListPageState extends ConsumerState<ItemListPage> {
  late final _adapter = ItemListAdapter(ref);
  String? _categoryId;
  String? _rarityId;

  void _open(String id) {
    if (widget.onOpen case final onOpen?) {
      onOpen(id);
    } else {
      openEditor(context, ref, ShellDomain.items, id);
    }
  }

  Future<void> _create() async {
    final record = await showCreateItemDialog(context);
    if (record != null && mounted) _open(record.id);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(itemCategoriesProvider).value ?? const [];
    final rarities = ref.watch(itemRaritiesProvider).value ?? const [];
    // A filter whose row has gone shows everything.
    final categoryId = categories.any((c) => c.id == _categoryId)
        ? _categoryId
        : null;
    final rarityId = rarities.any((r) => r.id == _rarityId) ? _rarityId : null;

    final filterSlot = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: ItemListPage.categoryFilterWidth,
          child: DraftPicker<String?>(
            key: ItemListPage.categoryFilterKey,
            label: 'Category',
            dense: true,
            value: categoryId,
            options: [
              (value: null, label: 'All Categories'),
              for (final c in categories) (value: c.id, label: c.displayName),
            ],
            onChanged: (id) => setState(() => _categoryId = id),
          ),
        ),
        const SizedBox(width: AnvilSpacing.md),
        SizedBox(
          width: ItemListPage.rarityFilterWidth,
          child: DraftPicker<String?>(
            key: ItemListPage.rarityFilterKey,
            label: 'Rarity',
            dense: true,
            value: rarityId,
            options: [
              (value: null, label: 'All Rarities'),
              for (final r in rarities) (value: r.id, label: r.displayName),
            ],
            onChanged: (id) => setState(() => _rarityId = id),
          ),
        ),
      ],
    );

    return RecordListPage<ItemRecord>(
      adapter: _adapter,
      newLabel: '+ New Item',
      onNew: _create,
      filterSlot: filterSlot,
      filter: categoryId == null && rarityId == null
          ? null
          : (row) =>
                (categoryId == null || row.itemCategoryId == categoryId) &&
                (rarityId == null || row.rarityId == rarityId),
      onOpen: _open,
      onDuplicated: (copy) => _open(copy.id),
    );
  }
}
