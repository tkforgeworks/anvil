import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'project_folder.dart';
import 'project_metadata.dart';

/// `recent-projects.json`, the 0.1.6 recent list (`readRecentProjects` /
/// `writeRecentProjects` in `project-service.ts`).
///
/// The file is a JSON array written as `JSON.stringify(list, null, 2)`,
/// newest first, at most [maxEntries] entries, each with the
/// `RecentProject` keys in 0.1.6 order. A missing, unreadable or corrupt
/// file reads as empty.
final class RecentProjectsStore {
  RecentProjectsStore(this.filePath);

  /// 0.1.6's file name, directly in the application support directory.
  static const fileName = 'recent-projects.json';

  /// 0.1.6 kept ten entries.
  static const maxEntries = 10;

  final String filePath;

  /// The stored entries, refreshed from disk: `exists`, and for files that
  /// still exist the folder structure, modification time and size. Entries
  /// whose file is gone keep their stored values.
  ///
  /// Also capped at [maxEntries] and de-duplicated by path
  /// case-insensitively (first entry wins), which 0.1.6 only enforced when
  /// writing.
  List<RecentProject> read() {
    final List<Object?> raw;
    try {
      final file = File(filePath);
      if (!file.existsSync()) return [];
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! List) return [];
      raw = decoded;
    } on Object {
      return [];
    }

    final seen = <String>{};
    final result = <RecentProject>[];
    for (final item in raw) {
      final entry = RecentProject.fromJson(item);
      if (entry == null) continue;
      if (!seen.add(entry.filePath.toLowerCase())) continue;
      result.add(_refresh(entry));
      if (result.length == maxEntries) break;
    }
    return result;
  }

  /// Puts [project] at the front (as `exists: true`), dropping any entry
  /// with the same path, and writes the list.
  void add(ProjectMetadata project) {
    final key = project.filePath.toLowerCase();
    _write([
      RecentProject(project: project, exists: true),
      ...read().where((r) => r.filePath.toLowerCase() != key),
    ]);
  }

  /// Removes the entry for [path] (case-insensitive) and writes the list.
  void remove(String path) {
    final key = path.toLowerCase();
    _write(read().where((r) => r.filePath.toLowerCase() != key).toList());
  }

  /// Writes an empty list, as 0.1.6's `clearRecentProjects`.
  void clear() => _write(const []);

  void _write(List<RecentProject> entries) {
    Directory(p.dirname(filePath)).createSync(recursive: true);
    final json = [for (final e in entries.take(maxEntries)) e.toJson()];
    File(filePath).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(json),
      flush: true,
    );
  }

  static RecentProject _refresh(RecentProject entry) {
    final path = entry.filePath;
    final FileStat stat;
    try {
      stat = File(path).statSync();
    } on FileSystemException {
      return RecentProject(
        project: entry.project,
        exists: false,
        isArchived: entry.isArchived,
      );
    }
    if (stat.type == FileSystemEntityType.notFound) {
      return RecentProject(
        project: entry.project,
        exists: false,
        isArchived: entry.isArchived,
      );
    }
    final stored = entry.project;
    return RecentProject(
      project: ProjectMetadata(
        projectName: stored.projectName,
        gameTitle: stored.gameTitle,
        filePath: path,
        projectFolder: detectProjectFolder(path),
        schemaVersion: stored.schemaVersion,
        lastModifiedAt: jsIsoString(stat.modified),
        fileSize: stat.size,
        recordCounts: stored.recordCounts,
      ),
      exists: true,
      isArchived: entry.isArchived,
    );
  }
}
