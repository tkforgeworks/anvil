import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../db/errors.dart';
import '../db/migrations/migration_runner.dart';
import '../db/migrations/migrations.dart';
import '../db/project_database.dart';
import 'project_errors.dart';
import 'project_folder.dart';
import 'project_folder_name.dart';
import 'project_lock.dart';
import 'project_metadata.dart';
import 'project_session.dart';
import 'recent_projects.dart';

/// What [ProjectService.create] returns: the new project's open session.
typedef CreateResult = ProjectSession;

/// What [ProjectService.open] found.
sealed class OpenResult {
  const OpenResult();
}

/// The project is open.
final class ProjectOpened extends OpenResult {
  const ProjectOpened(this.session);

  final ProjectSession session;
}

/// The file's schema is older than [currentSchemaVersion]. Its lock is held
/// until the caller picks [ProjectService.upgradeCopy] or
/// [ProjectService.cancelUpgrade]; the file itself is unchanged.
final class ProjectNeedsUpgrade extends OpenResult {
  const ProjectNeedsUpgrade(this.path, this.schemaVersion);

  final String path;
  final int schemaVersion;
}

/// The file could not be opened (integrity failure, missing file, or any
/// other error that is not a lock conflict). Nothing is open and no lock is
/// held; the UI shows recovery mode with [fileName] and [message].
final class ProjectRecovery extends OpenResult {
  const ProjectRecovery(this.path, this.fileName, this.message);

  final String path;
  final String fileName;
  final String message;
}

const _upsertProjectInfo = '''INSERT INTO project_info (id, project_name, game_title, schema_version, updated_at)
       VALUES (1, ?, ?, ?, datetime('now'))
       ON CONFLICT(id) DO UPDATE SET
         project_name = excluded.project_name,
         game_title = excluded.game_title,
         schema_version = excluded.schema_version,
         updated_at = excluded.updated_at''';

/// Project create, open, upgrade, close, Save As, backup and the recent
/// list: the port of Electron's `project-service.ts` without dialogs, the
/// auto-save timer, dirty tracking or auto-save info. Every path and choice
/// comes in as an argument; the UI owns the dialogs.
///
/// The service holds no "active project": the caller closes the current
/// session before opening another (0.1.6 did that inside `openProject`).
/// Opening a file this service already has open is a [ProjectLocked], as it
/// is from another window.
///
/// `SqliteException` never escapes a public method; failures arrive as the
/// types in `project_errors.dart` or as [ProjectRecovery].
final class ProjectService {
  ProjectService({required this.supportDirectory, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      _recents = RecentProjectsStore(
        p.join(supportDirectory, RecentProjectsStore.fileName),
      );

  /// 0.1.6's text for a missing file (it threw it instead of entering
  /// recovery mode).
  static const missingFileMessage = 'The selected project file does not exist.';

  /// The application support directory; `recent-projects.json` lives
  /// directly in it.
  final String supportDirectory;

  final DateTime Function() _clock;
  final RecentProjectsStore _recents;

  /// Locks held for [ProjectNeedsUpgrade] results, by lower-cased path.
  final Map<String, ProjectLock> _pendingUpgrades = {};

  // ---------------------------------------------------------------- create

  /// Creates `{parentFolder}/{sanitized name}/` with its four folders and
  /// `database/{sanitized name}.anvil`, migrates it, checks it, writes
  /// `project_info` and adds it to the recent list (`createProject`).
  ///
  /// Throws [ProjectCreateFailed]. When the failure comes after the folder
  /// was made, the whole tree is removed; an existing folder is never
  /// touched.
  Future<CreateResult> create({
    required String projectName,
    required String gameTitle,
    required String parentFolder,
  }) async {
    final name = projectName.trim();
    final title = gameTitle.trim();
    if (name.isEmpty) {
      throw const ProjectCreateFailed('Project name is required.');
    }
    if (title.isEmpty) {
      throw const ProjectCreateFailed('Game title is required.');
    }

    final ProjectFolderPaths folder;
    try {
      folder = createProjectFolder(parentFolder, name);
    } on ProjectCreateFailed {
      rethrow;
    } catch (e) {
      throw ProjectCreateFailed(describeProjectError(e), e);
    }

    final filePath = p.join(
      folder.database,
      '${sanitizeFolderName(name)}.anvil',
    );
    ProjectLock? lock;
    ProjectDatabase? db;
    try {
      lock = ProjectLock.acquire(filePath, now: _clock());
      db = ProjectDatabase.open(filePath);
      runMigrations(db);
      db.integrityCheck();
      db.handle.execute(_upsertProjectInfo, [
        name,
        title,
        currentSchemaVersion,
      ]);
      final session = ProjectSession(_buildMetadata(db, filePath), db, lock);
      _addRecent(session.metadata);
      // TODO(ANVL-173): log 'Project created' (info) and name + anonymized
      // path (debug).
      return session;
    } catch (e) {
      // TODO(ANVL-173): log 'Project creation failed' with the error.
      _closeQuietly(db);
      lock?.release();
      _deleteTree(folder.root);
      throw ProjectCreateFailed(describeProjectError(e), e);
    }
  }

  // ------------------------------------------------------------------ open

  /// Opens [path] (`openProject`): takes the lock, checks integrity and
  /// reads the schema version on a background isolate with a read-only
  /// connection, then opens it read-write here.
  ///
  /// Throws [ProjectLocked] on a lock conflict; every other failure is a
  /// [ProjectRecovery] with nothing left open or locked.
  Future<OpenResult> open(String path) async {
    final selected = path.trim();
    if (!File(selected).existsSync()) {
      return ProjectRecovery(
        selected,
        p.basename(selected),
        missingFileMessage,
      );
    }

    final ProjectLock lock;
    try {
      lock = ProjectLock.acquire(selected, now: _clock());
    } on ProjectLocked {
      // TODO(ANVL-173): log 'Project lock conflict'.
      rethrow;
    } catch (e) {
      return _recovery(selected, e);
    }

    final _Check check;
    try {
      check = await _runPreOpenCheck(selected);
    } catch (e) {
      lock.release();
      return _recovery(selected, e);
    }
    final error = check.error;
    if (error != null) {
      lock.release();
      // TODO(ANVL-173): log 'Project open failed, entering recovery mode'.
      return ProjectRecovery(selected, p.basename(selected), error);
    }

    if (check.version < currentSchemaVersion) {
      _pendingUpgrades[selected.toLowerCase()] = lock;
      return ProjectNeedsUpgrade(selected, check.version);
    }

    try {
      return ProjectOpened(_openSession(selected, lock));
    } catch (e) {
      lock.release();
      return _recovery(selected, e);
    }
  }

  /// After [ProjectNeedsUpgrade]: snapshots the original to
  /// `{name}_backup_{timestamp}.anvil` beside it, migrates, checks and
  /// checkpoints the copy on a background isolate, moves the lock to the
  /// copy (taking the new lock before releasing the old) and opens the copy
  /// (`migrateIfNeeded`). The original's bytes are unchanged.
  ///
  /// Throws [ProjectUpgradeFailed] (the UI shows recovery mode; nothing is
  /// locked and a partial copy is removed), [ProjectLocked] if the copy's
  /// lock is taken, or [StateError] if no upgrade is pending for [path].
  Future<ProjectSession> upgradeCopy(String path) async {
    final lock = _pendingUpgrades.remove(path.trim().toLowerCase());
    if (lock == null) {
      throw StateError('No upgrade is pending for $path');
    }
    final original = lock.filePath;
    final fileName = p.basename(original);
    final copyPath = upgradeBackupPath(original, _clock());

    String? error;
    try {
      error = await _runUpgrade(original, copyPath);
    } catch (e) {
      error = describeProjectError(e);
    }
    if (error != null) {
      lock.release();
      _deleteDatabaseFiles(copyPath);
      throw ProjectUpgradeFailed(fileName, error);
    }

    final ProjectLock copyLock;
    try {
      copyLock = ProjectLock.acquire(copyPath, now: _clock());
    } on ProjectLocked {
      lock.release();
      rethrow;
    } catch (e) {
      lock.release();
      _deleteDatabaseFiles(copyPath);
      throw ProjectUpgradeFailed(fileName, describeProjectError(e), e);
    }
    lock.release();

    try {
      return _openSession(copyPath, copyLock);
    } catch (e) {
      copyLock.release();
      throw ProjectUpgradeFailed(fileName, describeProjectError(e), e);
    }
  }

  /// After [ProjectNeedsUpgrade]: the user cancelled, so release the lock.
  /// Does nothing if no upgrade is pending for [path].
  void cancelUpgrade(String path) {
    _pendingUpgrades.remove(path.trim().toLowerCase())?.release();
  }

  // ----------------------------------------------------------------- close

  /// `TRUNCATE` checkpoint, close the handle, release the lock
  /// (`closeActiveProject`). The dirty-editor guard is the UI's.
  ///
  /// The handle is closed and the lock released even when the checkpoint
  /// fails, which then throws [ProjectCloseFailed].
  Future<void> close(ProjectSession session) async {
    Object? failure;
    if (session.isOpen) {
      try {
        session.database.checkpoint(CheckpointMode.truncate);
      } catch (e) {
        failure = e;
      }
      try {
        session.database.close();
      } catch (e) {
        failure ??= e;
      }
    }
    session.lock.release();
    // TODO(ANVL-173): log 'Project closed' (info) and the name (debug).
    if (failure != null) {
      throw ProjectCloseFailed(describeProjectError(failure), failure);
    }
  }

  // ------------------------------------------------------- Save As, backup

  /// Writes a snapshot of [session] to [targetPath] (`.anvil` appended if
  /// missing), moves the lock there and returns the copy's session; the
  /// original session is closed (`saveProjectAs`). The same path
  /// (case-insensitive) returns [session] unchanged.
  ///
  /// Throws [ProjectSaveAsFailed]; the original session is then still open,
  /// and a copy this call wrote is removed.
  Future<ProjectSession> saveAs(
    ProjectSession session,
    String targetPath,
  ) async {
    final target = normalizeAnvilPath(targetPath);
    if (target.toLowerCase() == session.filePath.toLowerCase()) {
      return session;
    }
    if (!session.isOpen) {
      throw const ProjectSaveAsFailed('The project is not open.');
    }
    if (FileSystemEntity.typeSync(target, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw const ProjectSaveAsFailed(
        'A project file already exists at that path.',
      );
    }

    ProjectLock? newLock;
    ProjectDatabase? db;
    var wrote = false;
    final ProjectSession copy;
    try {
      newLock = ProjectLock.acquire(target, now: _clock());
      session.database.snapshot(target);
      wrote = true;
      final check = await _runPreOpenCheck(target);
      if (check.error != null) {
        throw ProjectSaveAsFailed(check.error!);
      }
      db = ProjectDatabase.open(target);
      copy = ProjectSession(_buildMetadata(db, target), db, newLock);
    } catch (e) {
      // TODO(ANVL-173): log 'Save-as failed' with the error.
      _closeQuietly(db);
      newLock?.release();
      if (wrote) _deleteDatabaseFiles(target);
      if (e is ProjectSaveAsFailed) rethrow;
      throw ProjectSaveAsFailed(describeProjectError(e), e);
    }

    try {
      await close(session);
    } on ProjectCloseFailed {
      // TODO(ANVL-173): log the failed checkpoint of the original; the copy
      // is already a complete snapshot.
    }
    _addRecent(copy.metadata);
    // TODO(ANVL-173): log 'Project saved to new location'.
    return copy;
  }

  /// Writes a snapshot of [session] to [targetPath]; the open project does
  /// not change (`backupProject`). An existing file at [targetPath] is
  /// replaced (the save dialog has already confirmed that), via a temporary
  /// snapshot renamed over it.
  ///
  /// Throws [ProjectBackupFailed], including when [targetPath] is the open
  /// project's own file or is locked by an Anvil window.
  Future<void> backup(ProjectSession session, String targetPath) async {
    final target = targetPath.trim();
    if (target.toLowerCase() == session.filePath.toLowerCase()) {
      throw const ProjectBackupFailed(
        'A backup cannot replace the open project file.',
      );
    }
    if (File(ProjectLock.pathFor(target)).existsSync()) {
      throw ProjectBackupFailed(
        ProjectLocked.lockedMessage,
        ProjectLocked(target),
      );
    }
    final temp = '$target.${_clock().microsecondsSinceEpoch}.tmp';
    try {
      session.database.snapshot(temp);
      File(temp).renameSync(target);
    } catch (e) {
      _deleteDatabaseFiles(temp);
      throw ProjectBackupFailed(describeProjectError(e), e);
    }
    // TODO(ANVL-173): log 'Project backup created'.
  }

  /// The backup dialog's default: `{file's folder}/{name}-backup-{date}.anvil`
  /// with the project name's characters outside `[a-zA-Z0-9_-]` replaced by
  /// `_` and the UTC date as `YYYY-MM-DD`, as `backupProject` built it. The
  /// folder is the one holding the `.anvil` file (`database/` in a project
  /// folder), not the project root.
  String defaultBackupPath(ProjectSession session) {
    final name = session.metadata.projectName.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );
    final date = jsIsoString(_clock()).split('T').first;
    return p.join(p.dirname(session.filePath), '$name-backup-$date.anvil');
  }

  // ---------------------------------------------------------------- recent

  /// The recent list, newest first, refreshed from disk.
  List<RecentProject> recentProjects() => _recents.read();

  /// Removes [path] from the recent list (case-insensitive). Throws
  /// [FileSystemException] if the list cannot be written.
  void removeRecent(String path) => _recents.remove(path);

  /// Empties the recent list. Throws [FileSystemException] if the list
  /// cannot be written.
  void clearRecents() => _recents.clear();

  // --------------------------------------------------------------- helpers

  ProjectSession _openSession(String path, ProjectLock lock) {
    final db = ProjectDatabase.open(path);
    try {
      final session = ProjectSession(_buildMetadata(db, path), db, lock);
      _addRecent(session.metadata);
      // TODO(ANVL-173): log 'Project opened' (info) and name + anonymized
      // path (debug).
      return session;
    } catch (_) {
      _closeQuietly(db);
      rethrow;
    }
  }

  /// A recent-list write failure never fails the lifecycle step (0.1.6 let
  /// it fail the create or open).
  void _addRecent(ProjectMetadata metadata) {
    try {
      _recents.add(metadata);
    } catch (_) {
      // TODO(ANVL-173): log the failed recent-projects write.
    }
  }

  ProjectRecovery _recovery(String path, Object error) {
    // TODO(ANVL-173): log 'Project open failed, entering recovery mode'.
    return ProjectRecovery(path, p.basename(path), describeProjectError(error));
  }
}

/// `.anvil` appended unless the trimmed path already ends in it
/// (case-insensitive), as `normalizeAnvilPath`.
String normalizeAnvilPath(String path) {
  final trimmed = path.trim();
  return p.extension(trimmed).toLowerCase() == '.anvil'
      ? trimmed
      : '$trimmed.anvil';
}

/// `createBackupPath`: `{dir}/{name}_backup_{timestamp}{ext or .anvil}`,
/// the timestamp being [now] as `toISOString()` with `-`, `:`, `.`, `T` and
/// `Z` removed (`YYYYMMDDHHmmssSSS`, UTC).
String upgradeBackupPath(String filePath, DateTime now) {
  final timestamp = jsIsoString(now).replaceAll(RegExp('[-:.TZ]'), '');
  final ext = p.extension(filePath);
  return p.join(
    p.dirname(filePath),
    '${p.basenameWithoutExtension(filePath)}_backup_$timestamp'
    '${ext.isEmpty ? '.anvil' : ext}',
  );
}

/// The user-facing message for a lifecycle error, matching 0.1.6's text
/// where it had one.
String describeProjectError(Object error) => switch (error) {
  IntegrityCheckFailed(:final message) =>
    'SQLite integrity check failed: ${message.split('\n').first}',
  MigrationFailed(:final filename) => 'Migration failed: $filename',
  ProjectLocked(:final message) => message,
  ProjectLifecycleFailure(:final message) => message,
  SqliteException(:final message) => message,
  FileSystemException(:final message, :final path, :final osError) => [
    message,
    ?path,
    if (osError != null) osError.message,
  ].join(': '),
  _ => '$error',
};

// ------------------------------------------------------- record counts, meta

/// `buildProjectMetadata`: `project_info` (inserting the default row if it
/// is missing, as 0.1.6 did), names falling back to the file name, the
/// folder set, file stats and active record counts.
ProjectMetadata _buildMetadata(ProjectDatabase db, String filePath) {
  final handle = db.handle;
  final rows = handle.select(
    'SELECT project_name, game_title, schema_version FROM project_info WHERE id = 1',
  );
  String name = '';
  String title = '';
  int version = currentSchemaVersion;
  if (rows.isEmpty) {
    handle.execute(
      '''INSERT INTO project_info (id, project_name, game_title, schema_version)
     VALUES (1, '', '', ?)''',
      [currentSchemaVersion],
    );
  } else {
    final row = rows.single;
    name = (row['project_name'] as String?) ?? '';
    title = (row['game_title'] as String?) ?? '';
    version = (row['schema_version'] as num?)?.toInt() ?? 0;
  }

  final fallback = p.basenameWithoutExtension(filePath);
  final stat = File(filePath).statSync();
  return ProjectMetadata(
    projectName: name.isEmpty ? fallback : name,
    gameTitle: title.isEmpty ? fallback : title,
    filePath: filePath,
    projectFolder: detectProjectFolder(filePath),
    schemaVersion: version,
    lastModifiedAt: jsIsoString(stat.modified),
    fileSize: stat.size,
    recordCounts: RecordCounts(
      classes: _countActiveRows(handle, 'classes'),
      abilities: _countActiveRows(handle, 'abilities'),
      items: _countActiveRows(handle, 'items'),
      recipes: _countActiveRows(handle, 'recipes'),
      npcs: _countActiveRows(handle, 'npcs'),
      lootTables: _countActiveRows(handle, 'loot_tables'),
    ),
  );
}

bool _tableExists(Database handle, String table) => handle.select(
  "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
  [table],
).isNotEmpty;

int _countActiveRows(Database handle, String table) {
  if (!_tableExists(handle, table)) return 0;
  return handle
          .select(
            'SELECT COUNT(*) AS count FROM $table WHERE deleted_at IS NULL',
          )
          .single['count']
      as int;
}

/// `readProjectSchemaVersion`: `project_info`, else the legacy
/// `project_meta`, else 0.
int _readSchemaVersion(Database handle) {
  for (final table in const ['project_info', 'project_meta']) {
    if (!_tableExists(handle, table)) continue;
    final rows = handle.select(
      'SELECT schema_version FROM $table WHERE id = 1',
    );
    return rows.isEmpty
        ? 0
        : (rows.single['schema_version'] as num?)?.toInt() ?? 0;
  }
  return 0;
}

// ----------------------------------------------------------------- isolates

typedef _Check = ({int version, String? error});

/// Top-level so the isolate closure captures only [path].
Future<_Check> _runPreOpenCheck(String path) =>
    Isolate.run(() => _preOpenCheck(path));

Future<String?> _runUpgrade(String original, String copy) =>
    Isolate.run(() => _upgradeInIsolate(original, copy));

/// Integrity check and schema version on a read-only connection opened and
/// closed here, so the file is never written.
_Check _preOpenCheck(String path) {
  final sidecars = _Sidecars.before(path);
  ProjectDatabase? db;
  try {
    db = ProjectDatabase.openReadOnly(path);
    // 0.1.6 ran `journal_mode = WAL` first, so a file that is not a database
    // failed with SQLite's own message rather than as an integrity failure.
    db.handle.select('PRAGMA journal_mode');
    db.integrityCheck();
    return (version: _readSchemaVersion(db.handle), error: null);
  } catch (e) {
    return (version: 0, error: describeProjectError(e));
  } finally {
    _closeQuietly(db);
    sidecars.removeCreated();
  }
}

/// Snapshot of [original] (read-only) to [copy], then migrate, check and
/// checkpoint the copy. Returns null on success, else the message.
String? _upgradeInIsolate(String original, String copy) {
  final sidecars = _Sidecars.before(original);
  ProjectDatabase? source;
  ProjectDatabase? target;
  try {
    source = ProjectDatabase.openReadOnly(original);
    source.snapshot(copy);
    source.close();
    target = ProjectDatabase.open(copy);
    runMigrations(target);
    target.integrityCheck();
    target.checkpoint(CheckpointMode.truncate);
    target.close();
    return null;
  } catch (e) {
    return describeProjectError(e);
  } finally {
    _closeQuietly(source);
    _closeQuietly(target);
    sidecars.removeCreated();
  }
}

/// A read-only connection to a WAL file creates `-wal` and `-shm` beside it
/// and cannot delete them on close. This removes them again when they did
/// not exist before and the `-wal` holds nothing, so a check leaves the
/// original exactly as it found it.
final class _Sidecars {
  _Sidecars.before(this.path)
    : _hadWal = File('$path-wal').existsSync(),
      _hadShm = File('$path-shm').existsSync();

  final String path;
  final bool _hadWal;
  final bool _hadShm;

  void removeCreated() {
    if (_hadWal) return;
    final wal = File('$path-wal');
    try {
      if (wal.existsSync()) {
        if (wal.lengthSync() != 0) return;
        wal.deleteSync();
      }
      if (!_hadShm) {
        final shm = File('$path-shm');
        if (shm.existsSync()) shm.deleteSync();
      }
    } on FileSystemException {
      // Best effort; leftover empty sidecars are harmless.
    }
  }
}

void _closeQuietly(ProjectDatabase? db) {
  if (db == null) return;
  try {
    db.close();
  } catch (_) {
    // Already failing; the original error is what the caller needs.
  }
}

void _deleteDatabaseFiles(String path) {
  for (final suffix in const ['', '-wal', '-shm', '-journal']) {
    try {
      final file = File('$path$suffix');
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException {
      // Best effort.
    }
  }
}

void _deleteTree(String root) {
  try {
    final dir = Directory(root);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  } on FileSystemException {
    // Best effort, as 0.1.6's rmSync(force).
  }
}
