import 'package:meta/meta.dart';

/// Active (not soft-deleted) records per domain, as `RecordCounts` in
/// Electron's `src/shared/project-types.ts`. The JSON keys and their order
/// are the 0.1.6 ones, so `recent-projects.json` stays readable by both.
@immutable
final class RecordCounts {
  const RecordCounts({
    this.classes = 0,
    this.abilities = 0,
    this.items = 0,
    this.recipes = 0,
    this.npcs = 0,
    this.lootTables = 0,
  });

  static const empty = RecordCounts();

  final int classes;
  final int abilities;
  final int items;
  final int recipes;
  final int npcs;
  final int lootTables;

  /// Reads a stored object, filling missing or non-integer keys with 0 as
  /// Electron's `{ ...EMPTY_RECORD_COUNTS, ...project.recordCounts }` did.
  factory RecordCounts.fromJson(Object? json) {
    final map = json is Map ? json : const {};
    int read(String key) {
      final value = map[key];
      return value is num ? value.toInt() : 0;
    }

    return RecordCounts(
      classes: read('classes'),
      abilities: read('abilities'),
      items: read('items'),
      recipes: read('recipes'),
      npcs: read('npcs'),
      lootTables: read('lootTables'),
    );
  }

  Map<String, Object?> toJson() => {
    'classes': classes,
    'abilities': abilities,
    'items': items,
    'recipes': recipes,
    'npcs': npcs,
    'lootTables': lootTables,
  };

  @override
  bool operator ==(Object other) =>
      other is RecordCounts &&
      other.classes == classes &&
      other.abilities == abilities &&
      other.items == items &&
      other.recipes == recipes &&
      other.npcs == npcs &&
      other.lootTables == lootTables;

  @override
  int get hashCode =>
      Object.hash(classes, abilities, items, recipes, npcs, lootTables);

  @override
  String toString() => 'RecordCounts(${toJson()})';
}

/// The `{ProjectName}/database|exports|temp|logs` folder set, as
/// `ProjectFolderPaths` in Electron.
@immutable
final class ProjectFolderPaths {
  const ProjectFolderPaths({
    required this.root,
    required this.database,
    required this.exports,
    required this.temp,
    required this.logs,
  });

  final String root;
  final String database;
  final String exports;
  final String temp;
  final String logs;

  /// Returns null unless [json] is an object with all five string keys.
  static ProjectFolderPaths? fromJson(Object? json) {
    if (json is! Map) return null;
    final values = [
      for (final key in const ['root', 'database', 'exports', 'temp', 'logs'])
        json[key],
    ];
    if (values.any((v) => v is! String)) return null;
    return ProjectFolderPaths(
      root: values[0] as String,
      database: values[1] as String,
      exports: values[2] as String,
      temp: values[3] as String,
      logs: values[4] as String,
    );
  }

  Map<String, Object?> toJson() => {
    'root': root,
    'database': database,
    'exports': exports,
    'temp': temp,
    'logs': logs,
  };

  @override
  bool operator ==(Object other) =>
      other is ProjectFolderPaths &&
      other.root == root &&
      other.database == database &&
      other.exports == exports &&
      other.temp == temp &&
      other.logs == logs;

  @override
  int get hashCode => Object.hash(root, database, exports, temp, logs);

  @override
  String toString() => 'ProjectFolderPaths(${toJson()})';
}

/// What the app knows about an open project, as `ProjectMetadata` in
/// Electron.
@immutable
final class ProjectMetadata {
  const ProjectMetadata({
    required this.projectName,
    required this.gameTitle,
    required this.filePath,
    required this.projectFolder,
    required this.schemaVersion,
    required this.lastModifiedAt,
    required this.fileSize,
    required this.recordCounts,
  });

  final String projectName;
  final String gameTitle;
  final String filePath;

  /// The folder set around the file, or null when the file is not in a
  /// `database/` folder with its three siblings.
  final ProjectFolderPaths? projectFolder;
  final int schemaVersion;

  /// The file's modification time, UTC, in JavaScript `toISOString()` form.
  final String lastModifiedAt;
  final int fileSize;
  final RecordCounts recordCounts;

  /// The 0.1.6 keys in 0.1.6 order.
  Map<String, Object?> toJson() => {
    'projectName': projectName,
    'gameTitle': gameTitle,
    'filePath': filePath,
    'projectFolder': projectFolder?.toJson(),
    'schemaVersion': schemaVersion,
    'lastModifiedAt': lastModifiedAt,
    'fileSize': fileSize,
    'recordCounts': recordCounts.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is ProjectMetadata &&
      other.projectName == projectName &&
      other.gameTitle == gameTitle &&
      other.filePath == filePath &&
      other.projectFolder == projectFolder &&
      other.schemaVersion == schemaVersion &&
      other.lastModifiedAt == lastModifiedAt &&
      other.fileSize == fileSize &&
      other.recordCounts == recordCounts;

  @override
  int get hashCode => Object.hash(
    projectName,
    gameTitle,
    filePath,
    projectFolder,
    schemaVersion,
    lastModifiedAt,
    fileSize,
    recordCounts,
  );

  @override
  String toString() => 'ProjectMetadata(${toJson()})';
}

/// One entry of `recent-projects.json`: `RecentProject` in Electron, which
/// is `ProjectMetadata` plus `exists` and the optional `isArchived` (only
/// ever read by 0.1.6's welcome page, never written; kept so a file that
/// has it round-trips).
@immutable
final class RecentProject {
  const RecentProject({
    required this.project,
    required this.exists,
    this.isArchived,
  });

  final ProjectMetadata project;
  final bool exists;
  final bool? isArchived;

  String get filePath => project.filePath;

  /// Reads one stored entry. Returns null when `filePath` is not a string,
  /// which Electron's reader filtered out; other missing fields fall back to
  /// empty values.
  static RecentProject? fromJson(Object? json) {
    if (json is! Map) return null;
    final filePath = json['filePath'];
    if (filePath is! String) return null;
    String text(String key) => switch (json[key]) {
      final String s => s,
      _ => '',
    };
    int number(String key) => switch (json[key]) {
      final num n => n.toInt(),
      _ => 0,
    };
    return RecentProject(
      project: ProjectMetadata(
        projectName: text('projectName'),
        gameTitle: text('gameTitle'),
        filePath: filePath,
        projectFolder: ProjectFolderPaths.fromJson(json['projectFolder']),
        schemaVersion: number('schemaVersion'),
        lastModifiedAt: text('lastModifiedAt'),
        fileSize: number('fileSize'),
        recordCounts: RecordCounts.fromJson(json['recordCounts']),
      ),
      exists: json['exists'] == true,
      isArchived: switch (json['isArchived']) {
        final bool b => b,
        _ => null,
      },
    );
  }

  /// The metadata keys, then `exists`, then `isArchived` when set: the order
  /// Electron's `{ ...project, exists: true }` produced.
  Map<String, Object?> toJson() => {
    ...project.toJson(),
    'exists': exists,
    if (isArchived != null) 'isArchived': isArchived,
  };

  @override
  bool operator ==(Object other) =>
      other is RecentProject &&
      other.project == project &&
      other.exists == exists &&
      other.isArchived == isArchived;

  @override
  int get hashCode => Object.hash(project, exists, isArchived);

  @override
  String toString() => 'RecentProject(${toJson()})';
}

/// [time] in UTC as JavaScript's `Date.prototype.toISOString()` prints it,
/// `YYYY-MM-DDTHH:mm:ss.sssZ`, for the lock file and `lastModifiedAt`.
///
/// The migration runner has the same helper, but it is `@visibleForTesting`
/// there, so the project layer keeps its own.
@internal
String jsIsoString(DateTime time) {
  final t = time.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year.toString().padLeft(4, '0')}-${two(t.month)}-${two(t.day)}'
      'T${two(t.hour)}:${two(t.minute)}:${two(t.second)}'
      '.${t.millisecond.toString().padLeft(3, '0')}Z';
}
