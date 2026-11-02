/// The class editor's Derived Stats tab (0.1.6 `DerivedStatsEditor.tsx`):
/// each project definition with its effective formula, the class
/// override switch and field, its value at the preview level or a cycle /
/// error marker, then the breakpoint table.
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../../editor/widgets/draft_text_field.dart';
import '../../editor/widgets/field_messages.dart';
import '../../editor/widgets/number_draft_field.dart' show formatDraftNumber;
import '../../editor/widgets/validation_banner.dart' show fieldIssue;
import '../../theme/anvil_colors.dart';
import '../../theme/anvil_metrics.dart';
import 'classes_editor_controller.dart';
import 'classes_growth_math.dart';
import 'classes_growth_providers.dart';

/// The Derived Stats tab of class [classId] over [draft].
///
/// An override is on while the draft has one for the definition: the
/// switch turns it on with the project formula to edit (0.1.6's
/// `toggleOverride`) and off by removing it. The override field shows the
/// save blocker on `derivedStatOverrides.<id>` (a syntax error, which
/// keeps Save disabled as in 0.1.6), else the validation issue on
/// `derivedStat:<name>` after a save. A runtime error is not a blocker;
/// it shows as the warning-coloured `error` marker with its message.
class ClassDerivedStatsTab extends ConsumerWidget {
  const ClassDerivedStatsTab({
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

  static const tabKey = ValueKey('class-derived-stats-tab');

  /// 0.1.6's override field placeholder.
  static const overrideHint = 'e.g. con * 10';

  /// 0.1.6's cycle marker tooltip.
  static const cycleTooltip =
      'Cyclic dependency detected — this formula depends on itself';

  static const previewLevelKey = ValueKey('class-derived-preview-level');
  static const addLevelKey = ValueKey('class-breakpoint-add-level');
  static const addLevelButtonKey = ValueKey('class-breakpoint-add');

  static Key cardKey(String id) => ValueKey('class-derived-$id');
  static Key switchKey(String id) => ValueKey('class-derived-switch-$id');
  static Key overrideKey(String id) => ValueKey('class-derived-override-$id');
  static Key resultKey(String id) => ValueKey('class-derived-result-$id');
  static Key breakpointKey(int level, String id) =>
      ValueKey('class-breakpoint-$level-$id');
  static Key removeLevelKey(int level) =>
      ValueKey('class-breakpoint-remove-$level');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defsAsync = ref.watch(classDerivedStatsProvider);
    final maxLevelAsync = ref.watch(classMaxLevelProvider);
    // Watched for the stat bindings the preview reads.
    ref.watch(classGrowthStatsProvider);
    final preview = ref.watch(derivedStatPreviewProvider(classId));
    final view = ref.watch(derivedPreviewLevelsProvider(classId));
    final defs = defsAsync.value;
    final maxLevel = maxLevelAsync.value;
    final muted = context.text.bodyMedium?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    if (defs == null || maxLevel == null) {
      if (defsAsync.hasError || maxLevelAsync.hasError) {
        return Text(
          'Failed to load derived stats.',
          style: context.text.bodyMedium?.copyWith(color: context.colors.error),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    if (defs.isEmpty) {
      return Text('No derived stats configured in this project.', style: muted);
    }
    final previewLevel = view.previewLevel.clamp(
      1,
      maxLevel < 1 ? 1 : maxLevel,
    );
    final levels = ref.read(derivedPreviewLevelsProvider(classId).notifier);

    return Column(
      key: tabKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AnvilSpacing.md,
          runSpacing: AnvilSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Derived Stats', style: context.text.titleSmall),
            Text(
              'Preview at level',
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            SizedBox(
              width: 80,
              child: _LevelField(
                key: previewLevelKey,
                initial: '$previewLevel',
                onChanged: (text) =>
                    levels.setPreviewLevel(int.tryParse(text) ?? 1, maxLevel),
              ),
            ),
          ],
        ),
        const SizedBox(height: AnvilSpacing.md),
        for (final def in defs)
          Padding(
            padding: const EdgeInsets.only(bottom: AnvilSpacing.sm),
            child: _DefinitionCard(
              key: cardKey(def.id),
              def: def,
              overrideFormula: draft.derivedStatOverrides[def.id],
              blocker: blockerText(blockers, 'derivedStatOverrides.${def.id}'),
              issue: fieldIssue(issues, 'derivedStat:${def.displayName}'),
              cyclic: preview.cyclicIds.contains(def.id),
              result: preview.result(previewLevel, def.id),
              previewLevel: previewLevel,
              controller: controller,
            ),
          ),
        const Divider(height: AnvilSpacing.xl),
        _BreakpointTable(
          defs: defs,
          levels: view.breakpointsFor(maxLevel),
          preview: preview,
          maxLevel: maxLevel,
          onAdd: (level) => levels.addBreakpoint(level, maxLevel),
          onRemove: (level) => levels.removeBreakpoint(level, maxLevel),
        ),
        const SizedBox(height: AnvilSpacing.lg),
        Text.rich(
          TextSpan(
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
            children: [
              TextSpan(
                text: 'resource_multiplier',
                style: ForgeType.code(
                  size: 12,
                  color: context.colors.onSurface,
                ),
              ),
              TextSpan(
                text:
                    ' (${formatDraftNumber(draft.resourceMultiplier)}) is '
                    'always available as a formula variable.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A digits-only level field holding its own text (0.1.6's local
/// `type="number"` inputs), reporting every change.
class _LevelField extends StatefulWidget {
  const _LevelField({
    super.key,
    required this.initial,
    required this.onChanged,
    this.label,
    this.onSubmitted,
  });

  final String initial;
  final String? label;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_LevelField> createState() => _LevelFieldState();
}

class _LevelFieldState extends State<_LevelField> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    keyboardType: TextInputType.number,
    textAlign: TextAlign.center,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(labelText: widget.label, isDense: true),
    onChanged: (text) {
      setState(() {});
      widget.onChanged(text);
    },
    onSubmitted: widget.onSubmitted,
  );
}

/// One definition: name and key, effective formula or override field,
/// the override switch, output type and rounding, and the result.
class _DefinitionCard extends StatelessWidget {
  const _DefinitionCard({
    super.key,
    required this.def,
    required this.overrideFormula,
    required this.blocker,
    required this.issue,
    required this.cyclic,
    required this.result,
    required this.previewLevel,
    required this.controller,
  });

  final DerivedStatDefinition def;
  final String? overrideFormula;
  final String? blocker;
  final ValidationIssue? issue;
  final bool cyclic;
  final FormulaEvalResult? result;
  final int previewLevel;
  final ClassEditorController controller;

  @override
  Widget build(BuildContext context) {
    final overridden = overrideFormula != null;
    final messages = fieldMessages(blocker, issue);
    final muted = context.colors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.all(AnvilSpacing.md - 4),
      decoration: BoxDecoration(
        border: Border.all(color: context.forge.rowDivider),
        borderRadius: BorderRadius.circular(AnvilRadii.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  def.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  def.exportKey,
                  overflow: TextOverflow.ellipsis,
                  style: ForgeType.code(size: 11.5, color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AnvilSpacing.sm),
          Expanded(
            child: overridden
                ? DraftTextField(
                    key: ClassDerivedStatsTab.overrideKey(def.id),
                    value: overrideFormula!,
                    onChanged: (v) => controller.setDerivedOverride(def.id, v),
                    hintText: ClassDerivedStatsTab.overrideHint,
                    style: ForgeType.code(size: 12),
                    blockerMessage: messages.error,
                    issueMessage: messages.helper,
                    issueSeverity: messages.warning
                        ? ValidationSeverity.warning
                        : ValidationSeverity.error,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        def.formula,
                        style: ForgeType.code(size: 12.5, color: muted),
                      ),
                      if (messages.error ?? messages.helper case final text?)
                        Text(
                          text,
                          style: context.text.bodySmall?.copyWith(
                            color: messages.warning
                                ? context.forge.warning
                                : context.colors.error,
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(width: AnvilSpacing.sm),
          Tooltip(
            message: overridden
                ? 'Using class override'
                : 'Using project default',
            child: Switch(
              key: ClassDerivedStatsTab.switchKey(def.id),
              value: overridden,
              onChanged: (on) => controller.setDerivedOverride(
                def.id,
                on ? def.formula : null,
                typing: false,
              ),
            ),
          ),
          const SizedBox(width: AnvilSpacing.sm),
          SizedBox(
            width: 64,
            child: Center(
              child: _Marker(label: def.outputType.value, color: muted),
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              def.roundingMode.value,
              textAlign: TextAlign.center,
              style: context.text.bodySmall?.copyWith(color: muted),
            ),
          ),
          SizedBox(
            width: 104,
            child: Align(
              alignment: Alignment.centerRight,
              child: Tooltip(
                message: 'Result (lvl $previewLevel)',
                child: KeyedSubtree(
                  key: ClassDerivedStatsTab.resultKey(def.id),
                  child: _ResultCell(
                    def: def,
                    cyclic: cyclic,
                    result: result,
                    errorLabel: 'error',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A result: the `cycle` marker, the `error` (or `err`) marker with its
/// message as the tooltip, the formatted value, or `—` when there is
/// none, as 0.1.6's result cells.
class _ResultCell extends StatelessWidget {
  const _ResultCell({
    required this.def,
    required this.cyclic,
    required this.result,
    required this.errorLabel,
  });

  final DerivedStatDefinition def;
  final bool cyclic;
  final FormulaEvalResult? result;
  final String errorLabel;

  @override
  Widget build(BuildContext context) {
    if (cyclic) {
      return Tooltip(
        message: ClassDerivedStatsTab.cycleTooltip,
        child: _Marker(label: 'cycle', color: context.colors.error),
      );
    }
    final r = result;
    if (r?.error case final error?) {
      return Tooltip(
        message: error,
        child: _Marker(label: errorLabel, color: context.forge.warning),
      );
    }
    if (r?.value case final value?) {
      return Text(
        formatDerivedValue(def, value),
        style: AnvilType.numeric(size: 13, color: context.colors.onSurface),
      );
    }
    return Text(
      '—',
      style: context.text.bodySmall?.copyWith(
        color: context.anvil.textDisabled,
      ),
    );
  }
}

/// A small outlined chip in [color] (0.1.6's `Chip variant="outlined"`).
class _Marker extends StatelessWidget {
  const _Marker({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
    decoration: BoxDecoration(
      border: Border.all(color: color),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(label, style: context.text.labelSmall?.copyWith(color: color)),
  );
}

/// 0.1.6's `BreakpointTable`: the definitions × the breakpoint levels,
/// with `Add level` and a remove button per level.
class _BreakpointTable extends StatefulWidget {
  const _BreakpointTable({
    required this.defs,
    required this.levels,
    required this.preview,
    required this.maxLevel,
    required this.onAdd,
    required this.onRemove,
  });

  final List<DerivedStatDefinition> defs;
  final List<int> levels;
  final DerivedStatPreview preview;
  final int maxLevel;
  final bool Function(int level) onAdd;
  final ValueChanged<int> onRemove;

  @override
  State<_BreakpointTable> createState() => _BreakpointTableState();
}

class _BreakpointTableState extends State<_BreakpointTable> {
  var _input = '';
  var _fieldGeneration = 0;

  void _add() {
    final level = int.tryParse(_input.trim());
    if (level == null || !widget.onAdd(level)) return;
    // 0.1.6 cleared the field after a level was added.
    setState(() {
      _input = '';
      _fieldGeneration++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final divider = context.forge.rowDivider;
    final header = context.text.labelSmall?.copyWith(
      fontWeight: FontWeight.w500,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Breakpoint Table', style: context.text.titleSmall),
            ),
            SizedBox(
              width: 110,
              child: _LevelField(
                key: ValueKey(
                  '${ClassDerivedStatsTab.addLevelKey.value}-$_fieldGeneration',
                ),
                label: 'Add level',
                initial: '',
                onChanged: (text) => setState(() => _input = text),
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: AnvilSpacing.sm),
            OutlinedButton(
              key: ClassDerivedStatsTab.addLevelButtonKey,
              onPressed: _input.trim().isEmpty ? null : _add,
              child: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: AnvilSpacing.md),
        if (widget.levels.isEmpty)
          Text(
            'No breakpoint levels configured.',
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: divider),
              borderRadius: BorderRadius.circular(AnvilRadii.control),
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                columnWidths: const {0: FixedColumnWidth(160)},
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                border: TableBorder(
                  horizontalInside: BorderSide(color: divider),
                ),
                children: [
                  TableRow(
                    children: [
                      _cell(Text('Stat', style: header)),
                      for (final level in widget.levels)
                        _cell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('Lvl $level', style: header),
                              IconButton(
                                key: ClassDerivedStatsTab.removeLevelKey(level),
                                tooltip: 'Remove level',
                                visualDensity: VisualDensity.compact,
                                iconSize: 12,
                                icon: const Icon(Icons.close),
                                onPressed: () => widget.onRemove(level),
                              ),
                            ],
                          ),
                          align: Alignment.centerRight,
                        ),
                    ],
                  ),
                  for (final def in widget.defs)
                    TableRow(
                      children: [
                        _cell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                def.displayName,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                def.exportKey,
                                overflow: TextOverflow.ellipsis,
                                style: ForgeType.code(
                                  size: 11.5,
                                  color: context.colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        for (final level in widget.levels)
                          _cell(
                            KeyedSubtree(
                              key: ClassDerivedStatsTab.breakpointKey(
                                level,
                                def.id,
                              ),
                              child: _ResultCell(
                                def: def,
                                cyclic: widget.preview.cyclicIds.contains(
                                  def.id,
                                ),
                                result: widget.preview.result(level, def.id),
                                errorLabel: 'err',
                              ),
                            ),
                            align: Alignment.centerRight,
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _cell(Widget child, {Alignment align = Alignment.centerLeft}) =>
      Container(
        constraints: const BoxConstraints(minWidth: 90),
        padding: const EdgeInsets.symmetric(
          horizontal: AnvilSpacing.sm,
          vertical: AnvilSpacing.xs,
        ),
        alignment: align,
        child: child,
      );
}
