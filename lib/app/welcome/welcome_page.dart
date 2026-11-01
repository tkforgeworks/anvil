import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../project/project_lifecycle.dart';
import '../providers.dart';
import '../settings/theme_mode_selector.dart';
import '../theme/anvil_metrics.dart';
import '../theme/theme_gallery_page.dart';
import 'create_project_dialog.dart';
import 'recent_projects_list.dart';
import 'upgrade_project_dialog.dart';
import 'welcome_tiles.dart';

/// The home while no project is open (0.1.6 `WelcomePage.tsx`, design
/// §13.2): the hero, the New and Open tiles and the recent list, with the
/// lifecycle's busy, failure, upgrade and recovery presentations.
class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});

  /// 0.1.6's maximum content width.
  static const contentWidth = 920.0;

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  var _upgradePromptOpen = false;

  @override
  void initState() {
    super.initState();
    // Fires for a pending upgrade the page finds on arrival as well as for
    // one that arrives while it shows.
    ref.listenManual(projectLifecycleProvider, (previous, next) {
      if (next is LifecycleNeedsUpgrade && previous is! LifecycleNeedsUpgrade) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _promptUpgrade());
      }
    }, fireImmediately: true);
  }

  Future<void> _promptUpgrade() async {
    if (!mounted || _upgradePromptOpen) return;
    if (ref.read(projectLifecycleProvider) is! LifecycleNeedsUpgrade) return;
    _upgradePromptOpen = true;
    final upgrade = await showUpgradeProjectDialog(context);
    _upgradePromptOpen = false;
    if (!mounted) return;
    final lifecycle = ref.read(projectLifecycleProvider.notifier);
    if (upgrade == true) {
      await lifecycle.upgradeCopy();
    } else {
      lifecycle.cancelUpgrade();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectLifecycleProvider);
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AnvilSpacing.unit * 6,
          vertical: AnvilSpacing.xl,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: WelcomePage.contentWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Hero(),
                const SizedBox(height: AnvilSpacing.lg),
                if (state case LifecycleRecovery(
                  :final fileName,
                  :final message,
                ))
                  RecoveryView(fileName: fileName, message: message)
                else
                  _WelcomeContent(state: state),
                const SizedBox(height: AnvilSpacing.lg),
                const _Footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final heading = text.headlineMedium?.copyWith(fontWeight: FontWeight.w700);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: 'Welcome to ',
            children: [
              TextSpan(
                text: 'Anvil',
                style: TextStyle(color: context.colors.primary),
              ),
            ],
          ),
          style: heading,
        ),
        const SizedBox(height: AnvilSpacing.xs),
        Text(
          'Pick a project, or start a new world.',
          style: text.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _WelcomeContent extends ConsumerWidget {
  const _WelcomeContent({required this.state});

  final ProjectLifecycleState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lifecycle = ref.read(projectLifecycleProvider.notifier);
    final recents = ref.watch(recentProjectsProvider);
    final busy = state is LifecycleBusy;
    final text = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state case LifecycleFailed(:final message)) ...[
          Semantics(
            liveRegion: true,
            child: ForgeErrorCard(
              message: message,
              onRetry: lifecycle.dismiss,
              retryLabel: 'Dismiss',
            ),
          ),
          const SizedBox(height: AnvilSpacing.md),
        ],
        if (state case LifecycleBusy(:final what)) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: AnvilSpacing.xs),
          Text('$what…', style: text.bodySmall),
          const SizedBox(height: AnvilSpacing.md),
        ],
        Row(
          children: [
            Expanded(
              child: WelcomeTile(
                brand: true,
                icon: Icons.add,
                title: 'New project',
                subtitle: 'Start a blank project',
                onPressed: busy ? null : () => showCreateProjectDialog(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: WelcomeTile(
                icon: Icons.folder_open,
                title: 'Open file...',
                subtitle: '.anvil project file',
                onPressed: busy ? null : lifecycle.openWithDialog,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Recent projects',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: AnvilSpacing.md),
            Expanded(
              child: Text(
                'Sorted by last save · stored locally',
                style: text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
            if (recents.isNotEmpty)
              TextButton(
                onPressed: busy ? null : lifecycle.clearRecents,
                child: const Text('Clear Recents'),
              ),
          ],
        ),
        const SizedBox(height: AnvilSpacing.sm),
        RecentProjectsList(
          projects: recents,
          enabled: !busy,
          onOpen: lifecycle.openPath,
          onRemove: lifecycle.removeRecent,
        ),
      ],
    );
  }
}

/// Recovery mode (design §12.4): the file that failed, why, and the way
/// back to the welcome page. Nothing is open.
class RecoveryView extends ConsumerWidget {
  const RecoveryView({
    super.key,
    required this.fileName,
    required this.message,
  });

  final String fileName;
  final String message;

  /// 0.1.6's recovery banner opened with this sentence (`AppShell.tsx`).
  static const heading = 'Recovery mode is active.';
  static const body =
      'The project could not be opened. Nothing is open and '
      'nothing can be edited.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forge = context.forge;
    final text = context.text;
    return Container(
      padding: const EdgeInsets.all(AnvilSpacing.md),
      decoration: BoxDecoration(
        color: forge.warningContainer,
        borderRadius: BorderRadius.circular(AnvilRadii.panel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: text.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: forge.onWarningContainer,
            ),
          ),
          const SizedBox(height: AnvilSpacing.xs),
          Text(
            body,
            style: text.bodyMedium?.copyWith(color: forge.onWarningContainer),
          ),
          const SizedBox(height: AnvilSpacing.md),
          const ForgeMonoLabel('File'),
          const SizedBox(height: AnvilSpacing.xs),
          SelectableText(
            fileName,
            style: ForgeType.code(color: forge.onWarningContainer),
          ),
          const SizedBox(height: AnvilSpacing.sm),
          const ForgeMonoLabel('Error'),
          const SizedBox(height: AnvilSpacing.xs),
          SelectableText(
            message,
            style: text.bodyMedium?.copyWith(color: forge.onWarningContainer),
          ),
          const SizedBox(height: AnvilSpacing.md),
          FilledButton(
            onPressed: ref.read(projectLifecycleProvider.notifier).dismiss,
            child: const Text('Back to Welcome'),
          ),
        ],
      ),
    );
  }
}

class _Footer extends ConsumerWidget {
  const _Footer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final caption = context.text.bodySmall?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    return Column(
      children: [
        Text.rich(
          const TextSpan(
            children: [
              TextSpan(
                text: 'Local-first:',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(
                text: ' all projects live on disk. No accounts, no sync.',
              ),
            ],
          ),
          style: caption,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AnvilSpacing.md),
        // Until the app settings dialog (ANVL-189) takes it over.
        const ForgeMonoLabel('Theme'),
        const SizedBox(height: AnvilSpacing.sm),
        ThemeModeSelector(settings: settings),
        if (kDebugMode) ...[
          const SizedBox(height: AnvilSpacing.sm),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ThemeGalleryPage()),
            ),
            child: const Text('Open theme gallery'),
          ),
        ],
      ],
    );
  }
}
