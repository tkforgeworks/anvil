/// The hero's `Backup` button (0.1.6 `DashboardPage.tsx` `dash-backup` and
/// `backupProject`): asks where to save a snapshot of the open project and
/// writes it there; the open project does not change.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../editor/clock.dart';
import '../menu/menu_commands.dart';
import '../project/project_lifecycle.dart';
import '../providers.dart';

/// 0.1.6's default backup file name: the project name with every character
/// outside `[a-zA-Z0-9_-]` replaced by `_`, then `-backup-` and the UTC date
/// of [now] as `YYYY-MM-DD`.
String defaultBackupName(String projectName, DateTime now) {
  final name = projectName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  final date = now.toUtc().toIso8601String().split('T').first;
  return '$name-backup-$date.anvil';
}

/// Where the backup dialog starts: the project's folder root when it has
/// the folder structure, else the folder holding the file. 0.1.6 always
/// started in the file's folder (`database/` in a project folder).
String backupFolderOf(ProjectMetadata project) =>
    project.projectFolder?.root ??
    splitFilePath(project.filePath).folder ??
    '.';

/// The snackbar after a written backup.
String backupSavedMessage(String path) => 'Backup saved to $path';

/// An outlined `Backup` button in the hero's colours. A cancelled dialog does
/// nothing; a written backup shows [backupSavedMessage], a failure the
/// lifecycle's message. Disabled while the lifecycle is busy, because a busy
/// lifecycle ignores the request.
class BackupButton extends ConsumerWidget {
  const BackupButton({required this.project, super.key});

  static const buttonKey = ValueKey('dash-backup');

  final ProjectMetadata project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = context.colors.onPrimary;
    final busy = ref.watch(projectLifecycleProvider) is LifecycleBusy;
    return OutlinedButton.icon(
      key: buttonKey,
      style: OutlinedButton.styleFrom(
        foregroundColor: on,
        side: BorderSide(color: on.withValues(alpha: 0.5)),
      ),
      onPressed: busy ? null : () => unawaited(_backup(context, ref)),
      icon: const Icon(Icons.download),
      label: const Text('Backup'),
    );
  }

  Future<void> _backup(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final name = defaultBackupName(
      project.projectName,
      ref.read(clockProvider)(),
    );
    final folder = backupFolderOf(project);
    final separator = folder.endsWith('/') || folder.endsWith(r'\')
        ? ''
        : Platform.pathSeparator;
    final picked = await ref.read(saveLocationPickerProvider)(
      suggestedPath: '$folder$separator$name',
    );
    if (picked == null || !context.mounted) return;
    // file_selector sets no type filter, so add the extension as Save As does.
    final path = normalizeAnvilPath(picked);
    // A busy lifecycle or a closed project would answer null without
    // writing anything, which must not read as a saved backup.
    if (ref.read(projectLifecycleProvider) is LifecycleBusy ||
        ref.read(projectSessionProvider) == null) {
      return;
    }
    final failure = await ref
        .read(projectLifecycleProvider.notifier)
        .backup(path);
    messenger?.showSnackBar(
      SnackBar(content: Text(failure ?? backupSavedMessage(path))),
    );
  }
}
