import 'dart:convert';
import 'dart:io';

import 'project_errors.dart';
import 'project_metadata.dart';

/// The `<file>.anvil.lock` sidecar that keeps a project open in one window.
///
/// Same format as 0.1.6 (`acquireProjectLock` in `project-service.ts`), so a
/// 0.1.6 instance and a 0.2.0 instance refuse each other's open project: the
/// file is created with exclusive-create semantics (Node's `wx`) and holds
/// compact `JSON.stringify` output, `{"pid":…,"lockedAt":"…","filePath":"…"}`.
/// No stale-lock detection.
final class ProjectLock {
  ProjectLock._(this.filePath, this.lockPath);

  /// The project file this lock protects.
  final String filePath;

  /// `filePath` + `.lock`.
  final String lockPath;

  bool _held = true;

  /// Whether this lock is still held by its owner.
  bool get isHeld => _held;

  /// The sidecar path for [filePath].
  static String pathFor(String filePath) => '$filePath.lock';

  /// The JSON 0.1.6 writes into the lock file.
  static String contentsFor(String filePath, {required DateTime lockedAt}) =>
      jsonEncode({
        'pid': pid,
        'lockedAt': jsIsoString(lockedAt),
        'filePath': filePath,
      });

  /// Creates the lock file for [filePath].
  ///
  /// Throws [ProjectLocked] if it already exists, and any other
  /// [FileSystemException] as is (the caller decides what it means).
  static ProjectLock acquire(String filePath, {DateTime? now}) {
    final lockPath = pathFor(filePath);
    final file = File(lockPath);
    try {
      file.createSync(exclusive: true);
    } on FileSystemException catch (e) {
      if (_isAlreadyExists(e)) throw ProjectLocked(filePath);
      rethrow;
    }
    try {
      file.writeAsStringSync(
        contentsFor(filePath, lockedAt: now ?? DateTime.now()),
        flush: true,
      );
    } on FileSystemException {
      _deleteQuietly(file);
      rethrow;
    }
    return ProjectLock._(filePath, lockPath);
  }

  /// Whether [other] names the same project file, compared
  /// case-insensitively as 0.1.6 did.
  bool isFor(String other) => filePath.toLowerCase() == other.toLowerCase();

  /// Deletes the lock file. Best effort and idempotent, as 0.1.6's
  /// `releaseProjectLock`.
  void release() {
    if (!_held) return;
    _held = false;
    _deleteQuietly(File(lockPath));
  }

  static bool _isAlreadyExists(FileSystemException e) {
    if (e is PathExistsException) return true;
    // EEXIST on POSIX; ERROR_FILE_EXISTS / ERROR_ALREADY_EXISTS on Windows.
    final code = e.osError?.errorCode;
    return Platform.isWindows ? (code == 80 || code == 183) : code == 17;
  }

  static void _deleteQuietly(File file) {
    try {
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException {
      // Best effort release.
    }
  }
}
