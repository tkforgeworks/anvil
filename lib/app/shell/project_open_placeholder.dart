import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../project/project_lifecycle.dart';
import '../providers.dart';
import '../theme/anvil_metrics.dart';

/// What shows while a project is open, until the application shell
/// (ANVL-185) replaces it: the project's name, game title and path, and
/// Close Project.
class ProjectOpenPlaceholder extends ConsumerWidget {
  const ProjectOpenPlaceholder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(projectSessionProvider);
    final lifecycle = ref.watch(projectLifecycleProvider);
    if (session == null) return const SizedBox.shrink();
    final metadata = session.metadata;
    final text = context.text;
    final c = context.colors;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AnvilSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ForgeMonoLabel('Open project'),
              const SizedBox(height: AnvilSpacing.sm),
              Text(metadata.projectName, style: text.headlineMedium),
              const SizedBox(height: AnvilSpacing.xs),
              Text(
                metadata.gameTitle,
                style: text.titleMedium?.copyWith(color: c.onSurfaceVariant),
              ),
              const SizedBox(height: AnvilSpacing.sm),
              SelectableText(
                metadata.filePath,
                textAlign: TextAlign.center,
                style: ForgeType.code(color: c.onSurfaceVariant),
              ),
              const SizedBox(height: AnvilSpacing.lg),
              Text(
                'The application shell lands with ANVL-185.',
                style: text.bodySmall?.copyWith(color: c.onSurfaceVariant),
              ),
              const SizedBox(height: AnvilSpacing.md),
              FilledButton(
                onPressed: lifecycle is LifecycleBusy
                    ? null
                    : ref.read(projectLifecycleProvider.notifier).closeProject,
                child: const Text('Close Project'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
