/// The class editor's Stat Growth tab (0.1.6 `StatGrowthEditor.tsx`): the
/// formula fields of the stats in formula mode, the Fill column and
/// Interpolate helpers, the levels × stats grid with a manual / formula
/// switch per stat, and the chart.
library;

import 'dart:async';

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../../editor/widgets/draft_picker.dart';
import '../../editor/widgets/draft_text_field.dart';
import '../../editor/widgets/field_messages.dart';
import '../../editor/widgets/number_draft_field.dart' show formatDraftNumber;
import '../../editor/widgets/validation_banner.dart' show fieldIssue;
import '../../theme/anvil_colors.dart';
import '../../theme/anvil_metrics.dart';
import 'classes_editor_controller.dart';
import 'classes_growth_chart.dart';
import 'classes_growth_math.dart';
import 'classes_growth_providers.dart';

/// The Stat Growth tab of class [classId] over [draft].
///
/// A formula stat's cells are read-only and show the values its formula
/// computes ([statGrowthPreviewProvider], 300 ms after the last formula
/// edit); its formula field shows the save blocker on
/// `statGrowthFormulas.<statId>`, else the preview's first error, else
/// the validation issue on `statGrowthFormula:<stat name>` after a save.
class ClassStatGrowthTab extends ConsumerWidget {
  const ClassStatGrowthTab({
    super.key,
    required this.classId,
    required this.draft,
    required this.blockers,
    required this.issues,
    required this.controller,
  });

  final String classId;
  final ClassDraft draft;
  final List<SaveBlocker> blockers;
  final List<ValidationIssue> issues;
  final ClassEditorController controller;

  static const tabKey = ValueKey('class-stat-growth-tab');

  /// 0.1.6's formula field placeholder.
  static const formulaHint = 'e.g. min(level, 30) + max(level - 30, 0) * 2';

  static Key formulaKey(String statId) =>
      ValueKey('class-growth-formula-$statId');
  static Key formulaManualKey(String statId) =>
      ValueKey('class-growth-formula-manual-$statId');
  static Key modeKey(String statId) => ValueKey('class-growth-mode-$statId');
  static Key cellKey(String statId, int level) =>
      ValueKey('class-growth-cell-$statId-$level');

  static const fillStatKey = ValueKey('class-growth-fill-stat');
  static const fillValueKey = ValueKey('class-growth-fill-value');
  static const fillApplyKey = ValueKey('class-growth-fill-apply');
  static const interpStatKey = ValueKey('class-growth-interp-stat');
  static const interpFromLevelKey = ValueKey('class-growth-interp-from-level');
  static const interpFromValueKey = ValueKey('class-growth-interp-from-value');
  static const interpToLevelKey = ValueKey('class-growth-interp-to-level');
  static const interpToValueKey = ValueKey('class-growth-interp-to-value');
  static const interpApplyKey = ValueKey('class-growth-interp-apply');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(classGrowthStatsProvider);
    final maxLevelAsync = ref.watch(classMaxLevelProvider);
    final previews = ref.watch(statGrowthPreviewProvider(classId));
    final stats = statsAsync.value;
    final maxLevel = maxLevelAsync.value;
    final muted = context.text.bodyMedium?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    if (stats == null || maxLevel == null) {
      if (statsAsync.hasError || maxLevelAsync.hasError) {
        return Text(
          'Failed to load stat growth data.',
          style: context.text.bodyMedium?.copyWith(color: context.colors.error),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    if (stats.isEmpty) {
      return Text('No stats configured in this project.', style: muted);
    }

    double? valueAt(String statId, int level) =>
        displayedGrowth(draft, previews, statId, level);
    final formulaStats = [
      for (final s in stats)
        if (draft.statGrowthFormulas.containsKey(s.id)) s,
    ];
    final manualStats = [
      for (final s in stats)
        if (!draft.statGrowthFormulas.containsKey(s.id)) s,
    ];

    Future<void> toManual(String statId) async {
      final keep = await showSwitchToManualDialog(context);
      if (keep == null) return;
      controller.switchToManual(
        statId,
        keep: keep,
        onScreen: previews[statId]?.values,
      );
    }

    return Column(
      key: tabKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Primary Stat Growth — levels 1–$maxLevel',
          style: context.text.titleSmall,
        ),
        const SizedBox(height: AnvilSpacing.md),
        if (formulaStats.isNotEmpty) ...[
          _FormulaPanel(
            stats: formulaStats,
            draft: draft,
            previews: previews,
            blockers: blockers,
            issues: issues,
            controller: controller,
            onManual: (id) => unawaited(toManual(id)),
          ),
          const SizedBox(height: AnvilSpacing.md),
        ],
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FillColumnHelper(
                manualStats: manualStats,
                onApply: controller.fillColumn,
              ),
              const Divider(height: AnvilSpacing.lg),
              _InterpolateHelper(
                manualStats: manualStats,
                maxLevel: maxLevel,
                onApply: controller.interpolate,
              ),
            ],
          ),
        ),
        const SizedBox(height: AnvilSpacing.md),
        _GrowthGrid(
          stats: stats,
          maxLevel: maxLevel,
          formulaStatIds: draft.statGrowthFormulas.keys.toSet(),
          valueAt: valueAt,
          onCellChanged: controller.setStatGrowthValue,
          onToFormula: controller.switchToFormula,
          onToManual: (id) => unawaited(toManual(id)),
        ),
        const SizedBox(height: AnvilSpacing.md),
        StatGrowthChart(stats: stats, maxLevel: maxLevel, valueAt: valueAt),
      ],
    );
  }
}

/// 0.1.6's `Switch to Manual Mode` dialog: true for Keep Values, false for
/// Clear Values, null for Cancel (or a dismissal).
Future<bool?> showSwitchToManualDialog(BuildContext context) =>
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Switch to Manual Mode'),
        content: const Text(
          'How would you like to handle the computed values for this stat?',
        ),
        actions: [
          TextButton(
            key: const ValueKey('class-growth-manual-cancel'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const ValueKey('class-growth-manual-clear'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Clear Values'),
          ),
          FilledButton(
            key: const ValueKey('class-growth-manual-keep'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Keep Values'),
          ),
        ],
      ),
    );

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AnvilSpacing.md - 4),
    decoration: BoxDecoration(
      border: Border.all(color: context.forge.rowDivider),
      borderRadius: BorderRadius.circular(AnvilRadii.control),
    ),
    child: child,
  );
}

/// The formula field of every stat in formula mode, with its Manual
/// button (0.1.6's "Formula-driven stats" panel).
class _FormulaPanel extends StatelessWidget {
  const _FormulaPanel({
    required this.stats,
    required this.draft,
    required this.previews,
    required this.blockers,
    required this.issues,
    required this.controller,
    required this.onManual,
  });

  final List<MetaStat> stats;
  final ClassDraft draft;
  final Map<String, GrowthPreview> previews;
  final List<SaveBlocker> blockers;
  final List<ValidationIssue> issues;
  final ClassEditorController controller;
  final ValueChanged<String> onManual;

  @override
  Widget build(BuildContext context) {
    final caption = context.text.bodySmall?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    final code = ForgeType.code(size: 12, color: context.colors.onSurface);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              style: caption,
              children: [
                const TextSpan(text: 'Formula-driven stats — use '),
                TextSpan(text: 'level', style: code),
                const TextSpan(text: ' and '),
                TextSpan(text: 'max_level', style: code),
                const TextSpan(text: ' as variables. Functions: '),
                TextSpan(text: 'min()', style: code),
                const TextSpan(text: ', '),
                TextSpan(text: 'max()', style: code),
                const TextSpan(text: ', '),
                TextSpan(text: 'floor()', style: code),
                const TextSpan(text: ', '),
                TextSpan(text: 'ceil()', style: code),
              ],
            ),
          ),
          const SizedBox(height: AnvilSpacing.sm),
          for (final stat in stats)
            Padding(
              padding: const EdgeInsets.only(bottom: AnvilSpacing.sm),
              child: _formulaRow(context, stat),
            ),
        ],
      ),
    );
  }

  Widget _formulaRow(BuildContext context, MetaStat stat) {
    final messages = fieldMessages(
      blockerText(blockers, 'statGrowthFormulas.${stat.id}') ??
          previews[stat.id]?.error,
      fieldIssue(issues, 'statGrowthFormula:${stat.displayName}'),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Padding(
            padding: const EdgeInsets.only(top: AnvilSpacing.sm),
            child: Text(
              stat.displayName,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: AnvilSpacing.sm),
        Expanded(
          child: DraftTextField(
            key: ClassStatGrowthTab.formulaKey(stat.id),
            value: draft.statGrowthFormulas[stat.id] ?? '',
            onChanged: (v) => controller.setStatGrowthFormula(stat.id, v),
            hintText: ClassStatGrowthTab.formulaHint,
            style: ForgeType.code(size: 13.6),
            blockerMessage: messages.error,
            issueMessage: messages.helper,
            issueSeverity: messages.warning
                ? ValidationSeverity.warning
                : ValidationSeverity.error,
          ),
        ),
        const SizedBox(width: AnvilSpacing.sm),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: TextButton(
            key: ClassStatGrowthTab.formulaManualKey(stat.id),
            onPressed: () => onManual(stat.id),
            child: const Text('Manual'),
          ),
        ),
      ],
    );
  }
}

/// A number typed into a helper field: null unless it parses and is
/// finite (0.1.6 `parseFloat`, which `type="number"` fed only numbers).
double? _number(String text) {
  final v = double.tryParse(text.trim());
  return v != null && v.isFinite ? v : null;
}

final _numberChars = FilteringTextInputFormatter.allow(RegExp(r'[0-9eE+\-.]'));

/// The stat picker of a helper: the manual stats, the first one until the
/// user picks another (0.1.6's `useState(manualStats[0]?.id)`), falling
/// back to the first when the picked one leaves manual mode.
class _StatPicker extends StatelessWidget {
  const _StatPicker({
    super.key,
    required this.stats,
    required this.selected,
    required this.onChanged,
  });

  final List<MetaStat> stats;
  final String? selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 160,
    child: DraftPicker<String?>(
      label: 'Stat',
      dense: true,
      value: selected,
      options: [for (final s in stats) (value: s.id, label: s.displayName)],
      onChanged: stats.isEmpty
          ? null
          : (v) {
              if (v != null) onChanged(v);
            },
    ),
  );
}

String? _effectiveStat(List<MetaStat> stats, String? picked) {
  if (stats.any((s) => s.id == picked)) return picked;
  return stats.isEmpty ? null : stats.first.id;
}

Widget _helperLabel(BuildContext context, String text) => SizedBox(
  width: 90,
  child: Text(
    text,
    style: context.text.bodySmall?.copyWith(
      color: context.colors.onSurfaceVariant,
    ),
  ),
);

Widget _helperField({
  required Key key,
  required String label,
  required TextEditingController controller,
  required double width,
  bool integer = false,
  ValueChanged<String>? onChanged,
}) => SizedBox(
  width: width,
  child: TextField(
    key: key,
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(
      signed: true,
      decimal: true,
    ),
    inputFormatters: [
      integer
          ? FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]'))
          : _numberChars,
    ],
    decoration: InputDecoration(labelText: label, isDense: true),
    onChanged: onChanged,
  ),
);

/// 0.1.6's `FillColumnHelper`.
class _FillColumnHelper extends StatefulWidget {
  const _FillColumnHelper({required this.manualStats, required this.onApply});

  final List<MetaStat> manualStats;
  final void Function(String statId, double value) onApply;

  @override
  State<_FillColumnHelper> createState() => _FillColumnHelperState();
}

class _FillColumnHelperState extends State<_FillColumnHelper> {
  String? _picked;
  final _value = TextEditingController();

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statId = _effectiveStat(widget.manualStats, _picked);
    final value = _number(_value.text);
    return Wrap(
      spacing: AnvilSpacing.sm,
      runSpacing: AnvilSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _helperLabel(context, 'Fill column:'),
        _StatPicker(
          key: ClassStatGrowthTab.fillStatKey,
          stats: widget.manualStats,
          selected: statId,
          onChanged: (v) => setState(() => _picked = v),
        ),
        _helperField(
          key: ClassStatGrowthTab.fillValueKey,
          label: 'Value',
          controller: _value,
          width: 100,
          onChanged: (_) => setState(() {}),
        ),
        OutlinedButton(
          key: ClassStatGrowthTab.fillApplyKey,
          onPressed: value == null || statId == null
              ? null
              : () {
                  widget.onApply(statId, value);
                  setState(_value.clear);
                },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

/// 0.1.6's `InterpolateHelper`; To lvl starts at the max level.
class _InterpolateHelper extends StatefulWidget {
  const _InterpolateHelper({
    required this.manualStats,
    required this.maxLevel,
    required this.onApply,
  });

  final List<MetaStat> manualStats;
  final int maxLevel;
  final void Function(
    String statId,
    int fromLevel,
    double fromValue,
    int toLevel,
    double toValue,
  )
  onApply;

  @override
  State<_InterpolateHelper> createState() => _InterpolateHelperState();
}

class _InterpolateHelperState extends State<_InterpolateHelper> {
  String? _picked;
  final _fromLevel = TextEditingController(text: '1');
  final _fromValue = TextEditingController();
  late final _toLevel = TextEditingController(text: '${widget.maxLevel}');
  final _toValue = TextEditingController();

  @override
  void dispose() {
    for (final c in [_fromLevel, _fromValue, _toLevel, _toValue]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statId = _effectiveStat(widget.manualStats, _picked);
    final fromLevel = int.tryParse(_fromLevel.text.trim());
    final toLevel = int.tryParse(_toLevel.text.trim());
    final fromValue = _number(_fromValue.text);
    final toValue = _number(_toValue.text);
    final canApply =
        statId != null &&
        fromValue != null &&
        toValue != null &&
        fromLevel != null &&
        toLevel != null &&
        fromLevel < toLevel;
    void changed(String _) => setState(() {});
    return Wrap(
      spacing: AnvilSpacing.sm,
      runSpacing: AnvilSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _helperLabel(context, 'Interpolate:'),
        _StatPicker(
          key: ClassStatGrowthTab.interpStatKey,
          stats: widget.manualStats,
          selected: statId,
          onChanged: (v) => setState(() => _picked = v),
        ),
        _helperField(
          key: ClassStatGrowthTab.interpFromLevelKey,
          label: 'From lvl',
          controller: _fromLevel,
          width: 80,
          integer: true,
          onChanged: changed,
        ),
        _helperField(
          key: ClassStatGrowthTab.interpFromValueKey,
          label: 'From val',
          controller: _fromValue,
          width: 90,
          onChanged: changed,
        ),
        Text(
          '→',
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        _helperField(
          key: ClassStatGrowthTab.interpToLevelKey,
          label: 'To lvl',
          controller: _toLevel,
          width: 80,
          integer: true,
          onChanged: changed,
        ),
        _helperField(
          key: ClassStatGrowthTab.interpToValueKey,
          label: 'To val',
          controller: _toValue,
          width: 90,
          onChanged: changed,
        ),
        OutlinedButton(
          key: ClassStatGrowthTab.interpApplyKey,
          onPressed: canApply
              ? () => widget.onApply(
                  statId,
                  fromLevel,
                  fromValue,
                  toLevel,
                  toValue,
                )
              : null,
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

/// The levels × stats grid: one row per level from 1 to max level, one
/// column per stat headed by its export key in its chart colour and its
/// `M` / `F` switch, as 0.1.6 laid it out. At most [maxHeight] high, the
/// rows scroll under the header; wider than the tab, it scrolls sideways.
class _GrowthGrid extends StatelessWidget {
  const _GrowthGrid({
    required this.stats,
    required this.maxLevel,
    required this.formulaStatIds,
    required this.valueAt,
    required this.onCellChanged,
    required this.onToFormula,
    required this.onToManual,
  });

  static const levelWidth = 56.0;
  static const statWidth = 88.0;
  static const rowHeight = 32.0;
  static const headerHeight = 52.0;

  /// 0.1.6's `maxHeight: 420`.
  static const maxHeight = 420.0;

  final List<MetaStat> stats;
  final int maxLevel;
  final Set<String> formulaStatIds;
  final double? Function(String statId, int level) valueAt;
  final void Function(String statId, int level, double? value) onCellChanged;
  final ValueChanged<String> onToFormula;
  final ValueChanged<String> onToManual;

  @override
  Widget build(BuildContext context) {
    final divider = context.forge.rowDivider;
    final contentWidth = levelWidth + stats.length * statWidth;
    final bodyHeight = maxLevel * rowHeight;
    final height = (headerHeight + bodyHeight + 2).clamp(0.0, maxHeight);
    final levelStyle = AnvilType.numeric(
      size: 11,
      color: context.colors.onSurfaceVariant,
    );
    return Container(
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: divider),
        borderRadius: BorderRadius.circular(AnvilRadii.control),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = contentWidth > constraints.maxWidth
              ? contentWidth
              : constraints.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: headerHeight,
                    decoration: BoxDecoration(
                      color: context.colors.surfaceContainerLowest,
                      border: Border(bottom: BorderSide(color: divider)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: levelWidth,
                          child: Center(
                            child: Text(
                              'Lvl',
                              style: context.text.labelSmall?.copyWith(
                                color: context.colors.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        for (final (i, stat) in stats.indexed)
                          _StatHeader(
                            stat: stat,
                            color: context.anvil.seriesColor(i),
                            isFormula: formulaStatIds.contains(stat.id),
                            onTap: () => formulaStatIds.contains(stat.id)
                                ? onToManual(stat.id)
                                : onToFormula(stat.id),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: maxLevel,
                      itemExtent: rowHeight,
                      itemBuilder: (context, i) {
                        final level = i + 1;
                        return Container(
                          color: level.isEven
                              ? context.colors.onSurface.withValues(alpha: 0.03)
                              : null,
                          child: Row(
                            children: [
                              SizedBox(
                                width: levelWidth,
                                child: Center(
                                  child: Text('$level', style: levelStyle),
                                ),
                              ),
                              for (final stat in stats)
                                SizedBox(
                                  width: statWidth,
                                  child: formulaStatIds.contains(stat.id)
                                      ? _ComputedCell(
                                          key: ClassStatGrowthTab.cellKey(
                                            stat.id,
                                            level,
                                          ),
                                          value: valueAt(stat.id, level),
                                        )
                                      : _GrowthCell(
                                          key: ClassStatGrowthTab.cellKey(
                                            stat.id,
                                            level,
                                          ),
                                          value: valueAt(stat.id, level),
                                          onChanged: (v) =>
                                              onCellChanged(stat.id, level, v),
                                        ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatHeader extends StatelessWidget {
  const _StatHeader({
    required this.stat,
    required this.color,
    required this.isFormula,
    required this.onTap,
  });

  final MetaStat stat;
  final Color color;
  final bool isFormula;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final info = context.forge.info;
    return SizedBox(
      width: _GrowthGrid.statWidth,
      child: Tooltip(
        message: stat.displayName,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              stat.exportKey.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Tooltip(
              message: isFormula
                  ? 'Formula mode — switch to manual'
                  : 'Manual mode — switch to formula',
              child: InkWell(
                key: ClassStatGrowthTab.modeKey(stat.id),
                onTap: onTap,
                borderRadius: BorderRadius.circular(9),
                child: Container(
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isFormula ? info : null,
                    border: Border.all(
                      color: isFormula ? info : context.colors.outline,
                    ),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    isFormula ? 'F' : 'M',
                    style: context.text.labelSmall?.copyWith(
                      fontSize: 9,
                      color: isFormula
                          ? context.forge.onInfo
                          : context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A formula stat's cell: the computed value, read-only.
class _ComputedCell extends StatelessWidget {
  const _ComputedCell({super.key, required this.value});

  final double? value;

  @override
  Widget build(BuildContext context) => Container(
    color: context.colors.primary.withValues(alpha: 0.06),
    alignment: Alignment.centerRight,
    padding: const EdgeInsets.symmetric(horizontal: AnvilSpacing.sm),
    child: Text(
      formatDraftNumber(value),
      style: AnvilType.numeric(
        size: 12,
        color: context.colors.onSurfaceVariant,
      ),
    ),
  );
}

/// A manual stat's cell, bound to one `statGrowth` entry: typing a number
/// sets it, emptying the cell removes it, text that is not a number leaves
/// the draft alone and shows in the error colour. A change from the draft
/// (undo, fill, interpolate, discard) rewrites the text only when it no
/// longer means [value], as `NumberDraftField` does.
class _GrowthCell extends StatefulWidget {
  const _GrowthCell({super.key, required this.value, required this.onChanged});

  final double? value;
  final ValueChanged<double?> onChanged;

  @override
  State<_GrowthCell> createState() => _GrowthCellState();
}

class _GrowthCellState extends State<_GrowthCell> {
  late final _controller = TextEditingController(
    text: formatDraftNumber(widget.value),
  );
  var _invalid = false;

  ({bool valid, double? value}) _read(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return (valid: true, value: null);
    final parsed = double.tryParse(trimmed);
    if (parsed == null || !parsed.isFinite) return (valid: false, value: null);
    return (valid: true, value: parsed);
  }

  @override
  void didUpdateWidget(_GrowthCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == oldWidget.value) return;
    final reading = _read(_controller.text);
    if (reading.valid && reading.value == widget.value) return;
    final text = formatDraftNumber(widget.value);
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _invalid = false;
  }

  void _changed(String text) {
    final reading = _read(text);
    setState(() => _invalid = !reading.valid);
    if (reading.valid && reading.value != widget.value) {
      widget.onChanged(reading.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AnvilSpacing.xs),
    child: Center(
      child: TextField(
        controller: _controller,
        textAlign: TextAlign.right,
        keyboardType: const TextInputType.numberWithOptions(
          signed: true,
          decimal: true,
        ),
        inputFormatters: [_numberChars],
        style: AnvilType.numeric(
          size: 12,
          color: _invalid ? context.colors.error : context.colors.onSurface,
        ),
        decoration: const InputDecoration.collapsed(hintText: null),
        onChanged: _changed,
      ),
    ),
  );
}
