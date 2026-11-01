import 'item_types.dart';
import 'save_blocker.dart';

/// The rules that refuse an item save (design §8.6): an empty display name
/// or export key (after trimming), and an empty item category or rarity,
/// both `NOT NULL` foreign keys in `items`.
///
/// A category or rarity id that no longer exists is not a blocker; it is a
/// validation issue.
List<SaveBlocker> itemSaveBlockers(ItemDraft draft) => [
  if (draft.displayName.trim().isEmpty)
    const SaveBlocker('displayName', 'Display name is required.'),
  if (draft.exportKey.trim().isEmpty)
    const SaveBlocker('exportKey', 'Export key is required.'),
  if (draft.itemCategoryId.isEmpty)
    const SaveBlocker('itemCategoryId', 'Item category is required.'),
  if (draft.rarityId.isEmpty)
    const SaveBlocker('rarityId', 'Rarity is required.'),
];
