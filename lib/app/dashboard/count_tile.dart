/// The dashboard's six count tiles (0.1.6 `DOMAIN_TILES`).
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:forge_ui/forge_ui.dart';

import '../shell/shell_domain.dart';
import '../theme/anvil_metrics.dart';
import 'dashboard_card.dart';

/// `+2 this wk`, `-1 this wk`, or `stable` for no change.
String formatWeeklyDelta(int delta) => delta > 0
    ? '+$delta this wk'
    : delta < 0
    ? '$delta this wk'
    : 'stable';

/// One domain: the uppercase label beside its icon, the active count in the
/// primary colour, and the weekly delta. A tap opens the domain's list.
class CountTile extends StatelessWidget {
  const CountTile({
    super.key,
    required this.domain,
    required this.count,
    required this.delta,
    required this.onTap,
  });

  final ShellDomain domain;

  /// Null while the counts load or after they failed.
  final int? count;
  final int delta;
  final VoidCallback onTap;

  /// The tile of [domain].
  static ValueKey<String> keyOf(ShellDomain domain) =>
      ValueKey('dash-tile-${domain.path}');

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DashboardCard(
      key: keyOf(domain),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(domain.icon, size: 16, color: c.primary),
              const SizedBox(width: AnvilSpacing.sm - 2),
              Flexible(
                child: Text(
                  domain.label.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AnvilSpacing.xs),
          Text(
            count?.toString() ?? '—',
            style: AnvilType.numeric(
              size: 24,
              weight: FontWeight.w700,
              color: c.primary,
            ),
          ),
          Text(
            formatWeeklyDelta(delta),
            style: context.text.labelSmall?.copyWith(color: c.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// The six tiles in 0.1.6's order, as many to a row as fit at a minimum of
/// [minTileWidth] (0.1.6's `repeat(auto-fit, minmax(140px, 1fr))`), wrapping
/// onto further rows instead of squeezing.
class CountTiles extends StatelessWidget {
  const CountTiles({
    super.key,
    required this.counts,
    required this.deltas,
    required this.onOpen,
  });

  static const minTileWidth = 140.0;
  static const gap = AnvilSpacing.sm + 2;

  final RecordCounts? counts;
  final RecordCounts? deltas;
  final void Function(ShellDomain domain) onOpen;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      const domains = ShellDomain.values;
      final perRow = ((width + gap) / (minTileWidth + gap)).floor().clamp(
        1,
        domains.length,
      );
      final tileWidth = (width - gap * (perRow - 1)) / perRow;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final domain in domains)
            SizedBox(
              width: tileWidth,
              child: CountTile(
                domain: domain,
                count: switch (counts) {
                  final c? => domain.countIn(c),
                  null => null,
                },
                delta: switch (deltas) {
                  final d? => domain.countIn(d),
                  null => 0,
                },
                onTap: () => onOpen(domain),
              ),
            ),
        ],
      );
    },
  );
}
