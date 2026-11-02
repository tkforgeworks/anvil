/// The Details sections of the NPC editor: class assignments (0.1.6
/// `ClassAssignmentPanel.tsx`), the stat block (`NpcStatBlockPanel.tsx`),
/// ability assignments (`AbilityAssignmentPanel.tsx`) and the loot table
/// (`LootTableAssignmentPanel.tsx`), all bound to the draft.
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../../editor/editor_state.dart';
import '../../editor/widgets/draft_picker.dart';
import '../../editor/widgets/draft_text_field.dart';
import '../../editor/widgets/field_messages.dart';
import '../../editor/widgets/number_draft_field.dart';
import '../../editor/widgets/validation_banner.dart';
import '../../shell/open_editor.dart';
import '../../shell/shell_domain.dart';
import '../../theme/anvil_colors.dart';
import '../../theme/anvil_metrics.dart';
import 'npcs_editor_controller.dart';
import 'npcs_providers.dart';

/// 0.1.6's `maxWidth: 400` on the add pickers and the loot table picker.
const _pickerMaxWidth = 400.0;

/// The width of a class assignment's level field.
const _levelWidth = 110.0;

/// The width of a stat override field.
const _overrideWidth = 120.0;

/// One titled section of the Details tab (0.1.6's `subtitle1` heading and
/// `body2` explanation).
class NpcSection extends StatelessWidget {
  const NpcSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AnvilSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: context.text.titleMedium),
        const SizedBox(height: AnvilSpacing.xs),
        Text(
          subtitle,
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AnvilSpacing.md),
        child,
      ],
    ),
  );
}

/// The validation issues of [field] (`classAssignments`,
/// `abilityAssignments`), one line each.
class _FieldIssues extends StatelessWidget {
  const _FieldIssues({required this.issues, required this.field});

  final List<ValidationIssue> issues;
  final String field;

  @override
  Widget build(BuildContext context) {
    final matching = [
      for (final i in issues)
        if (i.field == field) i,
    ];
    if (matching.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AnvilSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final issue in matching)
            Text(
              issue.message,
              style: context.text.bodySmall?.copyWith(
                color: issue.severity == ValidationSeverity.error
                    ? context.colors.error
                    : context.forge.warning,
              ),
            ),
        ],
      ),
    );
  }
}

/// A warning line, as 0.1.6's MUI `Alert severity="warning"`.
class NpcNotice extends StatelessWidget {
  const NpcNotice({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final forge = context.forge;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AnvilSpacing.md),
      padding: const EdgeInsets.all(AnvilSpacing.md),
      decoration: BoxDecoration(
        color: forge.warningContainer,
        borderRadius: BorderRadius.circular(ForgeRadii.card),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, size: 20, color: forge.warning),
          const SizedBox(width: AnvilSpacing.md),
          Expanded(child: Text(message, style: context.text.bodyMedium)),
        ],
      ),
    );
  }
}

/// 0.1.6's outlined `Deleted` chip with its tooltip.
class _DeletedChip extends StatelessWidget {
  const _DeletedChip({super.key, required this.tooltip});

  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Chip(
      avatar: Icon(Icons.warning, size: 16, color: context.forge.warning),
      label: Text(
        'Deleted',
        style: context.text.labelSmall?.copyWith(color: context.forge.warning),
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: BorderSide(color: context.forge.warning),
      backgroundColor: Colors.transparent,
    ),
  );
}

/// A record name that opens its editor (0.1.6 navigated to it), plain text
/// when the record is unknown.
class _RecordLink extends ConsumerWidget {
  const _RecordLink({
    super.key,
    required this.label,
    required this.domain,
    required this.id,
    required this.known,
    required this.deleted,
  });

  final String label;
  final ShellDomain domain;
  final String id;
  final bool known;
  final bool deleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = context.text.bodyMedium?.copyWith(
      color: deleted ? context.colors.onSurfaceVariant : null,
    );
    if (!known) return Text(label, style: style);
    return InkWell(
      borderRadius: BorderRadius.circular(AnvilRadii.control),
      onTap: () => openEditor(context, ref, domain, id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AnvilSpacing.xs),
        child: Text(
          label,
          style: style?.copyWith(decoration: TextDecoration.underline),
        ),
      ),
    );
  }
}

/// The up, down and remove buttons of an assignment row.
class _RowActions extends StatelessWidget {
  const _RowActions({
    required this.keyPrefix,
    required this.index,
    required this.count,
    required this.onMove,
    required this.onRemove,
  });

  final String keyPrefix;
  final int index;
  final int count;
  final void Function(int from, int to) onMove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        key: ValueKey('$keyPrefix-$index-up'),
        tooltip: 'Move up',
        icon: const Icon(Icons.arrow_upward, size: 18),
        onPressed: index == 0 ? null : () => onMove(index, index - 1),
      ),
      IconButton(
        key: ValueKey('$keyPrefix-$index-down'),
        tooltip: 'Move down',
        icon: const Icon(Icons.arrow_downward, size: 18),
        onPressed: index == count - 1 ? null : () => onMove(index, index + 1),
      ),
      IconButton(
        key: ValueKey('$keyPrefix-$index-remove'),
        tooltip: 'Remove assignment',
        color: context.colors.error,
        icon: const Icon(Icons.delete, size: 18),
        onPressed: onRemove,
      ),
    ],
  );
}

/// An outlined list of rows, or 0.1.6's centred empty message.
class _AssignmentList extends StatelessWidget {
  const _AssignmentList({required this.empty, required this.rows});

  final String empty;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final border = Border.all(color: context.colors.outlineVariant);
    final radius = BorderRadius.circular(ForgeRadii.card);
    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AnvilSpacing.lg),
        decoration: BoxDecoration(border: border, borderRadius: radius),
        child: Text(
          empty,
          textAlign: TextAlign.center,
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(border: border, borderRadius: radius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, row) in rows.indexed) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AnvilSpacing.md,
                vertical: AnvilSpacing.xs,
              ),
              child: row,
            ),
          ],
        ],
      ),
    );
  }
}

/// 0.1.6's `Add class` / `Add ability` row: a picker of what can still be
/// added and an `Add` button enabled once something is picked.
class _AddPicker extends StatefulWidget {
  const _AddPicker({
    required this.pickerKey,
    required this.buttonKey,
    required this.label,
    required this.options,
    required this.noneLabel,
    required this.onAdd,
  });

  final Key pickerKey;
  final Key buttonKey;
  final String label;
  final List<PickerOption<String>> options;

  /// 0.1.6's `noOptionsText` when nothing can be added.
  final String noneLabel;
  final ValueChanged<String> onAdd;

  @override
  State<_AddPicker> createState() => _AddPickerState();
}

class _AddPickerState extends State<_AddPicker> {
  String? _picked;

  @override
  Widget build(BuildContext context) {
    final picked = widget.options.any((o) => o.value == _picked)
        ? _picked
        : null;
    return Row(
      children: [
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _pickerMaxWidth),
            child: DraftPicker<String?>(
              key: widget.pickerKey,
              label: widget.label,
              dense: true,
              value: picked,
              options: [
                for (final o in widget.options)
                  (value: o.value, label: o.label),
              ],
              helperText: widget.options.isEmpty ? widget.noneLabel : null,
              onChanged: widget.options.isEmpty
                  ? null
                  : (v) => setState(() => _picked = v),
            ),
          ),
        ),
        const SizedBox(width: AnvilSpacing.sm),
        OutlinedButton(
          key: widget.buttonKey,
          onPressed: picked == null
              ? null
              : () {
                  setState(() => _picked = null);
                  widget.onAdd(picked);
                },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

/// The class assignments: per row the class name as a link to its editor,
/// a `Deleted` chip for a soft-deleted class, the level (clamped by the
/// controller to 1..max level), up / down / remove; then the picker of the
/// active classes not yet assigned.
class ClassAssignmentsSection extends ConsumerWidget {
  const ClassAssignmentsSection({
    super.key,
    required this.state,
    required this.issues,
    required this.controller,
  });

  static const pickerKey = ValueKey('npc-add-class');
  static const addKey = ValueKey('npc-add-class-confirm');

  static Key levelKey(int index) => ValueKey('npc-class-$index-level');

  final EditorState<NpcDraft> state;
  final List<ValidationIssue> issues;
  final NpcEditorController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classes = ref.watch(npcClassesProvider).value ?? const [];
    final byId = {for (final c in classes) c.id: c};
    final assignments = state.draft.classAssignments;
    final assigned = {for (final a in assignments) a.classId};
    final active = [
      for (final c in classes)
        if (c.deletedAt == null) c,
    ];
    final deleted = [
      for (final a in assignments)
        if (byId[a.classId] case final c? when c.deletedAt != null) c,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (deleted.isNotEmpty)
          NpcNotice(
            key: const ValueKey('npc-deleted-classes-warning'),
            message:
                'This NPC is assigned to soft-deleted '
                '${deleted.length == 1 ? 'class' : 'classes'}: '
                '${deleted.map((c) => c.displayName).join(', ')}. Their stat '
                'contributions are still included.',
          ),
        _FieldIssues(issues: issues, field: 'classAssignments'),
        _AssignmentList(
          empty: 'No classes assigned. Use the picker below to add one.',
          rows: [
            for (final (i, a) in assignments.indexed)
              _classRow(context, i, a, byId[a.classId], assignments.length),
          ],
        ),
        const SizedBox(height: AnvilSpacing.md),
        _AddPicker(
          pickerKey: pickerKey,
          buttonKey: addKey,
          label: 'Add class',
          options: [
            for (final c in active)
              if (!assigned.contains(c.id)) (value: c.id, label: c.displayName),
          ],
          noneLabel: active.isEmpty
              ? 'No classes exist yet'
              : 'No matching classes',
          onAdd: controller.addClassAssignment,
        ),
      ],
    );
  }

  Widget _classRow(
    BuildContext context,
    int i,
    NpcClassAssignment a,
    ClassRecord? record,
    int count,
  ) {
    final isDeleted = record?.deletedAt != null;
    final error =
        blockerText(state.blockers, 'classAssignments[$i].level') ??
        blockerText(state.blockers, 'classAssignments[$i].classId');
    return Row(
      key: ValueKey('npc-class-row-$i'),
      children: [
        Expanded(
          child: Wrap(
            spacing: AnvilSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _RecordLink(
                key: ValueKey('npc-class-$i-link'),
                label: record?.displayName ?? '[Unknown: ${a.classId}]',
                domain: ShellDomain.classes,
                id: a.classId,
                known: record != null,
                deleted: isDeleted,
              ),
              if (isDeleted)
                _DeletedChip(
                  key: ValueKey('npc-class-$i-deleted'),
                  tooltip:
                      'This class has been soft-deleted — it still '
                      'contributes to stats but may be permanently removed '
                      'later',
                ),
            ],
          ),
        ),
        const SizedBox(width: AnvilSpacing.md),
        SizedBox(
          width: _levelWidth,
          child: IntDraftField(
            key: levelKey(i),
            label: 'Level',
            dense: true,
            value: a.level,
            errorText: error,
            onChanged: (level) => controller.setClassLevel(i, level),
          ),
        ),
        const SizedBox(width: AnvilSpacing.sm),
        _RowActions(
          keyPrefix: 'npc-class',
          index: i,
          count: count,
          onMove: controller.moveClassAssignment,
          onRemove: () => controller.removeClassAssignment(i),
        ),
      ],
    );
  }
}

/// The stat block: one row per project stat with the inherited value
/// (the core's `computeNpcStatBlock` over the draft's assignments and each
/// class's resolved growth, so it follows every assignment and level
/// change), the override field (empty = no override) with `Revert to
/// inherited`, and the final value. An override is emphasised in the
/// warning tone and dims the inherited value, as 0.1.6 did.
class StatBlockSection extends ConsumerWidget {
  const StatBlockSection({
    super.key,
    required this.draft,
    required this.controller,
  });

  static Key overrideKey(String statId) =>
      ValueKey('npc-stat-$statId-override');
  static Key inheritedKey(String statId) =>
      ValueKey('npc-stat-$statId-inherited');
  static Key finalKey(String statId) => ValueKey('npc-stat-$statId-final');
  static Key revertKey(String statId) => ValueKey('npc-stat-$statId-revert');

  final NpcDraft draft;
  final NpcEditorController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(npcStatsProvider).value;
    if (stats == null) {
      return Text(
        'Loading stats…',
        style: context.text.bodyMedium?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      );
    }
    if (stats.isEmpty) {
      return const _AssignmentList(
        empty: 'No stats defined in project settings.',
        rows: [],
      );
    }
    final growth = <String, Map<StatGrowthKey, double>>{
      for (final a in draft.classAssignments)
        a.classId: ?ref.watch(classGrowthProvider(a.classId)).value,
    };
    final rows = computeNpcStatBlock(
      stats: stats,
      classAssignments: draft.classAssignments,
      growthByClass: growth,
      combatStats: draft.combatStats,
    );
    final names = {for (final s in stats) s.id: s.displayName};
    final header = context.text.labelMedium?.copyWith(
      color: context.colors.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final forge = context.forge;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.colors.outlineVariant),
        borderRadius: BorderRadius.circular(ForgeRadii.card),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(),
          1: IntrinsicColumnWidth(),
          2: IntrinsicColumnWidth(),
          3: IntrinsicColumnWidth(),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            children: [
              _cell(Text('Stat', style: header)),
              _cell(Text('Inherited', style: header), end: true),
              _cell(Text('Override', style: header), end: true),
              _cell(Text('Final', style: header), end: true),
            ],
          ),
          for (final row in rows)
            TableRow(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: context.colors.outlineVariant),
                ),
              ),
              children: [
                _cell(
                  Text(
                    names[row.statId] ?? row.statId,
                    style: context.text.bodyMedium,
                  ),
                ),
                _cell(
                  Text(
                    formatDraftNumber(row.inherited),
                    key: inheritedKey(row.statId),
                    style: AnvilType.numeric(
                      color: row.hasOverride
                          ? context.anvil.textDisabled
                          : context.colors.onSurfaceVariant,
                    ),
                  ),
                  end: true,
                ),
                _cell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: _overrideWidth,
                        decoration: row.hasOverride
                            ? BoxDecoration(
                                color: forge.warningContainer,
                                borderRadius: BorderRadius.circular(
                                  AnvilRadii.control,
                                ),
                              )
                            : null,
                        child: NumberDraftField(
                          key: overrideKey(row.statId),
                          dense: true,
                          hintText: '—',
                          value: row.overrideValue,
                          onChanged: (v) =>
                              controller.setStatOverride(row.statId, v),
                        ),
                      ),
                      IconButton(
                        key: revertKey(row.statId),
                        tooltip: row.hasOverride
                            ? 'Revert to inherited'
                            : 'No override',
                        icon: const Icon(Icons.restart_alt, size: 18),
                        onPressed: row.hasOverride
                            ? () => controller.revertStatOverride(row.statId)
                            : null,
                      ),
                    ],
                  ),
                  end: true,
                ),
                _cell(
                  Text(
                    formatDraftNumber(row.effective),
                    key: finalKey(row.statId),
                    style: AnvilType.numeric(
                      weight: row.hasOverride
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: row.hasOverride
                          ? forge.warning
                          : context.colors.onSurface,
                    ),
                  ),
                  end: true,
                ),
              ],
            ),
        ],
      ),
    );
  }

  static Widget _cell(Widget child, {bool end = false}) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AnvilSpacing.md,
      vertical: AnvilSpacing.xs,
    ),
    child: Align(
      alignment: end ? Alignment.centerRight : Alignment.centerLeft,
      child: child,
    ),
  );
}

/// The ability assignments, as the class editor's panel (0.1.6
/// `AbilityAssignmentPanel.tsx`): per row the ability name as a link, a
/// `Deleted` chip, up / down / remove; then the picker of the active
/// abilities not yet assigned.
class AbilityAssignmentsSection extends ConsumerWidget {
  const AbilityAssignmentsSection({
    super.key,
    required this.state,
    required this.issues,
    required this.controller,
  });

  static const pickerKey = ValueKey('npc-add-ability');
  static const addKey = ValueKey('npc-add-ability-confirm');

  final EditorState<NpcDraft> state;
  final List<ValidationIssue> issues;
  final NpcEditorController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final abilities = ref.watch(npcAbilitiesProvider).value ?? const [];
    final byId = {for (final a in abilities) a.id: a};
    final ids = state.draft.abilityIds;
    final assigned = ids.toSet();
    final active = [
      for (final a in abilities)
        if (a.deletedAt == null) a,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldIssues(issues: issues, field: 'abilityAssignments'),
        _AssignmentList(
          empty: 'No abilities assigned. Use the picker below to add one.',
          rows: [
            for (final (i, id) in ids.indexed)
              _abilityRow(i, id, byId[id], ids.length),
          ],
        ),
        const SizedBox(height: AnvilSpacing.md),
        _AddPicker(
          pickerKey: pickerKey,
          buttonKey: addKey,
          label: 'Add ability',
          options: [
            for (final a in active)
              if (!assigned.contains(a.id)) (value: a.id, label: a.displayName),
          ],
          noneLabel: active.isEmpty
              ? 'No abilities exist yet'
              : 'No matching abilities',
          onAdd: controller.addAbility,
        ),
      ],
    );
  }

  Widget _abilityRow(int i, String id, AbilityRecord? record, int count) {
    final isDeleted = record?.deletedAt != null;
    final blocker = blockerText(state.blockers, 'abilityIds[$i]');
    return Row(
      key: ValueKey('npc-ability-row-$i'),
      children: [
        Expanded(
          child: Wrap(
            spacing: AnvilSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _RecordLink(
                key: ValueKey('npc-ability-$i-link'),
                label: record?.displayName ?? '[Unknown: $id]',
                domain: ShellDomain.abilities,
                id: id,
                known: record != null,
                deleted: isDeleted,
              ),
              if (isDeleted)
                _DeletedChip(
                  key: ValueKey('npc-ability-$i-deleted'),
                  tooltip: 'This ability has been soft-deleted',
                ),
              if (blocker != null) _BlockerText(blocker),
            ],
          ),
        ),
        _RowActions(
          keyPrefix: 'npc-ability',
          index: i,
          count: count,
          onMove: controller.moveAbility,
          onRemove: () => controller.removeAbility(i),
        ),
      ],
    );
  }
}

class _BlockerText extends StatelessWidget {
  const _BlockerText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Text(
    message,
    style: context.text.bodySmall?.copyWith(color: context.colors.error),
  );
}

/// The loot table: a picker with `None` first, the active tables and the
/// assigned one even when soft-deleted (with 0.1.6's `Deleted` chip and
/// warning); then the assigned table's name as a link and its entries,
/// read-only, with each entry's chance of the total weight.
class LootTableSection extends ConsumerWidget {
  const LootTableSection({
    super.key,
    required this.draft,
    required this.issues,
    required this.controller,
  });

  static const pickerKey = ValueKey('npc-loot-table');

  final NpcDraft draft;
  final List<ValidationIssue> issues;
  final NpcEditorController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tables = ref.watch(npcLootTablesProvider).value ?? const [];
    final value = draft.lootTableId;
    final selected = tables.where((t) => t.id == value).firstOrNull;
    final isDeleted = selected?.deletedAt != null;
    final messages = fieldMessages(null, fieldIssue(issues, 'lootTableId'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _pickerMaxWidth),
                child: DraftPicker<String?>(
                  key: pickerKey,
                  label: 'Loot Table',
                  dense: true,
                  value: value,
                  options: [
                    (value: null, label: 'None'),
                    for (final t in tables)
                      if (t.deletedAt == null || t.id == value)
                        (value: t.id, label: t.displayName),
                  ],
                  errorText: messages.error,
                  helperText: messages.helper,
                  helperIsWarning: messages.warning,
                  onChanged: controller.setLootTable,
                ),
              ),
            ),
            if (isDeleted) ...[
              const SizedBox(width: AnvilSpacing.sm),
              const _DeletedChip(
                key: ValueKey('npc-loot-table-deleted'),
                tooltip: 'This loot table has been soft-deleted',
              ),
            ],
          ],
        ),
        const SizedBox(height: AnvilSpacing.md),
        if (isDeleted)
          const NpcNotice(
            message:
                'The assigned loot table has been soft-deleted. It is still '
                'referenced here but may be permanently removed later.',
          ),
        if (selected != null) _LootEntries(table: selected),
      ],
    );
  }
}

class _LootEntries extends ConsumerWidget {
  const _LootEntries({required this.table});

  final LootTableRecord table;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(npcLootTableEntriesProvider(table.id));
    final entries = entriesAsync.value;
    final items = ref.watch(npcItemsProvider).value ?? const [];
    final itemById = {for (final i in items) i.id: i};
    final muted = context.text.bodyMedium?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    final count = entries?.length ?? 0;
    final header = context.text.labelMedium?.copyWith(
      color: context.colors.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final totalWeight = entries?.fold<int>(0, (s, e) => s + e.weight) ?? 0;

    Widget body;
    if (entries == null) {
      body = entriesAsync.hasError
          ? Text(
              'Failed to load loot entries.',
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.error,
              ),
            )
          : Text('Loading entries…', style: muted);
    } else if (entries.isEmpty) {
      body = const _AssignmentList(
        empty: 'This loot table has no entries.',
        rows: [],
      );
    } else {
      body = Container(
        key: const ValueKey('npc-loot-entries'),
        decoration: BoxDecoration(
          border: Border.all(color: context.colors.outlineVariant),
          borderRadius: BorderRadius.circular(ForgeRadii.card),
        ),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(),
            1: IntrinsicColumnWidth(),
            2: IntrinsicColumnWidth(),
            3: IntrinsicColumnWidth(),
          },
          children: [
            TableRow(
              children: [
                _cell(Text('Item', style: header)),
                _cell(Text('Weight', style: header), end: true),
                _cell(Text('Chance', style: header), end: true),
                _cell(Text('Quantity', style: header), end: true),
              ],
            ),
            for (final e in entries)
              TableRow(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: context.colors.outlineVariant),
                  ),
                ),
                children: [
                  _cell(
                    Wrap(
                      spacing: AnvilSpacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          itemById[e.itemId]?.displayName ??
                              '[Unknown: ${e.itemId}]',
                          style: itemById[e.itemId]?.deletedAt != null
                              ? muted
                              : context.text.bodyMedium,
                        ),
                        if (itemById[e.itemId]?.deletedAt != null)
                          const _DeletedChip(
                            tooltip: 'This item has been soft-deleted',
                          ),
                      ],
                    ),
                  ),
                  _cell(
                    Text('${e.weight}', style: AnvilType.numeric()),
                    end: true,
                  ),
                  _cell(
                    Text(
                      lootChance(e.weight, totalWeight),
                      style: AnvilType.numeric(),
                    ),
                    end: true,
                  ),
                  _cell(
                    Text(
                      e.quantityMin == e.quantityMax
                          ? '${e.quantityMin}'
                          : '${e.quantityMin}–${e.quantityMax}',
                      style: AnvilType.numeric(),
                    ),
                    end: true,
                  ),
                ],
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _RecordLink(
              key: const ValueKey('npc-loot-table-link'),
              label: table.displayName,
              domain: ShellDomain.lootTables,
              id: table.id,
              known: true,
              deleted: table.deletedAt != null,
            ),
            const SizedBox(width: AnvilSpacing.sm),
            Text(
              '($count ${count == 1 ? 'entry' : 'entries'})',
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: AnvilSpacing.sm),
        body,
      ],
    );
  }

  static Widget _cell(Widget child, {bool end = false}) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AnvilSpacing.md,
      vertical: AnvilSpacing.sm,
    ),
    child: Align(
      alignment: end ? Alignment.centerRight : Alignment.centerLeft,
      child: child,
    ),
  );
}

/// 0.1.6's chance column: the share of the total weight as `12.5%`, `—`
/// when the total is 0.
String lootChance(int weight, int totalWeight) => totalWeight > 0
    ? '${(weight / totalWeight * 100).toStringAsFixed(1)}%'
    : '—';
