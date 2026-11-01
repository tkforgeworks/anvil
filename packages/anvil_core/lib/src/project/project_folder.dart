import 'dart:io';

import 'package:path/path.dart' as p;

import 'project_errors.dart';
import 'project_folder_name.dart';
import 'project_metadata.dart';

const _subdirs = ['database', 'exports', 'temp', 'logs'];

/// Creates `{parentDir}/{sanitized projectName}/` with its `database/`,
/// `exports/`, `temp/` and `logs/` folders. Port of `createProjectFolder` in
/// Electron's `project-folder.ts`, with its messages.
///
/// Throws [ProjectCreateFailed] when the name sanitizes to nothing or the
/// folder (or any file of that name) already exists; an existing folder is
/// never touched. If a sub-folder cannot be made, the folder this call
/// created is removed and the [FileSystemException] is rethrown.
ProjectFolderPaths createProjectFolder(String parentDir, String projectName) {
  final folderName = sanitizeFolderName(projectName);
  if (folderName.isEmpty) {
    throw const ProjectCreateFailed(
      'Project name produces an empty folder name.',
    );
  }

  final root = p.join(parentDir, folderName);
  if (_exists(root)) {
    throw ProjectCreateFailed('Folder already exists: $root');
  }

  final paths = _buildPaths(root);
  try {
    for (final dir in _subdirPaths(paths)) {
      Directory(dir).createSync(recursive: true);
    }
  } on FileSystemException {
    try {
      if (Directory(root).existsSync()) {
        Directory(root).deleteSync(recursive: true);
      }
    } on FileSystemException {
      // Best effort; the original failure is what the caller needs.
    }
    rethrow;
  }
  return paths;
}

/// The folder set around [anvilFilePath] when the file sits in a folder
/// named `database` whose parent also has `exports/`, `temp/` and `logs/`;
/// otherwise null. Port of `detectProjectFolder`.
ProjectFolderPaths? detectProjectFolder(String anvilFilePath) {
  final parentDir = p.dirname(anvilFilePath);
  if (p.basename(parentDir) != 'database') return null;

  final paths = _buildPaths(p.dirname(parentDir));
  for (final dir in _subdirPaths(paths)) {
    if (!_exists(dir)) return null;
  }
  return paths;
}

ProjectFolderPaths _buildPaths(String root) => ProjectFolderPaths(
  root: root,
  database: p.join(root, _subdirs[0]),
  exports: p.join(root, _subdirs[1]),
  temp: p.join(root, _subdirs[2]),
  logs: p.join(root, _subdirs[3]),
);

List<String> _subdirPaths(ProjectFolderPaths paths) => [
  paths.database,
  paths.exports,
  paths.temp,
  paths.logs,
];

/// Node's `existsSync`: true for a file, folder or link.
bool _exists(String path) =>
    FileSystemEntity.typeSync(path, followLinks: false) !=
    FileSystemEntityType.notFound;
