import 'loot_table_types.dart';
import 'save_blocker.dart';

/// The rules that refuse a loot table save (design §8.6): an empty display
/// name or export key (after trimming), and per entry a weight below 1, a
/// minimum quantity below 1 or a maximum quantity below the minimum (the
/// `loot_table_entries` `CHECK` constraints), with paths such as
/// `entries[2].quantityMax`.
///
/// 0.1.6's `setEntries` clamped these values silently; 0.2.0 refuses
/// instead. The same item may appear in several entries, as in 0.1.6, and
/// an item id that no longer exists is a validation issue, not a blocker.
List<SaveBlocker> lootTableSaveBlockers(LootTableDraft draft) => [
  if (draft.displayName.trim().isEmpty)
    const SaveBlocker('displayName', 'Display name is required.'),
  if (draft.exportKey.trim().isEmpty)
    const SaveBlocker('exportKey', 'Export key is required.'),
  for (final (i, entry) in draft.entries.indexed) ...[
    if (entry.weight < 1)
      SaveBlocker(
        'entries[$i].weight',
        'Entry ${i + 1}: weight must be at least 1.',
      ),
    if (entry.quantityMin < 1)
      SaveBlocker(
        'entries[$i].quantityMin',
        'Entry ${i + 1}: minimum quantity must be at least 1.',
      ),
    if (entry.quantityMax < entry.quantityMin)
      SaveBlocker(
        'entries[$i].quantityMax',
        'Entry ${i + 1}: maximum quantity cannot be less than the minimum.',
      ),
  ],
];
