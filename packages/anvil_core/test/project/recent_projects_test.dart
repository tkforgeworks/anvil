import 'dart:io';

import 'package:anvil_core/anvil_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// What 0.1.6 writes (`JSON.stringify(list, null, 2)`) for two projects
/// whose files are gone, one carrying the optional `isArchived`.
const _electronFile = '''[
  {
    "projectName": "Old Game",
    "gameTitle": "Old Title",
    "filePath": "/gone/Old Game/database/Old Game.anvil",
    "projectFolder": {
      "root": "/gone/Old Game",
      "database": "/gone/Old Game/database",
      "exports": "/gone/Old Game/exports",
      "temp": "/gone/Old Game/temp",
      "logs": "/gone/Old Game/logs"
    },
    "schemaVersion": 7,
    "lastModifiedAt": "2026-10-11T08:00:00.000Z",
    "fileSize": 245760,
    "recordCounts": {
      "classes": 2,
      "abilities": 3,
      "items": 6,
      "recipes": 2,
      "npcs": 2,
      "lootTables": 1
    },
    "exists": false
  },
  {
    "projectName": "Loose",
    "gameTitle": "Loose",
    "filePath": "/gone/loose.anvil",
    "projectFolder": null,
    "schemaVersion": 5,
    "lastModifiedAt": "2026-09-01T00:00:00.000Z",
    "fileSize": 0,
    "recordCounts": {
      "classes": 0,
      "abilities": 0,
      "items": 0,
      "recipes": 0,
      "npcs": 0,
      "lootTables": 0
    },
    "exists": false,
    "isArchived": true
  }
]''';

ProjectMetadata _meta(String path, {String name = 'P'}) => ProjectMetadata(
  projectName: name,
  gameTitle: name,
  filePath: path,
  projectFolder: null,
  schemaVersion: 7,
  lastModifiedAt: '2026-11-01T00:00:00.000Z',
  fileSize: 1,
  recordCounts: RecordCounts.empty,
);

void main() {
  late Directory temp;
  late RecentProjectsStore store;
  setUp(() {
    temp = Directory.systemTemp.createTempSync('anvil-recent-');
    store = RecentProjectsStore(
      p.join(temp.path, 'support', RecentProjectsStore.fileName),
    );
  });
  tearDown(() => temp.deleteSync(recursive: true));

  void writeRaw(String text) {
    Directory(p.dirname(store.filePath)).createSync(recursive: true);
    File(store.filePath).writeAsStringSync(text);
  }

  test('a missing or corrupt file reads as empty', () {
    expect(store.read(), isEmpty);
    writeRaw('{not json');
    expect(store.read(), isEmpty);
    writeRaw('{"filePath": "/x.anvil"}');
    expect(store.read(), isEmpty);
  });

  test('a 0.1.6 file loads and is written back byte for byte', () {
    writeRaw(_electronFile);
    final entries = store.read();
    expect(entries, hasLength(2));
    expect(entries.first.project.projectName, 'Old Game');
    expect(entries.first.project.projectFolder!.logs, '/gone/Old Game/logs');
    expect(entries.first.project.recordCounts.items, 6);
    expect(entries.last.isArchived, isTrue);

    store.remove('/not/in/the/list.anvil');
    expect(File(store.filePath).readAsStringSync(), _electronFile);
  });

  test('entries are refreshed from disk', () {
    final file = File(p.join(temp.path, 'real.anvil'))
      ..writeAsBytesSync(List.filled(123, 0));
    final stale = _meta(file.path);
    store.add(stale);
    file.writeAsBytesSync(List.filled(456, 0));

    var entry = store.read().single;
    expect(entry.exists, isTrue);
    expect(entry.project.fileSize, 456);
    expect(
      DateTime.parse(entry.project.lastModifiedAt),
      file.statSync().modified.toUtc().copyWith(microsecond: 0),
    );
    expect(entry.project.projectName, 'P');

    file.deleteSync();
    entry = store.read().single;
    expect(entry.exists, isFalse);
    // Reads refresh in memory only, as 0.1.6: the file keeps what add wrote.
    expect(entry.project.fileSize, 1, reason: 'stored value kept');
  });

  test('add puts the newest first, de-duplicates case-insensitively and '
      'keeps ten', () {
    for (var i = 0; i < 12; i++) {
      store.add(_meta('/p/project$i.anvil'));
    }
    var paths = [for (final e in store.read()) e.filePath];
    expect(paths, [for (var i = 11; i >= 2; i--) '/p/project$i.anvil']);

    store.add(_meta('/P/PROJECT5.anvil', name: 'again'));
    paths = [for (final e in store.read()) e.filePath];
    expect(paths.first, '/P/PROJECT5.anvil');
    expect(paths, hasLength(10));
    expect(
      paths.where((path) => path.toLowerCase() == '/p/project5.anvil'),
      hasLength(1),
    );
  });

  test('read de-duplicates and caps a hand-edited file', () {
    store.add(_meta('/p/a.anvil'));
    final one = File(store.filePath).readAsStringSync();
    final body = one.substring(1, one.length - 1).trim();
    writeRaw('[${List.filled(12, body).join(',')}]');
    expect(store.read(), hasLength(1));
  });

  test('remove and clear', () {
    store.add(_meta('/p/a.anvil'));
    store.add(_meta('/p/b.anvil'));
    store.remove('/P/A.ANVIL');
    expect([for (final e in store.read()) e.filePath], ['/p/b.anvil']);
    store.clear();
    expect(store.read(), isEmpty);
    expect(File(store.filePath).readAsStringSync(), '[]');
  });
}
