/// What the ability pages read besides the draft: the project's stats for
/// the Stat Modifiers tab and the Used By references for the rail.
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shell/shell_providers.dart';

/// The project's stats in `sort_order`, re-read after every write.
final abilityStatsProvider = FutureProvider.autoDispose<List<MetaStat>>((ref) {
  ref.watch(writeEpochProvider);
  return ref.watch(metaRepositoryProvider).listStats();
});

/// The active classes and NPCs ability [id] is assigned to, re-read after
/// every write.
final abilityUsedByProvider = FutureProvider.autoDispose
    .family<AbilityUsedBy, String>((ref, id) {
      ref.watch(writeEpochProvider);
      return ref.watch(abilityRepositoryProvider).usedBy(id);
    });
