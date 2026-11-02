/// What the dashboard reads besides the shell's counts and validation list
/// (design §12.8): the open project's metadata, the weekly deltas and the
/// newest save history rows.
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../shell/shell_providers.dart';

/// How many save history rows the dashboard lists, as 0.1.6's
/// `projectApi.getSaveHistory(5)`.
const dashboardSaveHistoryLimit = 5;

/// The open project's metadata, or null with no project open. It is fixed
/// for the session: `ProjectSession` has no refresh, so the file size is
/// the one read at open where 0.1.6 re-read it from disk on every dashboard
/// refresh.
final dashboardProjectProvider = Provider.autoDispose<ProjectMetadata?>(
  (ref) => ref.watch(projectSessionProvider)?.metadata,
);

/// Per domain: records created in the last 7 days still active, minus
/// records soft-deleted in the last 7 days; re-read after every write.
///
/// Like every provider over a repository it depends on the session through
/// `lifecycleRepositoryProvider`, so it is rebuilt when the session changes
/// and, with no project open, settles as an error instead of throwing in a
/// widget.
final weeklyDeltasProvider = FutureProvider.autoDispose<RecordCounts>((ref) {
  ref.watch(writeEpochProvider);
  return ref.watch(lifecycleRepositoryProvider).weeklyDeltas();
});

/// The newest [dashboardSaveHistoryLimit] save history rows, newest first;
/// re-read after every write.
final saveHistoryProvider = FutureProvider.autoDispose<List<SaveHistoryEntry>>((
  ref,
) {
  ref.watch(writeEpochProvider);
  return ref
      .watch(saveHistoryRepositoryProvider)
      .recent(limit: dashboardSaveHistoryLimit);
});
