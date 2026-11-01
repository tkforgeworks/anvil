import 'dart:io';

import 'package:anvil_core/anvil_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('anvil-folder-'));
  tearDown(() => temp.deleteSync(recursive: true));

  test('createProjectFolder makes the sanitized folder and its four '
      'sub-folders', () {
    final paths = createProjectFolder(temp.path, 'My: Game');
    final root = p.join(temp.path, 'My_ Game');
    expect(
      paths,
      ProjectFolderPaths(
        root: root,
        database: p.join(root, 'database'),
        exports: p.join(root, 'exports'),
        temp: p.join(root, 'temp'),
        logs: p.join(root, 'logs'),
      ),
    );
    for (final dir in [paths.database, paths.exports, paths.temp, paths.logs]) {
      expect(Directory(dir).existsSync(), isTrue, reason: dir);
    }
  });

  test('createProjectFolder refuses an existing folder and leaves it '
      'alone', () {
    final existing = Directory(p.join(temp.path, 'Game'))..createSync();
    final sentinel = File(p.join(existing.path, 'keep.txt'))
      ..writeAsStringSync('x');

    expect(
      () => createProjectFolder(temp.path, 'Game'),
      throwsA(
        isA<ProjectCreateFailed>().having(
          (e) => e.message,
          'message',
          'Folder already exists: ${existing.path}',
        ),
      ),
    );
    expect(sentinel.readAsStringSync(), 'x');
    expect(existing.listSync(), hasLength(1));
  });

  test('createProjectFolder refuses a name that sanitizes to nothing', () {
    expect(
      () => createProjectFolder(temp.path, '///'),
      throwsA(
        isA<ProjectCreateFailed>().having(
          (e) => e.message,
          'message',
          'Project name produces an empty folder name.',
        ),
      ),
    );
    expect(temp.listSync(), isEmpty);
  });

  test('detectProjectFolder finds a complete folder set only', () {
    final paths = createProjectFolder(temp.path, 'Game');
    final file = p.join(paths.database, 'Game.anvil');
    expect(detectProjectFolder(file), paths);

    Directory(paths.logs).deleteSync();
    expect(detectProjectFolder(file), isNull);

    expect(detectProjectFolder(p.join(temp.path, 'loose.anvil')), isNull);
  });
}
