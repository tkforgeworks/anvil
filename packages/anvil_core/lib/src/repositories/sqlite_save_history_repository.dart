import '../db/project_database.dart';
import '../db/save_history.dart';
import 'save_history_repository.dart';

/// `SaveHistoryRepository` on a [ProjectDatabase], over `readRecentSaves`.
final class SqliteSaveHistoryRepository implements SaveHistoryRepository {
  SqliteSaveHistoryRepository(this._db);

  final ProjectDatabase _db;

  @override
  Future<List<SaveHistoryEntry>> recent({int limit = saveHistoryLimit}) async =>
      readRecentSaves(_db, limit: limit);
}
