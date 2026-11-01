/// The project's `.anvil.lock` sidecar already exists: another Anvil window
/// (0.1.6 or 0.2.0) has it open, or a crash left the lock behind. There is
/// no stale-lock detection, as in 0.1.6; the user deletes the file by hand.
final class ProjectLocked implements Exception {
  const ProjectLocked(this.filePath);

  /// 0.1.6's message, word for word.
  static const lockedMessage =
      'This project is already open in another Anvil window.';

  /// The project file whose lock is taken.
  final String filePath;

  String get message => lockedMessage;

  @override
  String toString() => 'ProjectLocked: $message ($filePath)';
}

/// Base of the lifecycle failures that carry a user-facing [message] and
/// the underlying [cause] (often a `SqliteException`, which never escapes
/// the core on its own).
sealed class ProjectLifecycleFailure implements Exception {
  const ProjectLifecycleFailure(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() =>
      '$runtimeType: $message${cause == null ? '' : ' ($cause)'}';
}

/// Creating a project failed. Anything the attempt created (folder tree,
/// file, lock) has been removed.
final class ProjectCreateFailed extends ProjectLifecycleFailure {
  const ProjectCreateFailed(super.message, [super.cause]);
}

/// Upgrading a copy of an old project failed. The original is untouched and
/// unlocked, and the partial copy has been removed. The UI shows this as
/// recovery mode, as 0.1.6 did.
final class ProjectUpgradeFailed extends ProjectLifecycleFailure {
  const ProjectUpgradeFailed(this.fileName, String message, [Object? cause])
    : super(message, cause);

  /// The original file's name, for the recovery screen.
  final String fileName;
}

/// Save As failed. The original session is still open and unchanged.
final class ProjectSaveAsFailed extends ProjectLifecycleFailure {
  const ProjectSaveAsFailed(super.message, [super.cause]);
}

/// Writing a backup failed. The open project is unchanged.
final class ProjectBackupFailed extends ProjectLifecycleFailure {
  const ProjectBackupFailed(super.message, [super.cause]);
}

/// The final checkpoint on close failed. The handle is closed and the lock
/// released regardless; committed data is in the file or its `-wal`.
final class ProjectCloseFailed extends ProjectLifecycleFailure {
  const ProjectCloseFailed(super.message, [super.cause]);
}
