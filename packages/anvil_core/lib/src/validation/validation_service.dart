import 'dart:isolate';

import '../db/project_database.dart';
import 'validate_project.dart';
import 'validation_issue.dart';

/// Runs the project-wide validation pass off the UI isolate.
///
/// `sqlite3` handles cannot cross isolates, and the UI isolate's
/// [ProjectDatabase] is never sent across: [runProject] sends only
/// [projectPath], the background isolate opens its own read-only connection
/// to that file ([ProjectDatabase.openReadOnly], which also sets
/// `foreign_keys = ON`), validates and closes it, and only the plain
/// [ValidationIssue] values come back. The pass sees committed data only.
final class ValidationService {
  ValidationService({required this.projectPath});

  /// The project file the background isolate opens.
  final String projectPath;

  /// [validateProject] on a background isolate over its own connection.
  Future<List<ValidationIssue>> runProject() {
    final path = projectPath;
    return Isolate.run(() {
      final db = ProjectDatabase.openReadOnly(path);
      try {
        return validateProject(db);
      } finally {
        db.close();
      }
    });
  }
}
