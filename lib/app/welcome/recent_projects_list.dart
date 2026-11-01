import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:forge_ui/forge_ui.dart';

import '../theme/anvil_metrics.dart';
import '../widgets/formatting.dart';

/// The welcome page's recent list (0.1.6 `WelcomePage.tsx`): one row per
/// entry with the initials mark, name, archived marker, record summary,
/// relative last-modified time, missing-file marker, path, file size and a
/// Remove button. A row opens its project on tap unless the file is missing
/// or [enabled] is false.
class RecentProjectsList extends StatelessWidget {
  const RecentProjectsList({
    super.key,
    required this.projects,
    required this.onOpen,
    required this.onRemove,
    this.enabled = true,
    this.now,
  });

  final List<RecentProject> projects;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onRemove;
  final bool enabled;

  /// The clock for the relative times; tests pin it.
  final DateTime? now;

  static const emptyMessage =
      'No recent projects yet. Create a new project or open an existing '
      '.anvil file.';

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AnvilSpacing.lg),
        child: Text(
          emptyMessage,
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      );
    }
    final c = context.colors;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AnvilRadii.panel),
        side: BorderSide(color: c.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, project) in projects.indexed) ...[
            if (i > 0) Divider(height: 1, color: c.outlineVariant),
            _RecentRow(
              project: project,
              enabled: enabled,
              now: now,
              onOpen: () => onOpen(project.filePath),
              onRemove: () => onRemove(project.filePath),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({
    required this.project,
    required this.enabled,
    required this.now,
    required this.onOpen,
    required this.onRemove,
  });

  final RecentProject project;
  final bool enabled;
  final DateTime? now;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final metadata = project.project;
    final counts = metadata.recordCounts;
    final summary = formatRecordSummary(
      items: counts.items,
      abilities: counts.abilities,
      classes: counts.classes,
      npcs: counts.npcs,
      recipes: counts.recipes,
      lootTables: counts.lootTables,
    );
    final archived = project.isArchived == true;
    final modified = DateTime.tryParse(metadata.lastModifiedAt);
    final secondary = text.bodySmall?.copyWith(color: c.onSurfaceVariant);

    return Opacity(
      opacity: !project.exists ? 0.5 : (archived ? 0.7 : 1),
      child: InkWell(
        onTap: project.exists && enabled ? onOpen : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProjectInitialsMark(name: metadata.projectName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            metadata.projectName,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (archived) ...[
                          const SizedBox(width: AnvilSpacing.sm),
                          const ForgeTagCapsule('archived'),
                        ],
                        const SizedBox(width: AnvilSpacing.sm),
                        Flexible(
                          child: Text(
                            '· ${summary.isEmpty ? 'empty project' : summary}',
                            overflow: TextOverflow.ellipsis,
                            style: secondary,
                          ),
                        ),
                      ],
                    ),
                    if (metadata.gameTitle.isNotEmpty)
                      Text(
                        metadata.gameTitle,
                        overflow: TextOverflow.ellipsis,
                        style: secondary,
                      ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: c.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Last saved '
                          '${modified == null ? 'unknown' : formatRelativeTimestamp(modified, now: now)}',
                          style: secondary,
                        ),
                        if (!project.exists) ...[
                          const SizedBox(width: AnvilSpacing.sm),
                          Text(
                            '· File missing',
                            style: text.bodySmall?.copyWith(color: c.error),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      metadata.filePath,
                      overflow: TextOverflow.ellipsis,
                      style: ForgeType.code(
                        size: 11,
                        color: c.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatFileSize(metadata.fileSize),
                    style: ForgeType.code(size: 11, color: c.onSurfaceVariant),
                  ),
                  TextButton(
                    onPressed: enabled ? onRemove : null,
                    style: TextButton.styleFrom(
                      foregroundColor: c.onSurface,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AnvilSpacing.xs,
                        vertical: 2,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: text.labelSmall,
                    ),
                    child: const Text('Remove'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The project's initials on a primary square (`ProjectInitialsMark` in
/// 0.1.6): the first letters of the first two words, else the first letter,
/// else `?`.
class ProjectInitialsMark extends StatelessWidget {
  const ProjectInitialsMark({super.key, required this.name, this.size = 34});

  final String name;
  final double size;

  /// `getInitials` in `ProjectInitialsMark.tsx`.
  static String initialsOf(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${_first(words[0])}${_first(words[1])}'.toUpperCase();
    }
    final first = _first(words.first);
    return (first.isEmpty ? '?' : first).toUpperCase();
  }

  static String _first(String word) =>
      word.isEmpty ? '' : String.fromCharCode(word.runes.first);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.primary,
        borderRadius: BorderRadius.circular(AnvilRadii.control),
      ),
      child: Text(
        initialsOf(name),
        style: ForgeType.ui(
          size: (size * 0.38).roundToDouble(),
          weight: FontWeight.w700,
          color: c.onPrimary,
        ).copyWith(height: 1),
      ),
    );
  }
}
