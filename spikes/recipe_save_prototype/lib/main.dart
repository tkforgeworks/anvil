import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/app.dart';
import 'src/app/providers.dart';
import 'src/core/project_database.dart';

/// Usage: `recipe_save_prototype <path/to/project.anvil>` (or ANVIL_FILE).
/// The file is copied to a fresh temp directory and only the copy is opened.
void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  final source = args.isNotEmpty
      ? args.first
      : Platform.environment['ANVIL_FILE'];
  if (source == null || !File(source).existsSync()) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Usage: recipe_save_prototype <path/to/project.anvil>'),
          ),
        ),
      ),
    );
    return;
  }
  final workDir = Directory.systemTemp.createTempSync('anvl158-');
  final project = ProjectDatabase.openCopy(source, workDir: workDir);
  stdout.writeln('ANVL-158: working copy at ${project.path}');
  runApp(
    ProviderScope(
      overrides: [projectDatabaseProvider.overrideWithValue(project)],
      child: PrototypeApp(workingCopyPath: project.path),
    ),
  );
}
