import 'project_database.dart';

/// Rows kept in `save_history`; the oldest by `saved_at` are trimmed.
const int saveHistoryLimit = 50;

/// One row of `save_history`.
final class SaveHistoryEntry {
  const SaveHistoryEntry({
    required this.id,
    required this.savedAt,
    required this.description,
    required this.isAutoSave,
  });

  final int id;

  /// ISO-style UTC text as 0.1.6 reports it: `2026-11-01T14:00:00Z`.
  final String savedAt;
  final String description;
  final bool isAutoSave;

  @override
  bool operator ==(Object other) =>
      other is SaveHistoryEntry &&
      other.id == id &&
      other.savedAt == savedAt &&
      other.description == description &&
      other.isAutoSave == isAutoSave;

  @override
  int get hashCode => Object.hash(id, savedAt, description, isAutoSave);

  @override
  String toString() => 'SaveHistoryEntry($id, $savedAt, $description)';
}

/// The newest [limit] history rows, newest first.
List<SaveHistoryEntry> readRecentSaves(
  ProjectDatabase db, {
  int limit = saveHistoryLimit,
}) => db.read(
  (tx) => [
    for (final row in tx.select(
      'SELECT id, saved_at, description, is_auto_save FROM save_history '
      'ORDER BY saved_at DESC LIMIT ?',
      [limit],
    ))
      SaveHistoryEntry(
        id: row['id'] as int,
        savedAt: '${(row['saved_at'] as String).replaceFirst(' ', 'T')}Z',
        description: row['description'] as String,
        isAutoSave: row['is_auto_save'] == 1,
      ),
  ],
);
