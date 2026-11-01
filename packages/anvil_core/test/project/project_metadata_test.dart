import 'dart:convert';

import 'package:anvil_core/anvil_core.dart';
import 'package:anvil_core/src/project/project_metadata.dart' show jsIsoString;
import 'package:test/test.dart';

const _folder = ProjectFolderPaths(
  root: '/p/Game',
  database: '/p/Game/database',
  exports: '/p/Game/exports',
  temp: '/p/Game/temp',
  logs: '/p/Game/logs',
);

const _metadata = ProjectMetadata(
  projectName: 'Game',
  gameTitle: 'Title',
  filePath: '/p/Game/database/Game.anvil',
  projectFolder: _folder,
  schemaVersion: 7,
  lastModifiedAt: '2026-11-01T10:20:30.456Z',
  fileSize: 4096,
  recordCounts: RecordCounts(
    classes: 1,
    abilities: 2,
    items: 3,
    recipes: 4,
    npcs: 5,
    lootTables: 6,
  ),
);

void main() {
  test('ProjectMetadata.toJson has the 0.1.6 keys in 0.1.6 order', () {
    final json = _metadata.toJson();
    expect(json.keys, [
      'projectName',
      'gameTitle',
      'filePath',
      'projectFolder',
      'schemaVersion',
      'lastModifiedAt',
      'fileSize',
      'recordCounts',
    ]);
    expect((json['projectFolder'] as Map).keys, [
      'root',
      'database',
      'exports',
      'temp',
      'logs',
    ]);
    expect((json['recordCounts'] as Map).keys, [
      'classes',
      'abilities',
      'items',
      'recipes',
      'npcs',
      'lootTables',
    ]);
  });

  test('RecentProject round-trips through JSON, with and without '
      'isArchived', () {
    for (final archived in [null, true]) {
      final entry = RecentProject(
        project: _metadata,
        exists: false,
        isArchived: archived,
      );
      final json = jsonDecode(jsonEncode(entry.toJson()));
      expect(RecentProject.fromJson(json), entry);
      expect((json as Map).containsKey('isArchived'), archived != null);
      expect(json.keys.toList().sublist(8, 9), ['exists']);
    }
  });

  test('RecentProject.fromJson skips entries without a string filePath and '
      'fills missing fields', () {
    expect(RecentProject.fromJson({'projectName': 'x'}), isNull);
    expect(RecentProject.fromJson('nope'), isNull);

    final sparse = RecentProject.fromJson({
      'filePath': '/a.anvil',
      'recordCounts': {'items': 3},
      'projectFolder': {'root': '/r'},
    })!;
    expect(sparse.project.projectName, '');
    expect(sparse.project.projectFolder, isNull);
    expect(sparse.project.recordCounts, const RecordCounts(items: 3));
    expect(sparse.exists, isFalse);
    expect(sparse.isArchived, isNull);
  });

  test('jsIsoString matches Date.prototype.toISOString', () {
    expect(
      jsIsoString(DateTime.utc(2026, 1, 2, 3, 4, 5, 6, 789)),
      '2026-01-02T03:04:05.006Z',
    );
    final local = DateTime(2026, 11, 1, 12);
    expect(jsIsoString(local), jsIsoString(local.toUtc()));
  });
}
