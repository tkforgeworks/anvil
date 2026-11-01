import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../menu/app_menu.dart';
import '../project/project_lifecycle.dart';
import '../providers.dart';
import '../theme/anvil_metrics.dart';
import 'sidebar.dart';

/// The open project's frame (0.1.6 `AppShell.tsx`, design §13.2, §13.3):
/// the app bar with the project name, the sidebar, and the current page as
/// [child]. The native window frame replaces 0.1.6's custom title bar.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  /// Where the hamburger menu goes (ANVL-186).
  static const menuSlotKey = ValueKey('app-shell-menu-slot');

  /// Where the save status indicator goes (ANVL-163).
  static const saveStatusSlotKey = ValueKey('app-shell-save-status-slot');

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The router leaves the shell as soon as the session is cleared; until
    // that frame, build nothing that needs the session. The shell watches
    // the nullable session rather than `requireSessionProvider`: a widget
    // still watching a provider when it throws gets the error reported.
    final session = ref.watch(projectSessionProvider);
    if (session == null) return const SizedBox.shrink();
    final name = session.metadata.projectName;
    final busy = ref.watch(projectLifecycleProvider) is LifecycleBusy;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: AnvilSpacing.md,
        shape: Border(bottom: BorderSide(color: context.colors.outlineVariant)),
        title: Row(
          children: [
            // The hamburger menu (ANVL-186) takes this slot.
            const AppMenuButton(key: menuSlotKey),
            Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          // The save status indicator (ANVL-163) takes this slot.
          const SizedBox.shrink(key: saveStatusSlotKey),
          // Until the menu's File section (ANVL-186) takes it over.
          TextButton(
            onPressed: busy
                ? null
                : ref.read(projectLifecycleProvider.notifier).closeProject,
            child: const Text('Close Project'),
          ),
          const SizedBox(width: AnvilSpacing.sm),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Sidebar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AnvilSpacing.lg),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
