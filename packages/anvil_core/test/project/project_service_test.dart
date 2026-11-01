import 'dart:convert';
import 'dart:io';

import 'package:anvil_core/anvil_core.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import '../db/support/fixture_copy.dart';

final _now = DateTime.utc(2026, 11, 1, 10, 20, 30, 456);

const _fixtureCounts = RecordCounts(
  classes: 2,
  abilities: 2,
  items: 5,
  recipes: 2,
  npcs: 2,
  lootTables: 1,
);

void main() {
  final fixture = FixtureCopy.setUpEach();
  late ProjectService service;
  late String support;

  setUp(() {
    support = fixture().pathFor('support');
    service = ProjectService(supportDirectory: support, clock: () => _now);
  });

  bool locked(String path) => File('$path.lock').existsSync();

  Map<String, Object?> lockJson(String path) =>
      jsonDecode(File('$path.lock').readAsStringSync()) as Map<String, Object?>;

  Future<ProjectSession> openOk(String path) async {
    final result = await service.open(path);
    expect(result, isA<ProjectOpened>());
    return (result as ProjectOpened).session;
  }

  /// What 0.1.x sees for a file made before migration 007: the step's row
  /// gone from `schema_migrations` and `project_info.schema_version` at 6.
  String downgradedCopy({required bool wal}) {
    final path = fixture().copyFixture();
    final db = wal ? ProjectDatabase.open(path).handle : sqlite3.open(path);
    db.execute(
      "DELETE FROM schema_migrations WHERE filename = '007_save_history'",
    );
    db.execute('UPDATE project_info SET schema_version = 6 WHERE id = 1');
    db.close();
    expect(File('$path-wal').existsSync(), isFalse);
    return path;
  }

  group('create', () {
    test('builds the folder tree, file, lock, project_info and recent '
        'entry', () async {
      final parent = fixture().pathFor('projects');
      final session = await service.create(
        projectName: '  My: Game ',
        gameTitle: ' Saga ',
        parentFolder: parent,
      );
      final root = p.join(parent, 'My_ Game');
      final file = p.join(root, 'database', 'My_ Game.anvil');
      for (final dir in ['database', 'exports', 'temp', 'logs']) {
        expect(Directory(p.join(root, dir)).existsSync(), isTrue);
      }
      expect(session.filePath, file);
      expect(File(file).existsSync(), isTrue);
      expect(lockJson(file).keys, ['pid', 'lockedAt', 'filePath']);
      expect(lockJson(file)['filePath'], file);
      expect(lockJson(file)['lockedAt'], '2026-11-01T10:20:30.456Z');

      final info = session.database.handle
          .select(
            'SELECT project_name, game_title, schema_version FROM project_info',
          )
          .single;
      expect(info['project_name'], 'My: Game');
      expect(info['game_title'], 'Saga');
      expect(info['schema_version'], currentSchemaVersion);
      expect(pendingMigrations(session.database), isEmpty);

      final meta = session.metadata;
      expect(meta.projectName, 'My: Game');
      expect(meta.gameTitle, 'Saga');
      expect(meta.projectFolder, detectProjectFolder(file));
      expect(meta.projectFolder!.root, root);
      expect(meta.schemaVersion, 7);
      expect(meta.recordCounts, RecordCounts.empty);

      final recent = service.recentProjects();
      expect(recent.single.filePath, file);
      expect(recent.single.exists, isTrue);
      expect(
        File(p.join(support, 'recent-projects.json')).existsSync(),
        isTrue,
      );

      await service.close(session);
      expect(locked(file), isFalse);
    });

    test('requires a name and a game title', () async {
      for (final (name, title, message) in [
        (' ', 'T', 'Project name is required.'),
        ('N', '', 'Game title is required.'),
      ]) {
        await expectLater(
          service.create(
            projectName: name,
            gameTitle: title,
            parentFolder: fixture().dir.path,
          ),
          throwsA(
            isA<ProjectCreateFailed>().having(
              (e) => e.message,
              'message',
              message,
            ),
          ),
        );
      }
    });

    test('an existing folder fails and is left alone', () async {
      final existing = Directory(fixture().pathFor('Game'))..createSync();
      File(p.join(existing.path, 'keep.txt')).writeAsStringSync('x');
      await expectLater(
        service.create(
          projectName: 'Game',
          gameTitle: 'T',
          parentFolder: fixture().dir.path,
        ),
        throwsA(isA<ProjectCreateFailed>()),
      );
      expect(File(p.join(existing.path, 'keep.txt')).existsSync(), isTrue);
    });

    test(
      'a failure after the folder was made removes the whole tree',
      () async {
        // 248 characters: the folder and `<name>.anvil` fit in a 255-byte name,
        // `<name>.anvil.lock` does not, so the lock step fails.
        final name = 'n' * 248;
        final parent = fixture().pathFor('projects');
        Object? thrown;
        try {
          await service.create(
            projectName: name,
            gameTitle: 'T',
            parentFolder: parent,
          );
        } catch (e) {
          thrown = e;
        }
        expect(thrown, isA<ProjectCreateFailed>());
        expect((thrown as ProjectCreateFailed).cause, isNotNull);
        expect(Directory(p.join(parent, name)).existsSync(), isFalse);
        expect(service.recentProjects(), isEmpty);
      },
    );
  });

  group('open', () {
    test('opens the 0.1.6 fixture with its project_info and counts', () async {
      final path = fixture().copyFixture();
      final session = await openOk(path);

      final meta = session.metadata;
      expect(meta.projectName, 'Spike Fixture');
      expect(meta.gameTitle, 'Forge & Fable');
      expect(meta.filePath, path);
      expect(meta.projectFolder, isNull);
      expect(meta.schemaVersion, 7);
      expect(meta.recordCounts, _fixtureCounts);
      expect(meta.fileSize, File(path).lengthSync());
      expect(
        DateTime.parse(meta.lastModifiedAt),
        File(path).statSync().modified.toUtc().copyWith(microsecond: 0),
      );
      expect(locked(path), isTrue);
      expect(lockJson(path)['pid'], pid);
      expect(service.recentProjects().single.project, meta);

      await service.close(session);
    });

    test('detects the folder set around a file in database/', () async {
      final folder = createProjectFolder(fixture().dir.path, 'Game');
      final path = p.join(folder.database, 'Game.anvil');
      File(fixturePath).copySync(path);
      final session = await openOk(path);
      expect(session.metadata.projectFolder, folder);
      await service.close(session);
    });

    test('a lock written by 0.1.6 throws ProjectLocked with the 0.1.6 '
        'message', () async {
      final path = fixture().copyFixture();
      final electron =
          '{"pid":4242,"lockedAt":"2026-10-11T08:00:00.000Z",'
          '"filePath":${jsonEncode(path)}}';
      File('$path.lock').writeAsStringSync(electron);

      await expectLater(
        service.open(path),
        throwsA(
          isA<ProjectLocked>().having(
            (e) => e.message,
            'message',
            'This project is already open in another Anvil window.',
          ),
        ),
      );
      expect(File('$path.lock').readAsStringSync(), electron);
    });

    test('a file this service already has open is locked too', () async {
      final path = fixture().copyFixture();
      final session = await openOk(path);
      await expectLater(service.open(path), throwsA(isA<ProjectLocked>()));
      await service.close(session);
    });

    test('a missing file is a recovery result', () async {
      final path = fixture().pathFor('missing.anvil');
      final result = await service.open(path);
      expect(result, isA<ProjectRecovery>());
      result as ProjectRecovery;
      expect(result.fileName, 'missing.anvil');
      expect(result.message, ProjectService.missingFileMessage);
      expect(locked(path), isFalse);
    });

    test('a corrupt file is a recovery result and leaves no lock', () async {
      final path = fixture().copyFixture();
      // Row bytes inside the populated `stats` leaf (page 5).
      const statsLeaf = 4096 * 4;
      final bytes = File(path).readAsBytesSync();
      bytes.fillRange(statsLeaf + 4096 - 64, statsLeaf + 4096, 0xFF);
      File(path).writeAsBytesSync(bytes);

      final result = await service.open(path);
      expect(result, isA<ProjectRecovery>());
      result as ProjectRecovery;
      expect(result.fileName, 'project.anvil');
      expect(result.path, path);
      expect(result.message, startsWith('SQLite integrity check failed: '));
      expect(locked(path), isFalse);
      expect(service.recentProjects(), isEmpty);
      expect(File(path).readAsBytesSync(), bytes);
    });

    test('a file that is not a database is a recovery result', () async {
      final path = fixture().pathFor('text.anvil');
      File(path).writeAsStringSync('not sqlite' * 1000);
      final result = await service.open(path);
      expect(result, isA<ProjectRecovery>());
      expect((result as ProjectRecovery).message, 'file is not a database');
      expect(locked(path), isFalse);
    });
  });

  group('upgrade', () {
    for (final wal in [false, true]) {
      test('upgradeCopy leaves the original byte-identical and unlocked '
          '(${wal ? 'WAL' : 'rollback-journal'} original)', () async {
        final path = downgradedCopy(wal: wal);
        final before = File(path).readAsBytesSync();

        final result = await service.open(path);
        expect(result, isA<ProjectNeedsUpgrade>());
        result as ProjectNeedsUpgrade;
        expect(result.path, path);
        expect(result.schemaVersion, 6);
        expect(locked(path), isTrue);

        final session = await service.upgradeCopy(path);
        final copy = fixture().pathFor(
          'project_backup_20261101102030456.anvil',
        );
        expect(session.filePath, copy);
        expect(session.metadata.schemaVersion, 7);
        expect(session.metadata.recordCounts, _fixtureCounts);
        expect(pendingMigrations(session.database), isEmpty);
        expect(locked(copy), isTrue);
        expect(lockJson(copy)['filePath'], copy);

        expect(locked(path), isFalse);
        expect(File(path).readAsBytesSync(), before);
        expect(File('$path-wal').existsSync(), isFalse);
        expect(File('$path-shm').existsSync(), isFalse);
        expect(service.recentProjects().first.filePath, copy);

        await service.close(session);
      });
    }

    test('cancelUpgrade releases the lock and writes nothing', () async {
      final path = downgradedCopy(wal: false);
      final before = File(path).readAsBytesSync();
      expect(await service.open(path), isA<ProjectNeedsUpgrade>());

      service.cancelUpgrade(path);
      expect(locked(path), isFalse);
      expect(File(path).readAsBytesSync(), before);
      expect(fixture().dir.listSync().whereType<File>(), hasLength(1));
      expect(() => service.upgradeCopy(path), throwsStateError);
    });

    test('a failed upgrade throws ProjectUpgradeFailed and removes the '
        'partial copy', () async {
      // Un-record migration 004 as well: re-running its ALTER TABLE on the
      // copy fails with a duplicate column.
      final path = downgradedCopy(wal: false);
      final db = sqlite3.open(path);
      db.execute(
        "DELETE FROM schema_migrations WHERE filename = '004_ability_resource_type'",
      );
      db.close();
      final before = File(path).readAsBytesSync();
      expect(await service.open(path), isA<ProjectNeedsUpgrade>());

      await expectLater(
        service.upgradeCopy(path),
        throwsA(
          isA<ProjectUpgradeFailed>()
              .having((e) => e.fileName, 'fileName', 'project.anvil')
              .having(
                (e) => e.message,
                'message',
                'Migration failed: 004_ability_resource_type',
              ),
        ),
      );
      expect(locked(path), isFalse);
      expect(File(path).readAsBytesSync(), before);
      expect(fixture().dir.listSync().map((e) => p.basename(e.path)), [
        'project.anvil',
      ]);
    });

    test('upgradeBackupPath uses the 0.1.6 timestamp format', () {
      expect(
        upgradeBackupPath('/x/My Game.anvil', _now),
        p.join('/x', 'My Game_backup_20261101102030456.anvil'),
      );
      expect(
        upgradeBackupPath('/x/noext', _now),
        p.join('/x', 'noext_backup_20261101102030456.anvil'),
      );
    });
  });

  group('close', () {
    test('removes the lock and leaves no -wal content', () async {
      final path = fixture().copyFixture();
      final session = await openOk(path);
      session.database.handle.execute(
        "INSERT INTO save_history (description) VALUES ('in wal')",
      );
      expect(File('$path-wal').lengthSync(), greaterThan(0));

      await service.close(session);
      expect(session.isOpen, isFalse);
      expect(locked(path), isFalse);
      final wal = File('$path-wal');
      expect(!wal.existsSync() || wal.lengthSync() == 0, isTrue);

      final reopened = fixture().track(ProjectDatabase.openReadOnly(path));
      expect(
        reopened.handle
            .select(
              "SELECT COUNT(*) AS n FROM save_history WHERE description = 'in wal'",
            )
            .single['n'],
        1,
      );
    });
  });

  group('saveAs', () {
    test('writes an openable copy, moves the lock and closes the '
        'original', () async {
      final path = fixture().copyFixture();
      final session = await openOk(path);
      session.database.handle.execute(
        "INSERT INTO save_history (description) VALUES ('only in wal')",
      );

      final target = fixture().pathFor('renamed');
      final copy = await service.saveAs(session, target);
      expect(copy.filePath, '$target.anvil');
      expect(copy.isOpen, isTrue);
      expect(copy.metadata.recordCounts, _fixtureCounts);
      expect(session.isOpen, isFalse);
      expect(locked(path), isFalse);
      expect(locked(copy.filePath), isTrue);
      expect(service.recentProjects().first.filePath, copy.filePath);
      await service.close(copy);

      final check = fixture().track(
        ProjectDatabase.openReadOnly(copy.filePath),
      );
      expect(pendingMigrations(check), isEmpty);
      check.integrityCheck();
      expect(
        check.handle
            .select(
              'SELECT COUNT(*) AS n FROM save_history '
              "WHERE description = 'only in wal'",
            )
            .single['n'],
        1,
      );
    });

    test('the same path is a no-op', () async {
      final path = fixture().copyFixture();
      final session = await openOk(path);
      expect(await service.saveAs(session, path.toUpperCase()), same(session));
      expect(session.isOpen, isTrue);
      await service.close(session);
    });

    test('an existing target fails and keeps the original open', () async {
      final path = fixture().copyFixture();
      final session = await openOk(path);
      final target = fixture().pathFor('taken.anvil');
      File(target).writeAsStringSync('keep');

      await expectLater(
        service.saveAs(session, target),
        throwsA(
          isA<ProjectSaveAsFailed>().having(
            (e) => e.message,
            'message',
            'A project file already exists at that path.',
          ),
        ),
      );
      expect(File(target).readAsStringSync(), 'keep');
      expect(session.isOpen, isTrue);
      expect(locked(path), isTrue);
      await service.close(session);
    });

    test('a locked target fails without writing it', () async {
      final path = fixture().copyFixture();
      final session = await openOk(path);
      final target = fixture().pathFor('other.anvil');
      File('$target.lock').writeAsStringSync('{}');

      await expectLater(
        service.saveAs(session, target),
        throwsA(isA<ProjectSaveAsFailed>()),
      );
      expect(File(target).existsSync(), isFalse);
      expect(session.isOpen, isTrue);
      await service.close(session);
    });
  });

  group('backup', () {
    test('writes an openable snapshot and leaves the project open', () async {
      final path = fixture().copyFixture();
      final session = await openOk(path);
      final target = fixture().pathFor('backup.anvil');
      File(target).writeAsStringSync('old backup, replaced');

      await service.backup(session, target);
      expect(session.isOpen, isTrue);
      expect(locked(path), isTrue);
      expect(locked(target), isFalse);
      expect(fixture().dir.listSync().map((e) => p.basename(e.path)), {
        'project.anvil',
        'project.anvil-wal',
        'project.anvil-shm',
        'project.anvil.lock',
        'backup.anvil',
        'support',
      });

      final check = fixture().track(ProjectDatabase.openReadOnly(target));
      expect(pendingMigrations(check), isEmpty);
      check.integrityCheck();
      await service.close(session);
    });

    test('backup and Save As carry a save still in the WAL file', () async {
      final path = fixture().copyFixture();
      final session = await openOk(path);
      final mainBefore = File(path).readAsBytesSync();
      session.database.saveTransaction('WAL save - Test changed', (tx) {
        tx.execute("UPDATE project_info SET game_title = 'WAL title'");
      });
      // The commit is in the -wal file only; the main file is untouched.
      expect(File('$path-wal').lengthSync(), greaterThan(0));
      expect(File(path).readAsBytesSync(), mainBefore);

      void expectSaveIn(String copyPath) {
        final check = fixture().track(ProjectDatabase.openReadOnly(copyPath));
        check.integrityCheck();
        expect(
          check.handle
              .select('SELECT game_title FROM project_info')
              .single['game_title'],
          'WAL title',
        );
        expect(
          check.handle
              .select(
                'SELECT COUNT(*) AS n FROM save_history '
                "WHERE description = 'WAL save - Test changed'",
              )
              .single['n'],
          1,
        );
        check.close();
      }

      final backupPath = fixture().pathFor('wal-backup.anvil');
      await service.backup(session, backupPath);
      expectSaveIn(backupPath);

      final copy = await service.saveAs(session, fixture().pathFor('wal-copy'));
      await service.close(copy);
      expectSaveIn(copy.filePath);
    });

    test('refuses the open file itself', () async {
      final path = fixture().copyFixture();
      final session = await openOk(path);
      await expectLater(
        service.backup(session, path),
        throwsA(isA<ProjectBackupFailed>()),
      );
      expect(session.database.integrityCheck, returnsNormally);
      await service.close(session);
    });

    test('defaultBackupPath matches backupProject', () async {
      final path = fixture().copyFixture();
      final session = await openOk(path);
      expect(
        service.defaultBackupPath(session),
        fixture().pathFor('Spike_Fixture-backup-2026-11-01.anvil'),
      );
      await service.close(session);
    });
  });

  group('recent projects', () {
    test('open adds newest first, de-duplicates and keeps ten', () async {
      final paths = [
        for (var i = 0; i < 11; i++) fixture().copyFixture('p$i.anvil'),
      ];
      for (final path in paths) {
        await service.close(await openOk(path));
      }
      var recent = [for (final r in service.recentProjects()) r.filePath];
      expect(recent, paths.reversed.take(10).toList());

      await service.close(await openOk(paths[5]));
      recent = [for (final r in service.recentProjects()) r.filePath];
      expect(recent.first, paths[5]);
      expect(recent.where((r) => r == paths[5]), hasLength(1));
      expect(recent, hasLength(10));

      File(paths[10]).deleteSync();
      final gone = service.recentProjects().firstWhere(
        (r) => r.filePath == paths[10],
      );
      expect(gone.exists, isFalse);

      service.removeRecent(paths[5].toUpperCase());
      expect(
        service.recentProjects().map((r) => r.filePath),
        isNot(contains(paths[5])),
      );
      service.clearRecents();
      expect(service.recentProjects(), isEmpty);
    });
  });
}
