import 'package:sqlite3/sqlite3.dart';

import '../db/errors.dart';
import '../db/project_database.dart';
import '../db/save_descriptions.dart';
import '../domain/custom_template.dart';
import 'record_id.dart';
import 'template_repository.dart';

const String _table = 'custom_templates';

const String _columns =
    'id, name, description, template_source, format, created_at, updated_at';

/// 0.1.6 created templates with `new Date().toISOString()`; SQLite produces
/// the same `YYYY-MM-DDTHH:MM:SS.sssZ` text.
const String _isoNow = "strftime('%Y-%m-%dT%H:%M:%fZ', 'now')";

CustomTemplate _template(Row r) => CustomTemplate(
  id: r['id'] as String,
  name: r['name'] as String,
  description: r['description'] as String,
  templateSource: r['template_source'] as String,
  format: r['format'] as String,
  createdAt: r['created_at'] as String,
  updatedAt: r['updated_at'] as String,
);

/// [TemplateRepository] over `custom_templates` with 0.1.6's SQL.
final class SqliteTemplateRepository implements TemplateRepository {
  SqliteTemplateRepository(this._db);

  final ProjectDatabase _db;

  @override
  Future<List<CustomTemplate>> list() async => _db.read(
    (tx) => [
      for (final r in tx.select(
        'SELECT $_columns FROM $_table ORDER BY name COLLATE NOCASE',
      ))
        _template(r),
    ],
  );

  @override
  Future<CustomTemplate> get(String id) async => _get(id);

  CustomTemplate _get(String id) => _db.read((tx) => _selectOne(tx.select, id));

  @override
  Future<CustomTemplate> create(CreateTemplateInput input) async =>
      _db.saveTransaction(templateChanged(input.name), (tx) {
        final id = newRecordId();
        tx.execute(
          'INSERT INTO $_table (id, name, description, template_source, '
          'format, created_at, updated_at) '
          'VALUES (?, ?, ?, ?, ?, $_isoNow, $_isoNow)',
          [
            id,
            input.name,
            input.description,
            input.templateSource,
            input.format,
          ],
        );
        return _selectOne(tx.select, id);
      });

  @override
  Future<CustomTemplate> update(String id, UpdateTemplateInput input) async {
    // The history description needs the name before the transaction opens;
    // the read and the save run back to back on this isolate.
    final existing = _get(id);
    final name = input.name ?? existing.name;
    return _db.saveTransaction(templateChanged(name), (tx) {
      tx.execute(
        'UPDATE $_table SET name = ?, description = ?, template_source = ?, '
        "format = ?, updated_at = datetime('now') WHERE id = ?",
        [
          name,
          input.description ?? existing.description,
          input.templateSource ?? existing.templateSource,
          input.format ?? existing.format,
          id,
        ],
      );
      if (tx.changes != 1) throw RecordNotFound(_table, id);
      return _selectOne(tx.select, id);
    });
  }

  @override
  Future<void> delete(String id) async {
    final existing = _get(id);
    _db.saveTransaction(templateChanged(existing.name), (tx) {
      tx.execute('DELETE FROM $_table WHERE id = ?', [id]);
      if (tx.changes != 1) throw RecordNotFound(_table, id);
    });
  }

  static CustomTemplate _selectOne(
    ResultSet Function(String sql, [List<Object?> parameters]) select,
    String id,
  ) {
    final rows = select('SELECT $_columns FROM $_table WHERE id = ?', [id]);
    if (rows.isEmpty) throw RecordNotFound(_table, id);
    return _template(rows.first);
  }
}
