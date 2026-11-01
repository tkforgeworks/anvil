import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';
import 'package:go_router/go_router.dart';

import '../theme/anvil_metrics.dart';
import 'shell_domain.dart';
import 'shell_providers.dart';

/// The shell's navigation (0.1.6 `Sidebar.tsx`): Dashboard; the six domains
/// with their active record counts; Validation with the error plus warning
/// count, Recycle Bin with the trash count, and Export; and the collapse
/// toggle at the bottom. Collapsed it is [AnvilLayout.sidebarCollapsedWidth]
/// wide with icons only, tooltips and a dot where a badge would show.
///
/// A column of its own rather than a `NavigationRail`, which cannot show
/// counts and badges beside expanded labels.
class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  /// 0.1.6's `TRANSITION_DURATION`.
  static const transition = Duration(milliseconds: 200);

  /// Badges show at most this, then [badgeOverflow].
  static const badgeCap = 99;
  static const badgeOverflow = '99+';

  static const toggleKey = ValueKey('sidebar-toggle');

  /// The count beside [domain]'s entry.
  static Key countKey(ShellDomain domain) =>
      ValueKey('sidebar-count-${domain.name}');

  /// The badge on [entry] (`validation` or `recycle-bin`) when expanded.
  static Key badgeKey(String entry) => ValueKey('sidebar-badge-$entry');

  /// The dot on [entry]'s icon when collapsed.
  static Key dotKey(String entry) => ValueKey('sidebar-dot-$entry');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collapsed = ref.watch(sidebarCollapsedProvider);
    final counts = ref.watch(recordCountsProvider).value;
    final trash = ref.watch(trashCountProvider).value ?? 0;
    final issues = ref.watch(validationIssuesProvider).value ?? const [];
    final issueCount = issues
        .where(
          (i) =>
              i.severity == ValidationSeverity.error ||
              i.severity == ValidationSeverity.warning,
        )
        .length;
    final hasErrors = issues.any((i) => i.severity == ValidationSeverity.error);
    final path = GoRouterState.of(context).uri.path;
    bool under(String location) =>
        path == location || path.startsWith('$location/');

    final c = context.colors;
    final forge = context.forge;
    final width = collapsed
        ? AnvilLayout.sidebarCollapsedWidth
        : AnvilLayout.sidebarWidth;

    _Entry entry({
      required String id,
      required IconData icon,
      required String label,
      required String location,
      required bool selected,
      int? count,
      Key? countKey,
      int badge = 0,
      Color? badgeColor,
      Color? onBadgeColor,
    }) => _Entry(
      id: id,
      icon: icon,
      label: label,
      selected: selected,
      collapsed: collapsed,
      count: count,
      countKey: countKey,
      badge: badge,
      badgeColor: badgeColor ?? c.error,
      onBadgeColor: onBadgeColor ?? c.onError,
      onTap: () => context.go(location),
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AnvilSpacing.sm),
        entry(
          id: 'dashboard',
          icon: Icons.dashboard,
          label: 'Dashboard',
          location: '/',
          selected: path == '/',
        ),
        const _SidebarDivider(),
        for (final domain in ShellDomain.values)
          entry(
            id: domain.name,
            icon: domain.icon,
            label: domain.label,
            location: domain.location,
            selected: under(domain.location),
            count: counts == null ? null : domain.countIn(counts),
            countKey: countKey(domain),
          ),
        const _SidebarDivider(),
        entry(
          id: 'validation',
          icon: Icons.check_circle,
          label: 'Validation',
          location: '/validation',
          selected: under('/validation'),
          badge: issueCount,
          badgeColor: hasErrors ? c.error : forge.warning,
          onBadgeColor: hasErrors ? c.onError : forge.onWarning,
        ),
        entry(
          id: 'recycle-bin',
          icon: Icons.delete,
          label: 'Recycle Bin',
          location: '/recycle-bin',
          selected: under('/recycle-bin'),
          badge: trash,
          badgeColor: c.onSurfaceVariant,
          onBadgeColor: c.surface,
        ),
        entry(
          id: 'export',
          icon: Icons.file_upload,
          label: 'Export',
          location: '/export',
          selected: under('/export'),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(bottom: AnvilSpacing.sm),
          child: Center(
            child: IconButton(
              key: toggleKey,
              tooltip: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
              icon: Icon(
                collapsed ? Icons.chevron_right : Icons.chevron_left,
                size: 20,
              ),
              onPressed: ref.read(sidebarCollapsedProvider.notifier).toggle,
            ),
          ),
        ),
      ],
    );

    return AnimatedContainer(
      duration: transition,
      curve: Curves.ease,
      width: width,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(color: c.surfaceContainerLowest),
      // A foreground border adds no padding, so the content keeps its width.
      foregroundDecoration: BoxDecoration(
        border: Border(right: BorderSide(color: c.outlineVariant)),
      ),
      // The content is laid out at the target width and clipped while the
      // width animates, so labels never squeeze mid-transition.
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: width,
        maxWidth: width,
        child: content,
      ),
    );
  }
}

class _SidebarDivider extends StatelessWidget {
  const _SidebarDivider();

  @override
  Widget build(BuildContext context) => Divider(
    height: AnvilSpacing.sm + 1,
    thickness: 1,
    color: context.colors.outlineVariant,
  );
}

/// One sidebar entry: icon, then (expanded) label, count and badge, or
/// (collapsed) the icon alone with a tooltip and a badge dot.
class _Entry extends StatelessWidget {
  const _Entry({
    required this.id,
    required this.icon,
    required this.label,
    required this.selected,
    required this.collapsed,
    required this.count,
    required this.countKey,
    required this.badge,
    required this.badgeColor,
    required this.onBadgeColor,
    required this.onTap,
  });

  final String id;
  final IconData icon;
  final String label;
  final bool selected;
  final bool collapsed;
  final int? count;
  final Key? countKey;
  final int badge;
  final Color badgeColor;
  final Color onBadgeColor;
  final VoidCallback onTap;

  static const _iconSize = 20.0;
  static const _dotSize = 8.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = selected ? c.primary : null;
    final iconWidget = Icon(
      icon,
      size: _iconSize,
      color: accent ?? c.onSurfaceVariant,
    );

    final Widget row;
    if (collapsed) {
      row = Center(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            iconWidget,
            if (badge > 0)
              Positioned(
                top: -2,
                right: -4,
                child: Container(
                  key: Sidebar.dotKey(id),
                  width: _dotSize,
                  height: _dotSize,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      );
    } else {
      row = Row(
        children: [
          SizedBox(width: AnvilSpacing.unit * 4.5, child: iconWidget),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium?.copyWith(
                color: accent ?? c.onSurface,
                fontWeight: selected ? FontWeight.w600 : null,
              ),
            ),
          ),
          if (count case final count?)
            Padding(
              padding: const EdgeInsets.only(left: AnvilSpacing.sm),
              child: Text(
                '$count',
                key: countKey,
                style: AnvilType.numeric(
                  size: 11,
                  weight: FontWeight.w500,
                  color: c.onSurfaceVariant,
                ),
              ),
            ),
          if (badge > 0)
            Padding(
              padding: const EdgeInsets.only(left: AnvilSpacing.sm),
              child: _Badge(
                key: Sidebar.badgeKey(id),
                value: badge,
                color: badgeColor,
                onColor: onBadgeColor,
              ),
            ),
        ],
      );
    }

    final button = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AnvilSpacing.xs),
      child: Material(
        color: selected ? c.surfaceContainerHigh : Colors.transparent,
        borderRadius: BorderRadius.circular(AnvilRadii.control),
        child: InkWell(
          borderRadius: BorderRadius.circular(AnvilRadii.control),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? AnvilSpacing.sm : AnvilSpacing.md,
              vertical: AnvilSpacing.sm,
            ),
            child: row,
          ),
        ),
      ),
    );

    return Semantics(
      selected: selected,
      child: collapsed ? Tooltip(message: label, child: button) : button,
    );
  }
}

/// 0.1.6's pill badge: at least 20 px, rounded, bold, capped at `99+`.
class _Badge extends StatelessWidget {
  const _Badge({
    super.key,
    required this.value,
    required this.color,
    required this.onColor,
  });

  static const _height = 20.0;

  final int value;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: _height, minHeight: _height),
    padding: const EdgeInsets.symmetric(horizontal: AnvilSpacing.xs),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(_height / 2),
    ),
    child: Text(
      value > Sidebar.badgeCap ? Sidebar.badgeOverflow : '$value',
      style: AnvilType.numeric(
        size: 11,
        weight: FontWeight.w700,
        color: onColor,
      ),
    ),
  );
}
