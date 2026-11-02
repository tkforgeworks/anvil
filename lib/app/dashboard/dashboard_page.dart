/// The dashboard at `/` (design §12.8; 0.1.6 `DashboardPage.tsx`): the
/// project hero with the save status and Quick add, the six count tiles
/// with their weekly deltas, the save history feed, the validation tile and
/// the Quick add card. 0.1.6's auto-save card is not ported (design §12.8).
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../editor/clock.dart';
import '../editor/save_status.dart';
import '../shell/app_router.dart';
import '../shell/shell_providers.dart';
import '../theme/anvil_metrics.dart';
import '../validation/last_checked.dart';
import '../welcome/recent_projects_list.dart' show ProjectInitialsMark;
import '../widgets/formatting.dart';
import 'count_tile.dart';
import 'dashboard_providers.dart';
import 'quick_add.dart';
import 'save_history_feed.dart';
import 'status_tag.dart';
import 'validation_tile.dart';

/// Everything is read from providers re-read on every write
/// (`writeEpochProvider`), so the page follows saves made anywhere without
/// 0.1.6's five-second polling. Renders nothing while no project is open.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  /// From this width the save history and the right column sit side by
  /// side (0.1.6's `md` breakpoint, `2fr 1fr`).
  static const twoColumnWidth = 900.0;

  static const heroKey = ValueKey('dash-hero');
  static const errorKey = ValueKey('dash-error');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(dashboardProjectProvider);
    if (project == null) return const SizedBox.shrink();
    // Keeps the Validation page's `Last checked` stamp following every run
    // from the moment the project opens on this page.
    ref.listen(validationLastCheckedProvider, (_, _) {});

    final counts = ref.watch(recordCountsProvider);
    final deltas = ref.watch(weeklyDeltasProvider);
    final history = ref.watch(saveHistoryProvider);
    final issues = ref.watch(validationIssuesProvider).value;
    final status = ref.watch(saveStatusProvider);
    final now = ref.watch(clockProvider)();
    void go(String location) => ref.read(routerProvider).go(location);

    final refreshError = counts.error ?? deltas.error;
    final entries = history.value ?? const <SaveHistoryEntry>[];
    final lastSaved = entries.isEmpty
        ? project.lastModifiedAt
        : entries.first.savedAt;

    final feed = SaveHistoryFeed(
      entries: entries,
      now: now,
      error: history.hasError ? 'Unable to read the save history.' : null,
    );
    final side = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValidationTile(issues: issues, onTap: () => go('/validation')),
        const SizedBox(height: CountTiles.gap),
        const QuickAddCard(),
      ],
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (refreshError != null) ...[
            Text(
              'Unable to refresh dashboard: $refreshError',
              key: errorKey,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.error,
              ),
            ),
            const SizedBox(height: AnvilSpacing.md),
          ],
          _Hero(
            project: project,
            status: status,
            lastSaved: lastSaved,
            now: now,
          ),
          const SizedBox(height: AnvilSpacing.md),
          CountTiles(
            counts: counts.value,
            deltas: deltas.value,
            onOpen: (domain) => go(domain.location),
          ),
          const SizedBox(height: AnvilSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) =>
                constraints.maxWidth >= twoColumnWidth
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: feed),
                      const SizedBox(width: CountTiles.gap),
                      Expanded(child: side),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      feed,
                      const SizedBox(height: CountTiles.gap),
                      side,
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// The banner in the primary colour: the initials mark, the project name
/// with the [StatusTag], `Last saved <relative>`, the folder (or file) and
/// the file size, and the Quick add button.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.project,
    required this.status,
    required this.lastSaved,
    required this.now,
  });

  static const markSize = 56.0;

  final ProjectMetadata project;
  final SaveStatus status;

  /// The newest save history row's time, or the file's modification time
  /// at open when the history is empty.
  final String lastSaved;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final on = c.onPrimary;
    final saved = DateTime.tryParse(lastSaved);
    return Container(
      key: DashboardPage.heroKey,
      padding: const EdgeInsets.all(AnvilSpacing.md),
      decoration: BoxDecoration(
        color: c.primary,
        borderRadius: BorderRadius.circular(AnvilRadii.panel),
      ),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: on.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(AnvilRadii.control),
            ),
            child: ProjectInitialsMark(
              name: project.projectName,
              size: markSize,
            ),
          ),
          const SizedBox(width: AnvilSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        project.projectName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: on,
                        ),
                      ),
                    ),
                    const SizedBox(width: AnvilSpacing.sm),
                    StatusTag(status),
                  ],
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    text: 'Last saved ',
                    children: [
                      TextSpan(
                        text: saved == null
                            ? '—'
                            : formatRelativeTimestamp(saved, now: now),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  style: context.text.bodyMedium?.copyWith(
                    color: on.withValues(alpha: 0.8),
                  ),
                ),
                Text(
                  '${project.projectFolder?.root ?? project.filePath} · '
                  '${formatFileSize(project.fileSize)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ForgeType.code(
                    size: 12,
                    color: on.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AnvilSpacing.md),
          const QuickAddButton(),
        ],
      ),
    );
  }
}
