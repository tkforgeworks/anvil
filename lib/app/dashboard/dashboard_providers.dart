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

/// The open project's metadata, or null with no project open, re-read from
/// the database and the file after every write through
/// `ProjectService.refreshMetadata` (which also stores it on the session),
/// as 0.1.6 re-read it on every dashboard refresh. The file size and
/// modification time are the main file's, so in WAL mode they move when a
/// checkpoint runs (the quiet checkpoint follows writes by a few seconds).
final dashboardProjectProvider = Provider.autoDispose<ProjectMetadata?>((ref) {
  ref.watch(writeEpochProvider);
  final session = ref.watch(projectSessionProvider);
  if (session == null || !session.isOpen) return session?.metadata;
  return ref.read(projectServiceProvider).refreshMetadata(session);
});

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
