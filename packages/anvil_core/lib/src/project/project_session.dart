import 'package:meta/meta.dart';

import '../db/project_database.dart';
import 'project_lock.dart';
import 'project_metadata.dart';

/// One open project: its metadata and its read-write [ProjectDatabase].
///
/// Made only by `ProjectService` (`create`, `open`, `upgradeCopy`,
/// `saveAs`) and closed only through `ProjectService.close`, which also
/// releases the lock. The repository fields arrive with ANVL-176 and later
/// tickets.
final class ProjectSession {
  @internal
  ProjectSession(this.metadata, this.database, this.lock);

  /// The metadata as read when the session was opened.
  final ProjectMetadata metadata;

  /// The project's read-write connection on the UI isolate.
  final ProjectDatabase database;

  /// The lock held for [filePath] while the session is open.
  @internal
  final ProjectLock lock;

  String get filePath => metadata.filePath;

  bool get isOpen => database.isOpen;
}
