/// What the class pages read besides the draft: every ability for the
/// assignment picker and row labels, and the Used By references for the
/// rail.
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shell/shell_providers.dart';

/// Every ability, soft-deleted ones included (`RecordListMode.all`) so an
/// assigned ability that was deleted still has a name and its warning;
/// re-read after every write.
final classAbilitiesProvider = FutureProvider.autoDispose<List<AbilityRecord>>((
  ref,
) {
  ref.watch(writeEpochProvider);
  return ref.watch(abilityRepositoryProvider).list(mode: RecordListMode.all);
});

/// The active NPCs class [id] is assigned to, re-read after every write.
final classUsedByProvider = FutureProvider.autoDispose
    .family<List<UsedByRef>, String>((ref, id) {
      ref.watch(writeEpochProvider);
      return ref.watch(classRepositoryProvider).usedBy(id);
    });
