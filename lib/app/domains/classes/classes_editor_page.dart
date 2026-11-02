/// The class editor (0.1.6 `ClassEditorPage.tsx`): the Overview, Details,
/// Stat Growth, Derived Stats and Abilities tabs over one class's draft,
/// with the Used By rail on the right.
library;

import 'dart:async';

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/foundation.dart' show listEquals, mapEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../../editor/editor_state.dart';
import '../../editor/record_editor_scope.dart';
import '../../editor/widgets/dirty_dot.dart';
import '../../editor/widgets/draft_text_field.dart';
import '../../editor/widgets/edit_header.dart';
import '../../editor/widgets/number_draft_field.dart';
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
import 'classes_ability_panel.dart';
import 'classes_derived_stats_tab.dart';
import 'classes_editor_controller.dart';
import 'classes_stat_growth_tab.dart';
import 'classes_providers.dart';

/// The editor of class [id], as a full page and as the editor dialog's
/// body: [RecordEditorScope] around the [EditHeader], the five tabs with
/// their [DirtyDot]s, the [ValidationBanner], the tab body beside the
/// [InspectorRail], and the [SaveBar].
///
/// Back leaves the editor the way it was opened: inside an [EditorDialog]
/// it closes the dialog (through its leave guard), on the editor route it
/// goes to the list (through the route's).
class ClassEditorPage extends ConsumerStatefulWidget {
  const ClassEditorPage(this.id, {super.key});

  final String id;

  /// The five tabs, in 0.1.6's order.
  static const tabLabels = [
    'Overview',
    'Details',
    'Stat Growth',
    'Derived Stats',
    'Abilities',
  ];

  /// 0.1.6's back label (`EditHeader` `backLabel`).
  static const backLabel = 'Character Classes';

  /// The Used By section's title (0.1.6 `usedBySections` label).
  static const npcsSection = 'NPCs';

  /// 0.1.6's helper under Resource Multiplier.
  static const resourceMultiplierHelper =
      'Class-level metadata field — usable as a variable in derived stat '
      'formulas';

  static const duplicateKey = ValueKey('class-duplicate');
  static const addMetadataKey = ValueKey('class-metadata-add');

  /// The Details tab's text and number fields, by draft field name.
  static Key fieldKey(String field) => ValueKey('class-field-$field');

  /// Metadata row [index]'s key field, value field and remove button.
  static Key metadataKeyKey(int index) => ValueKey('class-metadata-$index-key');
  static Key metadataValueKey(int index) =>
      ValueKey('class-metadata-$index-value');
  static Key metadataRemoveKey(int index) =>
      ValueKey('class-metadata-$index-remove');

  /// The dirty dot of tab [label].
  static Key dotKey(String label) => ValueKey('class-dot-$label');

  @override
  ConsumerState<ClassEditorPage> createState() => _ClassEditorPageState();
}

class _ClassEditorPageState extends ConsumerState<ClassEditorPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: ClassEditorPage.tabLabels.length,
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
      (ValidationDomain.classes, widget.id);

  void _onSaveOutcome(SaveOutcome outcome) => ref
      .read(recordValidationProvider(_validationKey).notifier)
      .afterSave(outcome);

  void _back() {
    if (context.findAncestorWidgetOfExactType<EditorDialog>() != null) {
      unawaited(Navigator.of(context).maybePop());
    } else {
      // Through the router as the menu navigates, so go_router stays
      // imported only under `lib/app/shell/`.
      ref.read(routerProvider).go(ShellDomain.classes.location);
    }
  }

  Future<void> _duplicate() async {
    if (_duplicating) return;
    setState(() => _duplicating = true);
    final controller = ref.read(classEditorProvider(widget.id).notifier);
    try {
      final copy = await controller.duplicate();
      if (mounted) openEditor(context, ref, ShellDomain.classes, copy.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(listErrorMessage(error, 'Failed to duplicate class.')),
        ),
      );
    } finally {
      if (mounted) setState(() => _duplicating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = classEditorProvider(widget.id);
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
    final dirty = dirtyTabs<ClassDraft>(state.baseline, state.draft, {
      'details': (a, b) =>
          a.exportKey == b.exportKey &&
          a.description == b.description &&
          a.resourceMultiplier == b.resourceMultiplier &&
          listEquals(a.metadataFields, b.metadataFields),
      'statGrowth': (a, b) =>
          mapEquals(a.statGrowth, b.statGrowth) &&
          mapEquals(a.statGrowthFormulas, b.statGrowthFormulas),
      'derivedStats': (a, b) =>
          mapEquals(a.derivedStatOverrides, b.derivedStatOverrides),
      'abilities': (a, b) => listEquals(a.abilityIds, b.abilityIds),
    });

    final header = EditHeader<ClassDraft>(
      provider: provider,
      backLabel: ClassEditorPage.backLabel,
      onBack: _back,
      displayNameOf: (d) => d.displayName,
      exportKeyOf: (d) => d.exportKey,
      onDisplayNameChanged: controller.setDisplayName,
      onSaveOutcome: _onSaveOutcome,
    );
    const labels = ClassEditorPage.tabLabels;
    final tabRow = Row(
      children: [
        Expanded(
          child: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: labels[0]),
              Tab(
                child: _TabLabel(labels[1], dirty: dirty.contains('details')),
              ),
              Tab(
                child: _TabLabel(
                  labels[2],
                  dirty: dirty.contains('statGrowth'),
                ),
              ),
              Tab(
                child: _TabLabel(
                  labels[3],
                  dirty: dirty.contains('derivedStats'),
                ),
              ),
              Tab(
                child: _TabLabel(labels[4], dirty: dirty.contains('abilities')),
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
            key: ClassEditorPage.duplicateKey,
            icon: const Icon(Icons.content_copy, size: 16),
            label: const Text('Duplicate'),
            onPressed: state.isDirty || state.saving || _duplicating
                ? null
                : () => unawaited(_duplicate()),
          ),
        ),
      ],
    );

    final usedBy = ref.watch(classUsedByProvider(widget.id));
    final rail = InspectorRail(
      loading: !usedBy.hasValue && usedBy.isLoading,
      sections: [
        UsedBySection(
          title: ClassEditorPage.npcsSection,
          domain: ShellDomain.npcs,
          refs: usedBy.value ?? const [],
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
      2 => ClassStatGrowthTab(
        classId: widget.id,
        draft: state.draft,
        blockers: state.blockers,
        issues: issues,
        controller: controller,
      ),
      3 => ClassDerivedStatsTab(
        classId: widget.id,
        draft: state.draft,
        blockers: state.blockers,
        issues: issues,
        controller: controller,
      ),
      _ => ClassAbilityPanel(
        abilityIds: state.draft.abilityIds,
        controller: controller,
      ),
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
    final saveBar = SaveBar<ClassDraft>(
      provider: provider,
      onSaveOutcome: _onSaveOutcome,
    );

    return RecordEditorScope<ClassDraft>(
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
      DirtyDot(key: ClassEditorPage.dotKey(label), visible: dirty),
    ],
  );
}

/// 0.1.6 `OverviewTab`: the name and the description, read-only. Its Used
/// By list is the rail beside every tab.
class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.draft});

  final ClassDraft draft;

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

/// Export key, description and resource multiplier as 0.1.6's Details
/// tab had them, then the class metadata fields (in 0.1.6's Derived Stats
/// tab, moved here by ANVL-195).
class _DetailsTab extends StatelessWidget {
  const _DetailsTab({
    required this.draft,
    required this.blockers,
    required this.issues,
    required this.controller,
  });

  final ClassDraft draft;
  final List<SaveBlocker> blockers;
  final List<ValidationIssue> issues;
  final ClassEditorController controller;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 600),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 360,
            child: DraftTextField(
              key: ClassEditorPage.fieldKey('exportKey'),
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
        DraftTextField(
          key: ClassEditorPage.fieldKey('description'),
          label: 'Description',
          value: draft.description,
          onChanged: controller.setDescription,
          maxLines: 3,
          blockerMessage: blockerText(blockers, 'description'),
          issueMessage: fieldIssueText(issues, 'description'),
        ),
        const SizedBox(height: AnvilSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 240,
            child: NumberDraftField(
              key: ClassEditorPage.fieldKey('resourceMultiplier'),
              label: 'Resource Multiplier',
              value: draft.resourceMultiplier,
              // 0.1.6 saved `parseFloat(resourceMultiplier) || 1`.
              emptyValue: 1,
              helperText: ClassEditorPage.resourceMultiplierHelper,
              issueMessage: fieldIssueText(issues, 'resourceMultiplier'),
              onChanged: (v) => controller.setResourceMultiplier(v ?? 1),
            ),
          ),
        ),
        const SizedBox(height: AnvilSpacing.xl),
        _MetadataFields(
          rows: draft.metadataFields,
          blockers: blockers,
          controller: controller,
        ),
      ],
    ),
  );
}

/// 0.1.6's `MetadataFieldsPanel`: one key / value row per field, Add
/// Field below. A key that is empty, not an identifier or repeated shows
/// the core's blocker under it and keeps Save disabled.
class _MetadataFields extends StatelessWidget {
  const _MetadataFields({
    required this.rows,
    required this.blockers,
    required this.controller,
  });

  final List<ClassMetadataField> rows;
  final List<SaveBlocker> blockers;
  final ClassEditorController controller;

  @override
  Widget build(BuildContext context) {
    final muted = context.text.bodyMedium?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Class Metadata Fields', style: context.text.titleSmall),
        const SizedBox(height: AnvilSpacing.xs),
        Text(
          'Numeric key-value pairs usable as variables in derived stat '
          'formulas.',
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AnvilSpacing.md),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AnvilSpacing.md),
            child: Text('No metadata fields. Add one below.', style: muted),
          )
        else
          for (final (i, row) in rows.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: AnvilSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DraftTextField(
                      key: ClassEditorPage.metadataKeyKey(i),
                      label: 'Key',
                      value: row.fieldKey,
                      onChanged: (v) => controller.setMetadataKey(i, v),
                      style: ForgeType.code(size: 13.6),
                      blockerMessage: blockerText(
                        blockers,
                        'metadataFields[$i].fieldKey',
                      ),
                    ),
                  ),
                  const SizedBox(width: AnvilSpacing.sm),
                  SizedBox(
                    width: 120,
                    child: NumberDraftField(
                      key: ClassEditorPage.metadataValueKey(i),
                      label: 'Value',
                      value: row.value,
                      // 0.1.6 saved `parseFloat(value) || 0`.
                      emptyValue: 0,
                      onChanged: (v) => controller.setMetadataValue(i, v ?? 0),
                    ),
                  ),
                  const SizedBox(width: AnvilSpacing.xs),
                  IconButton(
                    key: ClassEditorPage.metadataRemoveKey(i),
                    tooltip: 'Remove field',
                    color: context.colors.error,
                    icon: const Icon(Icons.delete, size: 18),
                    onPressed: () => controller.removeMetadataField(i),
                  ),
                ],
              ),
            ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: ClassEditorPage.addMetadataKey,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Field'),
            onPressed: controller.addMetadataField,
          ),
        ),
      ],
    );
  }
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
              ? 'Class not found.'
              : 'Failed to load class.',
          key: const ValueKey('class-load-error'),
          style: context.text.bodyMedium?.copyWith(color: context.colors.error),
        ),
        const SizedBox(height: AnvilSpacing.md),
        TextButton(onPressed: onBack, child: const Text('Back to Classes')),
      ],
    ),
  );
}
