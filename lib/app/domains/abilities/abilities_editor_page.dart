/// The ability editor (0.1.6 `AbilityEditorPage.tsx`): the Overview,
/// Details and Stat Modifiers tabs over one ability's draft, with the Used
/// By rail on the right.
library;

import 'dart:async';

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../../editor/editor_state.dart';
import '../../editor/record_editor_scope.dart';
import '../../editor/widgets/dirty_dot.dart';
import '../../editor/widgets/draft_text_field.dart';
import '../../editor/widgets/edit_header.dart';
import '../../editor/widgets/record_validation.dart';
import '../../editor/widgets/save_bar.dart';
import '../../editor/widgets/validation_banner.dart';
import '../../lists/record_list_controller.dart' show listErrorMessage;
import '../../shell/app_router.dart' show routerProvider;
import '../../shell/editor_dialog.dart';
import '../../shell/open_editor.dart';
import '../../shell/shell_domain.dart';
import '../../theme/anvil_colors.dart';
import '../../theme/anvil_metrics.dart';
import '../../widgets/inspector_rail.dart';
import 'abilities_editor_controller.dart';
import 'abilities_providers.dart';
import 'number_draft_field.dart';

/// The editor of ability [id], as a full page and as the editor dialog's
/// body: [RecordEditorScope] around the [EditHeader], the tabs with their
/// [DirtyDot]s, the [ValidationBanner], the tab body beside the
/// [InspectorRail], and the [SaveBar].
///
/// Back leaves the editor the way it was opened: inside an [EditorDialog]
/// it closes the dialog (through its leave guard), on the editor route it
/// goes to the list (through the route's).
class AbilityEditorPage extends ConsumerStatefulWidget {
  const AbilityEditorPage(this.id, {super.key});

  final String id;

  /// The three tabs, in 0.1.6's order.
  static const tabLabels = ['Overview', 'Details', 'Stat Modifiers'];

  /// The Used By sections' titles (0.1.6 `usedBySections` labels).
  static const classesSection = 'Character Classes';
  static const npcsSection = 'NPCs';

  static const duplicateKey = ValueKey('ability-duplicate');

  /// The Details tab's text and number fields, by draft field name.
  static Key fieldKey(String field) => ValueKey('ability-field-$field');

  /// The Stat Modifiers tab's field for stat [statId].
  static Key modifierKey(String statId) => ValueKey('ability-modifier-$statId');

  @override
  ConsumerState<AbilityEditorPage> createState() => _AbilityEditorPageState();
}

class _AbilityEditorPageState extends ConsumerState<AbilityEditorPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: AbilityEditorPage.tabLabels.length,
    vsync: this,
  )..addListener(_tabChanged);

  var _duplicating = false;

  void _tabChanged() {
    if (!_tabs.indexIsChanging) setState(() {});
  }

  @override
  void dispose() {
    _tabs
      ..removeListener(_tabChanged)
      ..dispose();
    super.dispose();
  }

  RecordValidationKey get _validationKey =>
      (ValidationDomain.abilities, widget.id);

  void _onSaveOutcome(SaveOutcome outcome) => ref
      .read(recordValidationProvider(_validationKey).notifier)
      .afterSave(outcome);

  void _back() {
    if (context.findAncestorWidgetOfExactType<EditorDialog>() != null) {
      unawaited(Navigator.of(context).maybePop());
    } else {
      // Through the router as the menu navigates, so go_router stays
      // imported only under `lib/app/shell/`.
      ref.read(routerProvider).go(ShellDomain.abilities.location);
    }
  }

  Future<void> _duplicate() async {
    if (_duplicating) return;
    setState(() => _duplicating = true);
    final controller = ref.read(abilitiesEditorProvider(widget.id).notifier);
    try {
      final copy = await controller.duplicate();
      if (mounted) openEditor(context, ref, ShellDomain.abilities, copy.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            listErrorMessage(error, 'Failed to duplicate ability.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _duplicating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = abilitiesEditorProvider(widget.id);
    final async = ref.watch(provider);
    final issues = ref.watch(recordValidationProvider(_validationKey));
    final state = async.value;
    if (state == null) {
      if (async.error case final error?) {
        return _LoadError(error: error, onBack: _back);
      }
      return const Center(child: CircularProgressIndicator());
    }
    final controller = ref.read(provider.notifier);
    final dirty = dirtyTabs<AbilityDraft>(state.baseline, state.draft, {
      'details': (a, b) =>
          a.exportKey == b.exportKey &&
          a.description == b.description &&
          a.abilityType == b.abilityType &&
          a.resourceType == b.resourceType &&
          a.resourceCost == b.resourceCost &&
          a.cooldown == b.cooldown,
      'modifiers': (a, b) => mapEquals(a.statModifiers, b.statModifiers),
    });

    final header = EditHeader<AbilityDraft>(
      provider: provider,
      backLabel: ShellDomain.abilities.label,
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
              Tab(text: AbilityEditorPage.tabLabels[0]),
              Tab(
                child: _TabLabel(
                  AbilityEditorPage.tabLabels[1],
                  dirty: dirty.contains('details'),
                ),
              ),
              Tab(
                child: _TabLabel(
                  AbilityEditorPage.tabLabels[2],
                  dirty: dirty.contains('modifiers'),
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
            key: AbilityEditorPage.duplicateKey,
            icon: const Icon(Icons.content_copy, size: 16),
            label: const Text('Duplicate'),
            onPressed: state.isDirty || state.saving || _duplicating
                ? null
                : () => unawaited(_duplicate()),
          ),
        ),
      ],
    );

    final usedBy = ref.watch(abilityUsedByProvider(widget.id));
    final rail = InspectorRail(
      loading: !usedBy.hasValue && usedBy.isLoading,
      sections: [
        UsedBySection(
          title: AbilityEditorPage.classesSection,
          domain: ShellDomain.classes,
          refs: usedBy.value?.classes ?? const [],
        ),
        UsedBySection(
          title: AbilityEditorPage.npcsSection,
          domain: ShellDomain.npcs,
          refs: usedBy.value?.npcs ?? const [],
        ),
      ],
    );

    final tabBody = switch (_tabs.index) {
      0 => _OverviewTab(draft: state.draft),
      1 => _DetailsTab(
        draft: state.draft,
        blockers: state.blockers,
        issues: issues,
        controller: controller,
      ),
      _ => _StatModifiersTab(draft: state.draft, controller: controller),
    };
    final main = Padding(
      padding: const EdgeInsets.only(top: AnvilSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Align(alignment: Alignment.topLeft, child: tabBody),
          ),
          rail,
        ],
      ),
    );
    final top = [header, tabRow, const SizedBox(height: AnvilSpacing.md)];
    final banner = ValidationBanner(issues);
    final saveBar = SaveBar<AbilityDraft>(
      provider: provider,
      onSaveOutcome: _onSaveOutcome,
    );

    return RecordEditorScope<AbilityDraft>(
      provider: provider,
      onSaveOutcome: _onSaveOutcome,
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.hasBoundedHeight
            // The editor route: the header, tabs and save bar stay put
            // while the body scrolls.
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...top,
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [banner, main],
                      ),
                    ),
                  ),
                  saveBar,
                ],
              )
            // The editor dialog, which scrolls its body itself.
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [...top, banner, main, saveBar],
              ),
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel(this.label, {required this.dirty});

  final String label;
  final bool dirty;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label),
      DirtyDot(key: ValueKey('dirty-dot-$label'), visible: dirty),
    ],
  );
}

/// 0.1.6 `OverviewTab`: the name and the description, read-only. Its Used
/// By list is the rail beside every tab.
class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.draft});

  final AbilityDraft draft;

  @override
  Widget build(BuildContext context) {
    final caption = context.text.labelSmall?.copyWith(
      color: context.anvil.textDisabled,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.66,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NAME', style: caption),
          Text(
            draft.displayName.isEmpty ? '—' : draft.displayName,
            style: context.text.titleLarge,
          ),
          const SizedBox(height: AnvilSpacing.lg),
          Text('DESCRIPTION', style: caption),
          const SizedBox(height: AnvilSpacing.xs),
          Text(
            draft.description.isEmpty
                ? 'No description provided.'
                : draft.description,
            style: context.text.bodyLarge?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({
    required this.draft,
    required this.blockers,
    required this.issues,
    required this.controller,
  });

  final AbilityDraft draft;
  final List<SaveBlocker> blockers;
  final List<ValidationIssue> issues;
  final AbilityEditorController controller;

  @override
  Widget build(BuildContext context) {
    DraftTextField text(
      String field,
      String label,
      String value,
      ValueChanged<String> onChanged, {
      String? helperText,
      int maxLines = 1,
    }) => DraftTextField(
      key: AbilityEditorPage.fieldKey(field),
      label: label,
      value: value,
      onChanged: onChanged,
      maxLines: maxLines,
      blockerMessage: blockerText(blockers, field),
      issueMessage: fieldIssueText(issues, field),
      issueSeverity:
          fieldIssue(issues, field)?.severity ?? ValidationSeverity.error,
      decoration: InputDecoration(helperText: helperText),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 360,
              child: DraftTextField(
                key: AbilityEditorPage.fieldKey('exportKey'),
                label: 'Export Key',
                value: draft.exportKey,
                onChanged: controller.setExportKey,
                hintText: 'export-key',
                style: ForgeType.code(size: 13.6),
                blockerMessage: blockerText(blockers, 'exportKey'),
                issueMessage: fieldIssueText(issues, 'exportKey'),
                decoration: const InputDecoration(
                  helperText: 'Export key — used in exported files',
                ),
              ),
            ),
          ),
          const SizedBox(height: AnvilSpacing.md),
          text(
            'description',
            'Description',
            draft.description,
            controller.setDescription,
            maxLines: 3,
          ),
          const SizedBox(height: AnvilSpacing.md),
          text(
            'abilityType',
            'Ability Type',
            draft.abilityType,
            controller.setAbilityType,
            helperText: 'e.g. active, passive, ultimate',
          ),
          const SizedBox(height: AnvilSpacing.md),
          text(
            'resourceType',
            'Resource Type',
            draft.resourceType,
            controller.setResourceType,
            helperText: 'e.g. mana, stamina, rage',
          ),
          const SizedBox(height: AnvilSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: NumberDraftField(
                  key: AbilityEditorPage.fieldKey('resourceCost'),
                  label: 'Resource Cost',
                  value: draft.resourceCost,
                  // 0.1.6 saved an empty cost as `parseFloat('') || 0`.
                  emptyValue: 0,
                  issueMessage: fieldIssueText(issues, 'resourceCost'),
                  onChanged: (v) => controller.setResourceCost(v ?? 0),
                ),
              ),
              const SizedBox(width: AnvilSpacing.md),
              Expanded(
                child: NumberDraftField(
                  key: AbilityEditorPage.fieldKey('cooldown'),
                  label: 'Cooldown',
                  value: draft.cooldown,
                  emptyValue: 0,
                  helperText: 'In turns or seconds',
                  issueMessage: fieldIssueText(issues, 'cooldown'),
                  onChanged: (v) => controller.setCooldown(v ?? 0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Every project stat with its modifier; an empty (or zero) field is no
/// modifier.
class _StatModifiersTab extends ConsumerWidget {
  const _StatModifiersTab({required this.draft, required this.controller});

  final AbilityDraft draft;
  final AbilityEditorController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = context.text.bodyMedium?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    final stats = ref.watch(abilityStatsProvider);
    final list = stats.value;
    if (list == null) {
      if (stats.hasError) {
        return Text('Failed to load the project\'s stats.', style: muted);
      }
      return const Center(child: CircularProgressIndicator());
    }
    if (list.isEmpty) {
      return Text('No stats defined in this project.', style: muted);
    }
    final border = BorderSide(color: context.colors.outlineVariant);
    final head = context.text.labelLarge;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Flat modifiers applied when this ability is active. Zero values '
            'are not exported.',
            style: muted,
          ),
          const SizedBox(height: AnvilSpacing.md),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(),
              1: FixedColumnWidth(140),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            border: TableBorder(horizontalInside: border, bottom: border),
            children: [
              TableRow(
                children: [
                  _Cell(Text('Stat', style: head)),
                  _Cell(Text('Modifier', style: head)),
                ],
              ),
              for (final stat in list)
                TableRow(
                  children: [
                    _Cell(
                      Text(stat.displayName, style: context.text.bodyMedium),
                    ),
                    _Cell(
                      NumberDraftField(
                        key: AbilityEditorPage.modifierKey(stat.id),
                        value: draft.statModifiers[stat.id],
                        zeroIsEmpty: true,
                        hintText: '0',
                        prefixText: '± ',
                        dense: true,
                        onChanged: (v) =>
                            controller.setStatModifier(stat.id, v),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AnvilSpacing.sm,
      vertical: AnvilSpacing.xs,
    ),
    child: child,
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.onBack});

  final Object error;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AnvilSpacing.xl),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          error is RecordNotFound
              ? 'Ability not found.'
              : 'Failed to load ability.',
          key: const ValueKey('ability-load-error'),
          style: context.text.bodyMedium?.copyWith(color: context.colors.error),
        ),
        const SizedBox(height: AnvilSpacing.md),
        TextButton(onPressed: onBack, child: const Text('Back to Abilities')),
      ],
    ),
  );
}
