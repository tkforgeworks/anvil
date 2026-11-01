import 'dart:io';

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';
import 'package:path_provider/path_provider.dart';

import '../dialogs/file_dialogs.dart';
import '../project/project_lifecycle.dart';
import '../providers.dart';
import '../theme/anvil_metrics.dart';

/// Opens the create-project dialog over whatever is showing (design §13.2:
/// reachable from any app state). Completes when the dialog closes; on a
/// successful create the new project is already current.
Future<void> showCreateProjectDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const CreateProjectDialog(),
);

/// The Documents folder, where the folder picker starts when no
/// `defaultSaveLocation` is set (0.1.6 `app.getPath('documents')`). Null
/// when the platform cannot say; tests override it.
final documentsDirectoryProvider = FutureProvider<String?>((ref) async {
  try {
    return (await getApplicationDocumentsDirectory()).path;
  } on Object {
    return null;
  }
});

/// `{parent}/{sanitized name}/database/{sanitized name}.anvil`, the file
/// `ProjectService.create` will make, or null when the name sanitizes to
/// nothing.
String? projectFilePreview(String parentDirectory, String projectName) {
  final name = sanitizeFolderName(projectName.trim());
  if (name.isEmpty) return null;
  final sep = Platform.pathSeparator;
  final parent = parentDirectory.endsWith(sep)
      ? parentDirectory.substring(0, parentDirectory.length - 1)
      : parentDirectory;
  return [parent, name, 'database', '$name.anvil'].join(sep);
}

/// "Create New Project" (0.1.6 `CreateProjectModal.tsx`): project name and
/// game title are required (trimmed) and, new in 0.2.0, the parent folder is
/// chosen in the dialog with a preview of the resulting file. Create stays
/// disabled until all three are set. A failed create shows the core's
/// message here and keeps the dialog open.
class CreateProjectDialog extends ConsumerStatefulWidget {
  const CreateProjectDialog({super.key});

  @override
  ConsumerState<CreateProjectDialog> createState() =>
      _CreateProjectDialogState();
}

class _CreateProjectDialogState extends ConsumerState<CreateProjectDialog> {
  final _name = TextEditingController();
  final _title = TextEditingController();
  String? _folder;
  var _attempted = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(_changed);
    _title.addListener(_changed);
  }

  @override
  void dispose() {
    _name.dispose();
    _title.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  Future<void> _chooseFolder() async {
    // Read at call time: the setting can change while the app runs.
    final initial =
        ref.read(appSettingsProvider).defaultSaveLocation ??
        await ref.read(documentsDirectoryProvider.future);
    final picked = await ref
        .read(fileDialogsProvider)
        .pickDirectory(initialDirectory: initial);
    if (picked != null && mounted) setState(() => _folder = picked);
  }

  Future<void> _create() async {
    final folder = _folder;
    if (folder == null) return;
    setState(() => _attempted = true);
    final created = await ref
        .read(projectLifecycleProvider.notifier)
        .create(_name.text.trim(), _title.text.trim(), folder);
    if (created && mounted) Navigator.of(context).pop();
  }

  // However the dialog closes (Cancel, Escape, the barrier), a failure it
  // showed belongs to it and is not left on the page behind.
  void _closed(bool didPop, Object? _) {
    if (didPop && _attempted) {
      ref.read(projectLifecycleProvider.notifier).dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lifecycle = ref.watch(projectLifecycleProvider);
    final busy = lifecycle is LifecycleBusy;
    final error = _attempted && lifecycle is LifecycleFailed
        ? lifecycle.message
        : null;
    final name = _name.text.trim();
    final title = _title.text.trim();
    final folder = _folder;
    final preview = folder == null ? null : projectFilePreview(folder, name);
    final canCreate =
        name.isNotEmpty && title.isNotEmpty && folder != null && !busy;
    final c = context.colors;
    final secondary = context.text.bodySmall?.copyWith(
      color: c.onSurfaceVariant,
    );

    return PopScope(
      canPop: !busy,
      onPopInvokedWithResult: _closed,
      child: AlertDialog(
        title: const Text('Create New Project'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: context.text.bodyMedium?.copyWith(color: c.error),
                  ),
                ),
                const SizedBox(height: AnvilSpacing.md),
              ],
              TextField(
                key: const ValueKey('create-project-name'),
                controller: _name,
                autofocus: true,
                enabled: !busy,
                decoration: const InputDecoration(labelText: 'Project Name *'),
              ),
              const SizedBox(height: AnvilSpacing.md),
              TextField(
                key: const ValueKey('create-project-title'),
                controller: _title,
                enabled: !busy,
                decoration: const InputDecoration(labelText: 'Game Title *'),
              ),
              const SizedBox(height: AnvilSpacing.md),
              const ForgeMonoLabel('Folder'),
              const SizedBox(height: AnvilSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      folder ?? 'No folder selected',
                      key: const ValueKey('create-project-folder'),
                      overflow: TextOverflow.ellipsis,
                      style: folder == null
                          ? secondary
                          : ForgeType.code(color: c.onSurface),
                    ),
                  ),
                  const SizedBox(width: AnvilSpacing.sm),
                  OutlinedButton(
                    onPressed: busy ? null : _chooseFolder,
                    child: const Text('Choose Folder…'),
                  ),
                ],
              ),
              if (preview != null) ...[
                const SizedBox(height: AnvilSpacing.md),
                const ForgeMonoLabel('Project file'),
                const SizedBox(height: AnvilSpacing.xs),
                Text(
                  preview,
                  key: const ValueKey('create-project-preview'),
                  style: ForgeType.code(size: 12, color: c.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: canCreate ? _create : null,
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
