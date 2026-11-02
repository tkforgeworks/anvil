/// The loot table editor (0.1.6 `LootTableEditorPage.tsx`) on the shared
/// editor scaffold (ANVL-187).
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../../editor/editor_state.dart';
import '../../editor/record_editor_scope.dart';
import '../../editor/widgets/dirty_dot.dart';
import '../../editor/widgets/draft_picker.dart';
import '../../editor/widgets/draft_text_field.dart';
import '../../editor/widgets/edit_header.dart';
import '../../editor/widgets/field_messages.dart';
import '../../editor/widgets/number_draft_field.dart';
import '../../editor/widgets/record_validation.dart';
import '../../editor/widgets/save_bar.dart';
import '../../editor/widgets/validation_banner.dart';
import '../../lists/record_list_controller.dart' show listErrorMessage;
import '../../settings/project/rarity_section.dart' show rarityHexPattern;
import '../../shell/app_router.dart' show routerProvider;
import '../../shell/open_editor.dart';
import '../../shell/shell_domain.dart';
import '../../theme/anvil_colors.dart';
import '../../theme/anvil_metrics.dart';
import '../../theme/color_math.dart';
import '../../widgets/inspector_rail.dart';
import 'loot_tables_editor_controller.dart';
import 'loot_tables_providers.dart';

/// The editor tabs, 0.1.6's two.
enum LootTableEditorTab {
  overview('Overview'),
  entries('Entries');

  const LootTableEditorTab(this.label);

  final String label;

  Key get key => ValueKey('loot-table-tab-$name');
  Key get dotKey => ValueKey('loot-table-tab-dot-$name');
}

/// 0.1.6's `maxWidth: 360` on the export key field.
const _exportKeyMaxWidth = 360.0;

/// 0.1.6's `maxWidth: 760` on the description field.
const _descriptionMaxWidth = 760.0;

/// 0.1.6's `fontSize: '0.85rem'` on the export key input.
const _exportKeyFontSize = 13.6;

/// 0.1.6's `Drop percentages are calculated from the current weights.`
const dropCaption = 'Drop percentages are calculated from the current weights.';

/// 0.1.6's warning above the tabs while an entry names a soft-deleted item.
const deletedReferenceWarning =
    'This loot table references a soft-deleted item. Validation will flag '
    'this loot table.';

/// The weight 0.1.6 computed drop percentages from:
/// `Math.max(1, Math.floor(weight || 1))`, so an entry whose weight the
/// save blockers refuse still counts as 1.
int effectiveDropWeight(int weight) => math.max(1, weight);

/// 0.1.6's `formatPercent`: one decimal from 10 % up, two below.
String formatDropPercent(double value) =>
    '${value.toStringAsFixed(value >= 10 ? 1 : 2)}%';

/// Each entry's drop percentage text, `weight / totalWeight * 100`, as
/// 0.1.6 computed it from the current draft.
List<String> dropPercentages(List<LootTableEntryDraft> entries) {
  final total = entries.fold<int>(
    0,
    (sum, e) => sum + effectiveDropWeight(e.weight),
  );
  return [
    for (final e in entries)
      formatDropPercent(
        total > 0 ? effectiveDropWeight(e.weight) / total * 100 : 0,
      ),
  ];
}

/// Edits loot table [id]: the header with the name, undo, redo and Save;
/// the Overview and Entries tabs as 0.1.6 had them (the export key,
/// description and entries all sit on Entries, which carries the dirty
/// dot); the record's validation after a save; the NPCs that drop from it
/// in the rail beside every tab; and the save bar while dirty.
///
/// The same widget is the full-page route and the body of the modal editor
/// dialog. With a bounded height (the route) the tab body scrolls between
/// the header and the save bar; with an unbounded one (the dialog's scroll
/// view) everything is laid out in one column.
class LootTableEditorPage extends ConsumerStatefulWidget {
  const LootTableEditorPage(this.id, {super.key, this.onBack});

  final String id;

  /// Leaves the editor; by default it pops the editor dialog (the dialog's
  /// leave guard runs) or goes to the loot table list (the route's leave
  /// guard runs).
  final VoidCallback? onBack;

  static const duplicateKey = ValueKey('loot-table-duplicate');
  static const exportKeyKey = ValueKey('loot-table-export-key');
  static const descriptionKey = ValueKey('loot-table-description');
  static const addEntryKey = ValueKey('loot-table-add-entry');
  static const deletedWarningKey = ValueKey(
    'loot-table-deleted-reference-warning',
  );

  /// The rail's one section.
  static const npcsSection = 'NPCs';

  /// A control of entry row [index]: `item`, `weight`, `drop`, `min`,
  /// `max`, `up`, `down`, `remove` or `errors`.
  static Key entryKey(int index, String part) =>
      ValueKey('loot-table-entry-$index-$part');

  @override
  ConsumerState<LootTableEditorPage> createState() =>
      _LootTableEditorPageState();
}

class _LootTableEditorPageState extends ConsumerState<LootTableEditorPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: LootTableEditorTab.values.length,
    vsync: this,
  )..addListener(_onTab);
  var _duplicating = false;

  RecordValidationKey get _validationKey =>
      (ValidationDomain.lootTables, widget.id);

  void _onTab() {
    if (!_tabs.indexIsChanging) setState(() {});
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// Every save outcome (Ctrl+S, the header, the save bar) re-validates
  /// the record after a completed save; failures and blockers show in the
  /// header and the save bar themselves.
  void _onSaveOutcome(SaveOutcome outcome) => ref
      .read(recordValidationProvider(_validationKey).notifier)
      .afterSave(outcome);

  void _back() {
    if (widget.onBack case final onBack?) return onBack();
    if (ModalRoute.of(context) is PopupRoute) {
      Navigator.of(context).maybePop();
    } else {
      // Through the router as the menu navigates, so go_router stays
      // imported only under `lib/app/shell/`.
      ref.read(routerProvider).go(ShellDomain.lootTables.location);
    }
  }

  Future<void> _duplicate() async {
    if (_duplicating) return;
    setState(() => _duplicating = true);
    final controller = ref.read(lootTableEditorProvider(widget.id).notifier);
    try {
      final copy = await controller.duplicate();
      if (mounted) openEditor(context, ref, ShellDomain.lootTables, copy.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            listErrorMessage(error, 'Failed to duplicate loot table.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _duplicating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = lootTableEditorProvider(widget.id);
    final async = ref.watch(provider);
    return RecordEditorScope<LootTableDraft>(
      provider: provider,
      onSaveOutcome: _onSaveOutcome,
      child: switch (async) {
        AsyncValue(:final EditorState<LootTableDraft> value) => _editor(
          context,
          value,
        ),
        AsyncError(:final error) => _LoadFailed(
          message: error is RecordNotFound
              ? 'Loot table not found.'
              : 'Failed to load loot table.',
          onBack: _back,
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _editor(BuildContext context, EditorState<LootTableDraft> state) {
    final provider = lootTableEditorProvider(widget.id);
    final controller = ref.read(provider.notifier);
    final issues = ref.watch(recordValidationProvider(_validationKey));
    final lookups =
        ref.watch(lootTableLookupsProvider).value ?? LootTableLookups.empty;
    final dirty = dirtyTabs<LootTableDraft>(state.baseline, state.draft, {
      LootTableEditorTab.entries.name: (a, b) =>
          a.exportKey == b.exportKey &&
          a.description == b.description &&
          listEquals(a.entries, b.entries),
    });
    final tab = LootTableEditorTab.values[_tabs.index];

    final header = EditHeader<LootTableDraft>(
      provider: provider,
      backLabel: ShellDomain.lootTables.label,
      onBack: _back,
      displayNameOf: (d) => d.displayName,
      exportKeyOf: (d) => d.exportKey,
      onDisplayNameChanged: controller.setDisplayName,
      onSaveOutcome: _onSaveOutcome,
    );
    final tabRow = Row(
      children: [
        Expanded(
          child: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final t in LootTableEditorTab.values)
                Tab(
                  key: t.key,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(t.label),
                      if (t != LootTableEditorTab.overview)
                        DirtyDot(
                          key: t.dotKey,
                          visible: dirty.contains(t.name),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: AnvilSpacing.md),
        Tooltip(
          message: state.isDirty
              ? 'Save your changes before duplicating'
              : 'Duplicate',
          child: OutlinedButton.icon(
            key: LootTableEditorPage.duplicateKey,
            icon: const Icon(Icons.content_copy, size: 16),
            label: const Text('Duplicate'),
            onPressed: state.isDirty || state.saving || _duplicating
                ? null
                : () => unawaited(_duplicate()),
          ),
        ),
      ],
    );
    final panel = switch (tab) {
      LootTableEditorTab.overview => _OverviewPanel(draft: state.draft),
      LootTableEditorTab.entries => _EntriesPanel(
        state: state,
        issues: issues,
        lookups: lookups,
        controller: controller,
      ),
    };
    final referencesDeleted = state.draft.entries.any(
      (e) => lookups.isDeleted(e.itemId),
    );
    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ValidationBanner(issues),
              if (referencesDeleted)
                const _Notice(
                  key: LootTableEditorPage.deletedWarningKey,
                  message: deletedReferenceWarning,
                ),
              Align(alignment: Alignment.topLeft, child: panel),
            ],
          ),
        ),
        _UsedByRail(id: widget.id),
      ],
    );
    final saveBar = SaveBar<LootTableDraft>(
      provider: provider,
      onSaveOutcome: _onSaveOutcome,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              tabRow,
              const SizedBox(height: AnvilSpacing.lg),
              body,
              saveBar,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            tabRow,
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(
                  top: AnvilSpacing.lg,
                  bottom: AnvilSpacing.lg,
                ),
                child: body,
              ),
            ),
            saveBar,
          ],
        );
      },
    );
  }
}

/// 0.1.6's `OverviewTab` without its Used By list, which is the rail here.
class _OverviewPanel extends StatelessWidget {
  const _OverviewPanel({required this.draft});

  final LootTableDraft draft;

  @override
  Widget build(BuildContext context) {
    final caption = context.text.labelSmall?.copyWith(
      color: context.anvil.textDisabled,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NAME', style: caption),
          Text(
            draft.displayName.isEmpty ? '—' : draft.displayName,
            key: const ValueKey('loot-table-overview-name'),
            style: context.text.titleLarge,
          ),
          const SizedBox(height: AnvilSpacing.lg),
          Text('DESCRIPTION', style: caption),
          const SizedBox(height: AnvilSpacing.xs),
          Text(
            draft.description.isEmpty
                ? 'No description provided.'
                : draft.description,
            key: const ValueKey('loot-table-overview-description'),
            style: context.text.bodyLarge?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 0.1.6's Entries tab: the export key, the description and the entry
/// rows with their drop percentages.
class _EntriesPanel extends StatelessWidget {
  const _EntriesPanel({
    required this.state,
    required this.issues,
    required this.lookups,
    required this.controller,
  });

  final EditorState<LootTableDraft> state;
  final List<ValidationIssue> issues;
  final LootTableLookups lookups;
  final LootTableEditorController controller;

  @override
  Widget build(BuildContext context) {
    final draft = state.draft;
    final entries = draft.entries;
    final active = lookups.activeItems;
    final percentages = dropPercentages(entries);
    final muted = context.text.bodyMedium?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _exportKeyMaxWidth),
            child: DraftTextField(
              key: LootTableEditorPage.exportKeyKey,
              label: 'Export Key',
              value: draft.exportKey,
              hintText: 'export-key',
              onChanged: controller.setExportKey,
              blockerMessage: blockerText(state.blockers, 'exportKey'),
              issueMessage: fieldIssueText(issues, 'exportKey'),
              style: ForgeType.code(
                size: _exportKeyFontSize,
                color: context.colors.onSurface,
              ),
              decoration: const InputDecoration(
                helperText: 'Export key — used in exported files',
              ),
            ),
          ),
        ),
        const SizedBox(height: AnvilSpacing.lg),
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _descriptionMaxWidth),
            child: DraftTextField(
              key: LootTableEditorPage.descriptionKey,
              label: 'Description',
              value: draft.description,
              maxLines: 4,
              onChanged: controller.setDescription,
              issueMessage: fieldIssueText(issues, 'description'),
            ),
          ),
        ),
        const SizedBox(height: AnvilSpacing.lg),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Entries', style: context.text.titleMedium),
                  Text(
                    dropCaption,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              key: LootTableEditorPage.addEntryKey,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Entry'),
              onPressed: active.isEmpty
                  ? null
                  : () => controller.addEntry(active.first.id),
            ),
          ],
        ),
        const SizedBox(height: AnvilSpacing.md),
        if (active.isEmpty && lookups != LootTableLookups.empty)
          const _Notice(
            message: 'Create an active item before adding loot entries.',
            info: true,
          ),
        if (entries.isEmpty)
          Text('No entries yet.', style: muted)
        else ...[
          const _EntryHeader(),
          for (final (i, entry) in entries.indexed)
            _EntryRow(
              key: ValueKey('loot-table-entry-row-$i'),
              index: i,
              entry: entry,
              count: entries.length,
              percent: percentages[i],
              blockers: state.blockers,
              lookups: lookups,
              controller: controller,
            ),
        ],
      ],
    );
  }
}

/// The column widths of the entry rows (0.1.6's table had 110 / 120 px
/// numeric columns beside a wide item column).
abstract final class _Cols {
  static const rarity = 36.0;
  static const number = 96.0;
  static const drop = 72.0;
  static const actions = 120.0;
}

class _EntryHeader extends StatelessWidget {
  const _EntryHeader();

  @override
  Widget build(BuildContext context) {
    final style = context.text.labelMedium?.copyWith(
      color: context.colors.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    const gap = SizedBox(width: AnvilSpacing.sm);
    return Padding(
      padding: const EdgeInsets.only(bottom: AnvilSpacing.sm),
      child: Row(
        children: [
          const SizedBox(width: _Cols.rarity),
          gap,
          Expanded(child: Text('Item', style: style)),
          gap,
          SizedBox(
            width: _Cols.number,
            child: Text('Weight', style: style),
          ),
          gap,
          SizedBox(
            width: _Cols.drop,
            child: Text('Drop', style: style),
          ),
          gap,
          SizedBox(
            width: _Cols.number,
            child: Text('Min Qty', style: style),
          ),
          gap,
          SizedBox(
            width: _Cols.number,
            child: Text('Max Qty', style: style),
          ),
          gap,
          SizedBox(
            width: _Cols.actions,
            child: Text('Actions', style: style, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

/// One entry: the item's rarity, the item picker, weight, the computed
/// drop percentage, minimum and maximum quantity, and move / remove. The
/// core's blockers for the row put its number fields in error and are
/// listed in full under it, since the fields are too narrow for them.
class _EntryRow extends StatelessWidget {
  const _EntryRow({
    super.key,
    required this.index,
    required this.entry,
    required this.count,
    required this.percent,
    required this.blockers,
    required this.lookups,
    required this.controller,
  });

  final int index;
  final LootTableEntryDraft entry;
  final int count;
  final String percent;
  final List<SaveBlocker> blockers;
  final LootTableLookups lookups;
  final LootTableEditorController controller;

  @override
  Widget build(BuildContext context) {
    final i = index;
    Key key(String part) => LootTableEditorPage.entryKey(i, part);
    final weight = fieldMessages(
      blockerText(blockers, 'entries[$i].weight'),
      null,
    );
    final min = fieldMessages(
      blockerText(blockers, 'entries[$i].quantityMin'),
      null,
    );
    final max = fieldMessages(
      blockerText(blockers, 'entries[$i].quantityMax'),
      null,
    );
    final rowErrors = [?weight.error, ?min.error, ?max.error];
    final deleted = lookups.isDeleted(entry.itemId);
    const gap = SizedBox(width: AnvilSpacing.sm);
    return Padding(
      padding: const EdgeInsets.only(bottom: AnvilSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: AnvilSpacing.sm),
                child: SizedBox(
                  width: _Cols.rarity,
                  child: _RarityChip(lookups.rarityOfItem(entry.itemId)),
                ),
              ),
              gap,
              Expanded(
                child: DraftPicker<String>(
                  key: key('item'),
                  label: 'Item',
                  dense: true,
                  value: entry.itemId,
                  options: [
                    for (final item in lookups.activeItems)
                      (value: item.id, label: item.displayName),
                  ],
                  unknownLabel: (id) => switch (lookups.item(id)) {
                    final item? => '${item.displayName} (deleted)',
                    null => id,
                  },
                  onChanged: (v) => controller.setEntryItem(i, v),
                  helperText: deleted ? 'Soft-deleted item reference' : null,
                  helperIsWarning: true,
                ),
              ),
              gap,
              SizedBox(
                width: _Cols.number,
                child: IntDraftField(
                  key: key('weight'),
                  dense: true,
                  value: entry.weight,
                  onChanged: (w) => controller.setEntryWeight(i, w),
                  errorText: weight.error == null ? null : '',
                ),
              ),
              gap,
              SizedBox(
                width: _Cols.drop,
                child: Padding(
                  padding: const EdgeInsets.only(top: AnvilSpacing.sm),
                  child: Text(
                    percent,
                    key: key('drop'),
                    style: context.text.bodyMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              gap,
              SizedBox(
                width: _Cols.number,
                child: IntDraftField(
                  key: key('min'),
                  dense: true,
                  value: entry.quantityMin,
                  onChanged: (q) => controller.setEntryQuantityMin(i, q),
                  errorText: min.error == null ? null : '',
                ),
              ),
              gap,
              SizedBox(
                width: _Cols.number,
                child: IntDraftField(
                  key: key('max'),
                  dense: true,
                  value: entry.quantityMax,
                  onChanged: (q) => controller.setEntryQuantityMax(i, q),
                  errorText: max.error == null ? null : '',
                ),
              ),
              gap,
              SizedBox(
                width: _Cols.actions,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      key: key('up'),
                      tooltip: 'Move up',
                      icon: const Icon(Icons.arrow_upward, size: 18),
                      onPressed: i == 0
                          ? null
                          : () => controller.moveEntry(i, i - 1),
                    ),
                    IconButton(
                      key: key('down'),
                      tooltip: 'Move down',
                      icon: const Icon(Icons.arrow_downward, size: 18),
                      onPressed: i == count - 1
                          ? null
                          : () => controller.moveEntry(i, i + 1),
                    ),
                    IconButton(
                      key: key('remove'),
                      tooltip: 'Remove',
                      color: context.colors.error,
                      icon: const Icon(Icons.delete, size: 18),
                      onPressed: () => controller.removeEntry(i),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (rowErrors.isNotEmpty)
            Padding(
              key: key('errors'),
              padding: const EdgeInsets.only(
                left: _Cols.rarity + AnvilSpacing.sm,
                top: AnvilSpacing.xs,
              ),
              child: Text(
                rowErrors.join('\n'),
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 0.1.6's `renderRarityChip`: the rarity's initial in its colour with the
/// name as tooltip, `?` when the item or its rarity is unknown.
class _RarityChip extends StatelessWidget {
  const _RarityChip(this.rarity);

  final MetaRarity? rarity;

  @override
  Widget build(BuildContext context) {
    final rarity = this.rarity;
    final hex = rarity?.colorHex.trim() ?? '';
    // The rarity's colour is the user's data, built through `hexToColor`,
    // not a theme colour (as the project settings' swatch).
    final color = rarityHexPattern.hasMatch(hex)
        ? hexToColor(hex)
        : context.colors.outline;
    final name = rarity?.displayName ?? '';
    final chip = Container(
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
        style: context.text.labelMedium?.copyWith(
          color: rarity == null ? context.colors.onSurfaceVariant : color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return name.isEmpty ? chip : Tooltip(message: name, child: chip);
  }
}

/// The NPCs that drop from the loot table, re-read after every write.
class _UsedByRail extends ConsumerWidget {
  const _UsedByRail({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usedBy = ref.watch(lootTableUsedByProvider(id));
    final value = usedBy.value;
    return InspectorRail(
      loading: value == null && usedBy.isLoading,
      sections: [
        UsedBySection(
          title: LootTableEditorPage.npcsSection,
          domain: ShellDomain.npcs,
          refs: value ?? const [],
        ),
      ],
    );
  }
}

/// A warning (or, with [info], an information) line, as 0.1.6's MUI
/// `Alert`s in the editor.
class _Notice extends StatelessWidget {
  const _Notice({super.key, required this.message, this.info = false});

  final String message;
  final bool info;

  @override
  Widget build(BuildContext context) {
    final forge = context.forge;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AnvilSpacing.md),
      padding: const EdgeInsets.all(AnvilSpacing.md),
      decoration: BoxDecoration(
        color: info ? forge.infoContainer : forge.warningContainer,
        borderRadius: BorderRadius.circular(ForgeRadii.card),
      ),
      child: Row(
        children: [
          Icon(
            info ? Icons.info_outline : Icons.warning_amber,
            size: 20,
            color: info ? forge.info : forge.warning,
          ),
          const SizedBox(width: AnvilSpacing.md),
          Expanded(child: Text(message, style: context.text.bodyMedium)),
        ],
      ),
    );
  }
}

/// 0.1.6's not-found view: the error and `Back to Loot Tables`.
class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.message, required this.onBack});

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AnvilSpacing.xl),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ForgeErrorCard(
          key: const ValueKey('loot-table-load-error'),
          message: message,
        ),
        const SizedBox(height: AnvilSpacing.md),
        TextButton(onPressed: onBack, child: const Text('Back to Loot Tables')),
      ],
    ),
  );
}
