import '../db/save_history.dart';

/// The save history feed: replaces 0.1.6's `project:get-save-history`
/// (`save-history-service.ts` `getRecentSaves`).
///
/// Read only: rows are written by `ProjectDatabase.saveTransaction`, one per
/// committed change, and trimmed there to `saveHistoryLimit`.
abstract interface class SaveHistoryRepository {
  /// The newest [limit] rows, newest first by `saved_at`, with `saved_at`
  /// as `YYYY-MM-DDTHH:MM:SSZ` as 0.1.6 reported it.
  Future<List<SaveHistoryEntry>> recent({int limit = saveHistoryLimit});
}
