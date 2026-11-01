import 'dart:convert';
import 'dart:io';

import 'package:anvil_core/anvil_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory temp;
  late String project;
  setUp(() {
    temp = Directory.systemTemp.createTempSync('anvil-lock-');
    project = p.join(temp.path, 'project.anvil');
  });
  tearDown(() => temp.deleteSync(recursive: true));

  test('acquire writes compact JSON.stringify output in 0.1.6 key order', () {
    final lock = ProjectLock.acquire(
      project,
      now: DateTime.utc(2026, 11, 1, 10, 20, 30, 456),
    );
    expect(lock.lockPath, '$project.lock');
    expect(
      File('$project.lock').readAsStringSync(),
      '{"pid":$pid,"lockedAt":"2026-11-01T10:20:30.456Z",'
      '"filePath":${jsonEncode(project)}}',
    );
    lock.release();
  });

  test('a lock file written by 0.1.6 makes acquire throw ProjectLocked and '
      'is left as it was', () {
    final electron =
        '{"pid":4242,"lockedAt":"2026-10-11T08:00:00.000Z",'
        '"filePath":${jsonEncode(project)}}';
    File('$project.lock').writeAsStringSync(electron);

    expect(
      () => ProjectLock.acquire(project),
      throwsA(
        isA<ProjectLocked>().having(
          (e) => e.message,
          'message',
          'This project is already open in another Anvil window.',
        ),
      ),
    );
    expect(File('$project.lock').readAsStringSync(), electron);
  });

  test('a second acquire in the same process is refused too', () {
    final lock = ProjectLock.acquire(project);
    expect(() => ProjectLock.acquire(project), throwsA(isA<ProjectLocked>()));
    lock.release();
  });

  test('release deletes the file and is idempotent', () {
    final lock = ProjectLock.acquire(project);
    lock.release();
    expect(lock.isHeld, isFalse);
    expect(File('$project.lock').existsSync(), isFalse);
    lock.release();
    ProjectLock.acquire(project).release();
  });

  test('isFor compares paths case-insensitively', () {
    final lock = ProjectLock.acquire(project);
    expect(lock.isFor(project.toUpperCase()), isTrue);
    expect(lock.isFor('$project.x'), isFalse);
    lock.release();
  });

  test('other file system errors propagate as is', () {
    expect(
      () => ProjectLock.acquire(p.join(temp.path, 'missing', 'x.anvil')),
      throwsA(
        isA<FileSystemException>().having(
          (e) => e is PathExistsException,
          'is PathExistsException',
          isFalse,
        ),
      ),
    );
  });
}
