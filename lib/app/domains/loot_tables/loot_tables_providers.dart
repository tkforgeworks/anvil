/// What the loot table pages read besides the draft: the items and
/// rarities the entry rows name, the NPC counts of the list's Assigned
/// column and the Used By references for the rail.
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shell/shell_providers.dart';

/// Every item (active and soft-deleted, so an entry naming a deleted item
/// still shows its name) and the rarities, with lookups by id.
class LootTableLookups {
  LootTableLookups({required this.items, required this.rarities})
    : _items = {for (final i in items) i.id: i},
      _rarities = {for (final r in rarities) r.id: r};

  /// Nothing loaded yet.
  static final empty = LootTableLookups(items: const [], rarities: const []);

  /// Ordered by display name ignoring case, as the repository lists them.
  final List<ItemRecord> items;
  final List<MetaRarity> rarities;

  final Map<String, ItemRecord> _items;
  final Map<String, MetaRarity> _rarities;

  /// The items an entry picker offers: the ones not soft-deleted, as
  /// 0.1.6's `activeItems`.
  List<ItemRecord> get activeItems => [
    for (final i in items)
      if (i.deletedAt == null) i,
  ];

  ItemRecord? item(String id) => _items[id];

  /// The rarity of item [itemId], null when either is unknown.
  MetaRarity? rarityOfItem(String itemId) {
    final item = _items[itemId];
    return item == null ? null : _rarities[item.rarityId];
  }

  /// Whether [itemId] names a soft-deleted item.
  bool isDeleted(String itemId) => _items[itemId]?.deletedAt != null;
}

/// The loot table pages' [LootTableLookups], re-read after every write.
///
/// Only providers watch the repository providers (the ANVL-185 rule);
/// widgets watch this one.
final lootTableLookupsProvider = FutureProvider.autoDispose<LootTableLookups>((
  ref,
) async {
  ref.watch(writeEpochProvider);
  final items = ref
      .watch(itemRepositoryProvider)
      .list(mode: RecordListMode.all);
  final rarities = ref.watch(metaRepositoryProvider).listRarities();
  return LootTableLookups(items: await items, rarities: await rarities);
});

/// 0.1.6's `assignmentCounts`: loot table id → the number of active NPCs
/// that drop from it, re-read after every write.
final lootTableAssignmentCountsProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) async {
      ref.watch(writeEpochProvider);
      final npcs = await ref.watch(npcRepositoryProvider).list();
      final counts = <String, int>{};
      for (final npc in npcs) {
        if (npc.deletedAt != null) continue;
        if (npc.lootTableId case final id?) {
          counts[id] = (counts[id] ?? 0) + 1;
        }
      }
      return counts;
    });

/// The active NPCs that drop from loot table [id], re-read after every
/// write.
final lootTableUsedByProvider = FutureProvider.autoDispose
    .family<List<UsedByRef>, String>((ref, id) {
      ref.watch(writeEpochProvider);
      return ref.watch(lootTableRepositoryProvider).usedBy(id);
    });
