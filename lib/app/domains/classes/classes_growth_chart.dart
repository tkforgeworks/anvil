/// The stat growth chart (0.1.6 `StatGrowthEditor.tsx`'s Recharts
/// `LineChart`, drawn with `fl_chart` as design §13.6 decided).
library;

import 'dart:math' as math;

import 'package:anvil_core/anvil_core.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:forge_ui/forge_ui.dart';

import '../../editor/widgets/number_draft_field.dart' show formatDraftNumber;
import '../../theme/anvil_colors.dart';
import '../../theme/anvil_metrics.dart';

/// One line per stat over levels 1 to [maxLevel], in the theme's chart
/// series colours (`context.anvil.chartSeries`, cycled by stat index as
/// 0.1.6 cycled `STAT_COLORS`), straight segments without dots, 2 px wide,
/// a dashed grid and `Level` under the x axis. An empty cell plots as 0,
/// as 0.1.6's `buildChartData` did. Tapping a stat in the legend below
/// hides or shows its line (0.1.6's legend click); hiding is view state
/// of this widget.
class StatGrowthChart extends StatefulWidget {
  const StatGrowthChart({
    super.key,
    required this.stats,
    required this.maxLevel,
    required this.valueAt,
  });

  static const chartKey = ValueKey('class-growth-chart');
  static const height = 280.0;

  /// The legend entry of [statId].
  static Key legendKey(String statId) =>
      ValueKey('class-growth-legend-$statId');

  final List<MetaStat> stats;
  final int maxLevel;

  /// The value the grid shows for a stat at a level, null when empty.
  final double? Function(String statId, int level) valueAt;

  @override
  State<StatGrowthChart> createState() => _StatGrowthChartState();
}

class _StatGrowthChartState extends State<StatGrowthChart> {
  final _hidden = <String>{};

  void _toggle(String statId) => setState(() {
    if (!_hidden.remove(statId)) _hidden.add(statId);
  });

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    final maxLevel = widget.maxLevel;
    final gridLine = FlLine(
      color: context.forge.rowDivider,
      strokeWidth: 1,
      dashArray: const [3, 3],
    );
    final axisStyle = AnvilType.numeric(
      size: 11,
      color: context.colors.onSurfaceVariant,
    );

    final bars = <LineChartBarData>[];
    var minY = 0.0;
    var maxY = 0.0;
    for (final (i, stat) in stats.indexed) {
      final shown = !_hidden.contains(stat.id);
      final spots = <FlSpot>[];
      for (var level = 1; level <= maxLevel; level++) {
        final y = widget.valueAt(stat.id, level) ?? 0;
        if (!y.isFinite) {
          spots.add(FlSpot.nullSpot);
          continue;
        }
        spots.add(FlSpot(level.toDouble(), y));
        if (shown) {
          minY = math.min(minY, y);
          maxY = math.max(maxY, y);
        }
      }
      bars.add(
        LineChartBarData(
          spots: spots,
          show: shown,
          color: context.anvil.seriesColor(i),
          barWidth: 2,
          isCurved: false,
          dotData: const FlDotData(show: false),
        ),
      );
    }
    if (maxY <= minY) maxY = minY + 1;

    final names = {for (final (i, stat) in stats.indexed) i: stat.displayName};
    final data = LineChartData(
      minX: 1,
      maxX: math.max(2, maxLevel).toDouble(),
      minY: minY,
      maxY: maxY,
      lineBarsData: bars,
      gridData: FlGridData(
        getDrawingHorizontalLine: (_) => gridLine,
        getDrawingVerticalLine: (_) => gridLine,
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          left: BorderSide(color: context.forge.rowDivider),
          bottom: BorderSide(color: context.forge.rowDivider),
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) => SideTitleWidget(
              meta: meta,
              child: Text(meta.formattedValue, style: axisStyle),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          axisNameWidget: Text('Level', style: axisStyle),
          axisNameSize: 16,
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            interval: math.max(1, (maxLevel / 10).ceil()).toDouble(),
            getTitlesWidget: (value, meta) => SideTitleWidget(
              meta: meta,
              child: Text(formatDraftNumber(value), style: axisStyle),
            ),
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => context.colors.surfaceContainerHighest,
          getTooltipItems: (spots) => [
            for (final (i, spot) in spots.indexed)
              LineTooltipItem(
                '${i == 0 ? 'Level ${formatDraftNumber(spot.x)}\n' : ''}'
                '${names[spot.barIndex] ?? ''}: ${formatDraftNumber(spot.y)}',
                context.text.bodySmall!.copyWith(
                  color: context.anvil.seriesColor(spot.barIndex),
                ),
              ),
          ],
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(AnvilSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: context.forge.rowDivider),
        borderRadius: BorderRadius.circular(AnvilRadii.control),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: StatGrowthChart.height,
            child: LineChart(
              data,
              key: StatGrowthChart.chartKey,
              duration: Duration.zero,
            ),
          ),
          const SizedBox(height: AnvilSpacing.sm),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AnvilSpacing.md,
            runSpacing: AnvilSpacing.xs,
            children: [
              for (final (i, stat) in stats.indexed)
                _LegendEntry(
                  key: StatGrowthChart.legendKey(stat.id),
                  label: stat.displayName,
                  color: context.anvil.seriesColor(i),
                  hidden: _hidden.contains(stat.id),
                  onTap: () => _toggle(stat.id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({
    super.key,
    required this.label,
    required this.color,
    required this.hidden,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: hidden ? 'Show $label' : 'Hide $label',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AnvilRadii.control),
      child: Opacity(
        // 0.1.6's legend formatter: `opacity: 0.4` while hidden.
        opacity: hidden ? 0.4 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AnvilSpacing.xs,
            vertical: 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 14, height: 3, color: color),
              const SizedBox(width: AnvilSpacing.xs),
              Text(label, style: context.text.bodySmall),
            ],
          ),
        ),
      ),
    ),
  );
}
