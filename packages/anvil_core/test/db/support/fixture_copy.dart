import 'dart:convert';
import 'dart:io';

import 'package:anvil_core/anvil_core.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

/// `packages/anvil_core`, relative to the working directory: `dart test`
/// runs in the package, `flutter test test packages/anvil_core/test` at the
/// repo root. (`Isolate.resolvePackageUriSync` would be neater but is
/// unsupported under `flutter_tester`.)
final String packageRoot = () {
  for (final candidate in ['.', p.join('packages', 'anvil_core')]) {
    final marker = p.join(candidate, 'test', 'fixtures', 'sample-0.1.6.anvil');
    if (File(marker).existsSync()) return p.normalize(p.absolute(candidate));
  }
  throw StateError(
    'Run the tests from packages/anvil_core or the repo root '
    '(working directory: ${Directory.current.path})',
  );
}();

final String fixturesDir = p.join(packageRoot, 'test', 'fixtures');

/// The Electron 0.1.6 project file. Never opened directly.
final String fixturePath = p.join(fixturesDir, 'sample-0.1.6.anvil');

final List<int> _fixtureBytes = File(fixturePath).readAsBytesSync();

/// A temp directory per test, holding a fresh copy of the fixture, plus the
/// `tearDown` that checks the fixture itself was never modified.
///
/// Call [FixtureCopy.setUpEach] once at the top of a test file's `main` (or
/// a group); it registers `setUp`/`tearDown` and returns a getter.
final class FixtureCopy {
  FixtureCopy._(this.dir);

  final Directory dir;
  final List<ProjectDatabase> _opened = [];

  static FixtureCopy Function() setUpEach() {
    FixtureCopy? current;
    setUp(() {
      current = FixtureCopy._(
        Directory.systemTemp.createTempSync('anvil-core-db-test-'),
      );
    });
    tearDown(() {
      final copy = current!;
      for (final db in copy._opened) {
        db.close();
      }
      copy.dir.deleteSync(recursive: true);
      current = null;
      expect(
        _sameBytes(File(fixturePath).readAsBytesSync(), _fixtureBytes),
        isTrue,
        reason: 'test/fixtures/sample-0.1.6.anvil must never change',
      );
    });
    return () => current!;
  }

  /// A path inside this test's temp directory.
  String pathFor(String name) => p.join(dir.path, name);

  /// Copies the fixture to [name] and returns the copy's path. The fixture
  /// is in rollback-journal mode with no sidecars, so a file copy is safe.
  String copyFixture([String name = 'project.anvil']) {
    final target = pathFor(name);
    File(fixturePath).copySync(target);
    return target;
  }

  /// Opens a fresh copy of the fixture read-write.
  ProjectDatabase openFixture() => track(ProjectDatabase.open(copyFixture()));

  /// Opens an empty, unmigrated project file.
  ProjectDatabase openEmpty([String name = 'fresh.anvil']) =>
      track(ProjectDatabase.open(pathFor(name)));

  /// Registers [db] to be closed in `tearDown`.
  ProjectDatabase track(ProjectDatabase db) {
    _opened.add(db);
    return db;
  }
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Collapses whitespace runs to one space and trims, as the parity tests
/// compare stored SQL.
String normalizeSql(Object? sql) =>
    (sql as String).replaceAll(RegExp(r'\s+'), ' ').trim();

/// `SELECT type, name[, tbl_name], sql FROM sqlite_master WHERE sql IS NOT
/// NULL ORDER BY type, name`, with `sql` normalized.
List<Map<String, Object?>> masterRows(
  Database db, {
  bool withTableName = false,
}) {
  final columns = withTableName
      ? 'type, name, tbl_name, sql'
      : 'type, name, sql';
  return [
    for (final row in db.select(
      'SELECT $columns FROM sqlite_master WHERE sql IS NOT NULL '
      'ORDER BY type, name',
    ))
      {...row, 'sql': normalizeSql(row['sql'])},
  ];
}

/// A `schema-*.json` fixture with `sql` normalized.
List<Map<String, Object?>> loadMasterJson(String name) {
  final rows = jsonDecode(
    File(p.join(fixturesDir, name)).readAsStringSync(),
  ) as List<Object?>;
  return [
    for (final row in rows.cast<Map<String, Object?>>())
      {...row, 'sql': normalizeSql(row['sql'])},
  ];
}

/// Rows of [sql] as plain maps, for before/after comparisons.
List<Map<String, Object?>> rowsOf(
  Database db,
  String sql, [
  List<Object?> parameters = const [],
]) => [
  for (final row in db.select(sql, parameters)) {...row},
];
