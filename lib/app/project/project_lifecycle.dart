/// The project lifecycle state machine behind the welcome page, the create
/// dialog and the upgrade and recovery presentations (design §12.1-12.4,
/// §12.7). The core `ProjectService` does the work; this notifier sequences
/// it, logs the 0.1.6 lines and turns the outcomes into UI states.
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dialogs/file_dialogs.dart';
import '../providers.dart';

/// What the lifecycle UI shows besides the welcome page itself.
sealed class ProjectLifecycleState {
  const ProjectLifecycleState();

  /// Nothing in progress and nothing to report.
  const factory ProjectLifecycleState.idle() = LifecycleIdle;

  /// A create, open, upgrade or close is running; [what] names it.
  const factory ProjectLifecycleState.busy(String what) = LifecycleBusy;

  /// [path] has schema [schemaVersion] below the current one. The core holds
  /// its lock until [ProjectLifecycleNotifier.upgradeCopy] or
  /// [ProjectLifecycleNotifier.cancelUpgrade].
  const factory ProjectLifecycleState.needsUpgrade(
    String path,
    int schemaVersion,
  ) = LifecycleNeedsUpgrade;

  /// Recovery mode (design §12.4): [fileName] could not be opened, nothing
  /// is open and nothing is locked.
  const factory ProjectLifecycleState.recovery(
    String fileName,
    String message,
  ) = LifecycleRecovery;

  /// A dismissible error: a lock conflict, a failed create, close or
  /// recent-list write.
  const factory ProjectLifecycleState.failed(String message) = LifecycleFailed;
}

final class LifecycleIdle extends ProjectLifecycleState {
  const LifecycleIdle();

  @override
  bool operator ==(Object other) => other is LifecycleIdle;

  @override
  int get hashCode => (LifecycleIdle).hashCode;

  @override
  String toString() => 'idle';
}

final class LifecycleBusy extends ProjectLifecycleState {
  const LifecycleBusy(this.what);

  final String what;

  @override
  bool operator ==(Object other) =>
      other is LifecycleBusy && other.what == what;

  @override
  int get hashCode => Object.hash(LifecycleBusy, what);

  @override
  String toString() => 'busy($what)';
}

final class LifecycleNeedsUpgrade extends ProjectLifecycleState {
  const LifecycleNeedsUpgrade(this.path, this.schemaVersion);

  final String path;
  final int schemaVersion;

  @override
  bool operator ==(Object other) =>
      other is LifecycleNeedsUpgrade &&
      other.path == path &&
      other.schemaVersion == schemaVersion;

  @override
  int get hashCode => Object.hash(LifecycleNeedsUpgrade, path, schemaVersion);

  @override
  String toString() => 'needsUpgrade($path, $schemaVersion)';
}

final class LifecycleRecovery extends ProjectLifecycleState {
  const LifecycleRecovery(this.fileName, this.message);

  final String fileName;
  final String message;

  @override
  bool operator ==(Object other) =>
      other is LifecycleRecovery &&
      other.fileName == fileName &&
      other.message == message;

  @override
  int get hashCode => Object.hash(LifecycleRecovery, fileName, message);

  @override
  String toString() => 'recovery($fileName, $message)';
}

final class LifecycleFailed extends ProjectLifecycleState {
  const LifecycleFailed(this.message);

  final String message;

  @override
  bool operator ==(Object other) =>
      other is LifecycleFailed && other.message == message;

  @override
  int get hashCode => Object.hash(LifecycleFailed, message);

  @override
  String toString() => 'failed($message)';
}

/// The lifecycle state; see [ProjectLifecycleNotifier].
final projectLifecycleProvider =
    NotifierProvider<ProjectLifecycleNotifier, ProjectLifecycleState>(
      ProjectLifecycleNotifier.new,
    );

/// The recent list, read from `ProjectService.recentProjects()` (which
/// refreshes every entry from disk) each time a widget starts watching it:
/// auto-dispose drops it when the welcome page goes, so showing the page
/// again reads the file again. Remove and clear invalidate it.
final recentProjectsProvider = Provider.autoDispose<List<RecentProject>>(
  (ref) => ref.watch(projectServiceProvider).recentProjects(),
);

/// Creates, opens, upgrades and closes projects through `ProjectService`
/// and holds what the UI should show about it. A successful create, open
/// or upgrade makes the session current through
/// `projectSessionProvider.notifier.set`.
///
/// `build()` watches nothing; the service, logger, dialogs and session are
/// read at call time. While [LifecycleBusy], new intents are ignored.
class ProjectLifecycleNotifier extends Notifier<ProjectLifecycleState> {
  @override
  ProjectLifecycleState build() => const ProjectLifecycleState.idle();

  ProjectService get _service => ref.read(projectServiceProvider);

  AppLogger get _log => ref.read(appLoggerProvider);

  bool get _busy => state is LifecycleBusy;

  /// Asks for a `.anvil` file and opens it; a cancelled dialog does nothing.
  Future<void> openWithDialog() async {
    if (_busy) return;
    final path = await ref.read(fileDialogsProvider).pickAnvilFile();
    if (path == null) return;
    await openPath(path);
  }

  /// Opens [path], closing the current project first as 0.1.6 did. Ends in
  /// idle with the session set, [LifecycleNeedsUpgrade], [LifecycleRecovery]
  /// or, for a lock conflict, [LifecycleFailed] with 0.1.6's lock message.
  Future<void> openPath(String path) async {
    if (_busy) return;
    state = const ProjectLifecycleState.busy('Opening project');
    await _closeCurrent();
    try {
      switch (await _service.open(path)) {
        case ProjectOpened(:final session):
          _activate(session, 'Project opened');
        case ProjectNeedsUpgrade(:final path, :final schemaVersion):
          _log.debug('Project needs a schema upgrade (version $schemaVersion)');
          state = ProjectLifecycleState.needsUpgrade(path, schemaVersion);
        case ProjectRecovery(:final fileName, :final message):
          _enterRecovery(fileName, message);
      }
    } on ProjectLocked catch (e) {
      _log.error('Project lock conflict', e);
      state = ProjectLifecycleState.failed(e.message);
    } catch (e, stack) {
      _log.error('Project open failed', e, stack);
      state = ProjectLifecycleState.failed(describeProjectError(e));
    }
  }

  /// Creates a project in [parentDirectory] and makes it current, closing
  /// the current project first as 0.1.6 did. Returns whether it succeeded;
  /// on failure the state is [LifecycleFailed] with the core's message (the
  /// core has already removed anything it created).
  Future<bool> create(
    String projectName,
    String gameTitle,
    String parentDirectory,
  ) async {
    if (_busy) return false;
    state = const ProjectLifecycleState.busy('Creating project');
    await _closeCurrent();
    try {
      final session = await _service.create(
        projectName: projectName,
        gameTitle: gameTitle,
        parentFolder: parentDirectory,
      );
      _activate(session, 'Project created');
      return true;
    } on ProjectCreateFailed catch (e) {
      _log.error('Project creation failed', e);
      state = ProjectLifecycleState.failed(e.message);
      return false;
    } catch (e, stack) {
      _log.error('Project creation failed', e, stack);
      state = ProjectLifecycleState.failed(describeProjectError(e));
      return false;
    }
  }

  /// After [LifecycleNeedsUpgrade]: upgrades a backup copy and opens it. A
  /// failed upgrade enters recovery mode, as 0.1.6 did.
  Future<void> upgradeCopy() async {
    final pending = state;
    if (pending is! LifecycleNeedsUpgrade) return;
    state = const ProjectLifecycleState.busy('Upgrading a copy');
    try {
      final session = await _service.upgradeCopy(pending.path);
      _activate(session, 'Project opened');
    } on ProjectUpgradeFailed catch (e) {
      _enterRecovery(e.fileName, e.message);
    } on ProjectLocked catch (e) {
      _log.error('Project lock conflict', e);
      state = ProjectLifecycleState.failed(e.message);
    } catch (e, stack) {
      _log.error('Project upgrade failed', e, stack);
      state = ProjectLifecycleState.failed(describeProjectError(e));
    }
  }

  /// After [LifecycleNeedsUpgrade]: releases the original's lock.
  void cancelUpgrade() {
    final pending = state;
    if (pending is! LifecycleNeedsUpgrade) return;
    _service.cancelUpgrade(pending.path);
    state = const ProjectLifecycleState.idle();
  }

  /// Closes the open project (`ProjectService.close`, then clears the
  /// session). The handle and lock are released even when the final
  /// checkpoint fails, which is then reported as [LifecycleFailed].
  Future<void> closeProject() async {
    if (_busy || ref.read(projectSessionProvider) == null) return;
    state = const ProjectLifecycleState.busy('Closing project');
    final failure = await _closeCurrent();
    state = failure == null
        ? const ProjectLifecycleState.idle()
        : ProjectLifecycleState.failed(failure);
  }

  /// Save As (0.1.6 `saveProjectAs`): snapshots the open project to [path]
  /// (`.anvil` appended if missing), moves the lock there and makes the copy
  /// the open project; the original is closed. The same path does nothing.
  ///
  /// Returns null on success, or the message to show on failure, when the
  /// original stays open. Either way the state ends idle: the shell, not the
  /// welcome page, reports the failure.
  Future<String?> saveAs(String path) async {
    final session = ref.read(projectSessionProvider);
    if (_busy || session == null) return null;
    state = const ProjectLifecycleState.busy('Saving a copy');
    try {
      final copy = await _service.saveAs(session, path);
      if (!identical(copy, session)) {
        _activate(copy, 'Project saved to new location');
      }
      state = const ProjectLifecycleState.idle();
      return null;
    } catch (e, stack) {
      _log.error('Save-as failed', e, stack);
      state = const ProjectLifecycleState.idle();
      return e is ProjectLifecycleFailure ? e.message : describeProjectError(e);
    }
  }

  /// Writes a backup snapshot of the open project to [path]
  /// (0.1.6 `backupProject`); the open project does not change. Returns
  /// null on success or the failure message, and ends idle as [saveAs].
  Future<String?> backup(String path) async {
    final session = ref.read(projectSessionProvider);
    if (_busy || session == null) return null;
    state = const ProjectLifecycleState.busy('Backing up project');
    try {
      await _service.backup(session, path);
      _log.info('Project backup created');
      _log.debug('Project backup created: ${anonymizePath(path)}');
      state = const ProjectLifecycleState.idle();
      return null;
    } catch (e, stack) {
      _log.error('Project backup failed', e, stack);
      state = const ProjectLifecycleState.idle();
      return e is ProjectLifecycleFailure ? e.message : describeProjectError(e);
    }
  }

  /// Removes one entry from the recent list.
  void removeRecent(String path) =>
      _changeRecents(() => _service.removeRecent(path));

  /// Empties the recent list.
  void clearRecents() => _changeRecents(_service.clearRecents);

  /// Leaves a failure or recovery mode for the plain welcome page. A pending
  /// upgrade is cancelled so its lock is never left behind.
  void dismiss() {
    switch (state) {
      case LifecycleNeedsUpgrade():
        cancelUpgrade();
      case LifecycleFailed() || LifecycleRecovery():
        state = const ProjectLifecycleState.idle();
      case LifecycleIdle() || LifecycleBusy():
        break;
    }
  }

  void _activate(ProjectSession session, String verb) {
    ref.read(projectSessionProvider.notifier).set(session);
    final metadata = session.metadata;
    _log.info(verb);
    _log.debug(
      '$verb: ${metadata.projectName} (${anonymizePath(metadata.filePath)})',
    );
    state = const ProjectLifecycleState.idle();
  }

  void _enterRecovery(String fileName, String message) {
    _log.error('Project open failed, entering recovery mode', message);
    state = ProjectLifecycleState.recovery(fileName, message);
  }

  /// Closes and clears the current session, if any. Returns the failure
  /// message when the final checkpoint failed (the session is cleared
  /// regardless), else null.
  Future<String?> _closeCurrent() async {
    final session = ref.read(projectSessionProvider);
    if (session == null) return null;
    final name = session.metadata.projectName;
    String? failure;
    try {
      await _service.close(session);
    } on ProjectCloseFailed catch (e) {
      _log.error('Project close failed', e);
      failure = e.message;
    }
    ref.read(projectSessionProvider.notifier).clear();
    _log.info('Project closed');
    _log.debug('Project closed: $name');
    return failure;
  }

  void _changeRecents(void Function() change) {
    if (_busy) return;
    try {
      change();
    } catch (e) {
      _log.error('Recent projects update failed', e);
      state = ProjectLifecycleState.failed(describeProjectError(e));
    }
    ref.invalidate(recentProjectsProvider);
  }
}
