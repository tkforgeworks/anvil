/// The NPC editor (0.1.6 `NpcEditorPage.tsx`) on the shared editor
/// scaffold: header, the Overview / Details tabs, the record's validation
/// and the save bar. NPCs have no Used By, so there is no inspector rail.
library;

import 'dart:async';

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../../editor/editor_state.dart';
import '../../editor/record_editor_scope.dart';
import '../../editor/widgets/custom_fields_panel.dart';
import '../../editor/widgets/dirty_dot.dart';
import '../../editor/widgets/draft_picker.dart';
import '../../editor/widgets/draft_text_field.dart';
import '../../editor/widgets/edit_header.dart';
import '../../editor/widgets/field_messages.dart';
import '../../editor/widgets/record_validation.dart';
import '../../editor/widgets/save_bar.dart';
import '../../editor/widgets/validation_banner.dart';
import '../../lists/record_list_controller.dart' show listErrorMessage;
import '../../shell/app_router.dart' show routerProvider;
import '../../shell/open_editor.dart';
import '../../shell/shell_domain.dart';
import '../../theme/anvil_colors.dart';
import '../../theme/anvil_metrics.dart';
import 'npcs_editor_controller.dart';
import 'npcs_editor_sections.dart';
import 'npcs_providers.dart';

/// The editor tabs, 0.1.6's two.
enum NpcEditorTab {
  overview('Overview'),
  details('Details');

  const NpcEditorTab(this.label);

  final String label;

  Key get key => ValueKey('npc-tab-$name');
}

/// 0.1.6's `maxWidth: 900` on the Details stack.
const _detailsMaxWidth = 900.0;

/// 0.1.6's `maxWidth: 760` on the type picker and the description.
const _fieldMaxWidth = 760.0;

/// 0.1.6's `maxWidth: 360` on the export key field.
const _exportKeyMaxWidth = 360.0;

/// 0.1.6's `fontSize: '0.85rem'` on the export key input.
const _exportKeyFontSize = 13.6;

/// Edits NPC [id]. In the full-page mode it fills the route and scrolls
/// its tab body between the header and the save bar; in the editor dialog,
/// which already scrolls, it lays out at its natural height.
///
/// [onBack] leaves the editor; by default it pops the editor dialog (the
/// dialog's leave guard runs) or goes to the NPC list (the route's leave
/// guard runs).
class NpcEditorPage extends ConsumerStatefulWidget {
  const NpcEditorPage(this.id, {super.key, this.onBack});

  final String id;
  final VoidCallback? onBack;

  static const duplicateKey = ValueKey('npc-duplicate');
  static const exportKeyKey = ValueKey('npc-export-key');
  static const typeKey = ValueKey('npc-type');
  static const descriptionKey = ValueKey('npc-description');

  @override
  ConsumerState<NpcEditorPage> createState() => _NpcEditorPageState();
}

class _NpcEditorPageState extends ConsumerState<NpcEditorPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: NpcEditorTab.values.length,
    vsync: this,
  )..addListener(_onTab);
  var _duplicating = false;

  void _onTab() {
    if (!_tabs.indexIsChanging) setState(() {});
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  RecordValidationKey get _validationKey => (ValidationDomain.npcs, widget.id);

  void _back() {
    if (widget.onBack case final onBack?) return onBack();
    if (ModalRoute.of(context) is PopupRoute) {
      unawaited(Navigator.of(context).maybePop());
    } else {
      // Through the router as the menu navigates, so go_router stays
      // imported only under `lib/app/shell/`.
      ref.read(routerProvider).go(ShellDomain.npcs.location);
    }
  }

  void _onSaveOutcome(SaveOutcome outcome) => ref
      .read(recordValidationProvider(_validationKey).notifier)
      .afterSave(outcome);

  Future<void> _duplicate() async {
    if (_duplicating) return;
    setState(() => _duplicating = true);
    final controller = ref.read(npcEditorProvider(widget.id).notifier);
    try {
      final copy = await controller.duplicate();
      if (mounted) openEditor(context, ref, ShellDomain.npcs, copy.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(listErrorMessage(error, 'Failed to duplicate NPC.')),
        ),
      );
    } finally {
      if (mounted) setState(() => _duplicating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = npcEditorProvider(widget.id);
    final async = ref.watch(provider);
    return RecordEditorScope<NpcDraft>(
      provider: provider,
      onSaveOutcome: _onSaveOutcome,
      child: switch (async) {
        AsyncValue(:final EditorState<NpcDraft> value) => _editor(
          context,
          value,
        ),
        AsyncError(:final error) => _LoadFailed(
          message: error is RecordNotFound
              ? 'NPC not found.'
              : 'Failed to load NPC.',
          onBack: _back,
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _editor(BuildContext context, EditorState<NpcDraft> state) {
    final provider = npcEditorProvider(widget.id);
    final controller = ref.read(provider.notifier);
    final issues = ref.watch(recordValidationProvider(_validationKey));
    final dirty = dirtyTabs<NpcDraft>(state.baseline, state.draft, {
      // Everything but the name, which the header edits.
      NpcEditorTab.details.name: (a, b) =>
          a.copyWith(displayName: '') == b.copyWith(displayName: ''),
    });
    final tab = NpcEditorTab.values[_tabs.index];

    final header = EditHeader<NpcDraft>(
      provider: provider,
      backLabel: ShellDomain.npcs.label,
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
              for (final t in NpcEditorTab.values)
                Tab(
                  key: t.key,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(t.label),
                      DirtyDot(
                        key: ValueKey('npc-tab-dot-${t.name}'),
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
            key: NpcEditorPage.duplicateKey,
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
      NpcEditorTab.overview => _OverviewPanel(draft: state.draft),
      NpcEditorTab.details => _DetailsPanel(
        state: state,
        issues: issues,
        controller: controller,
      ),
    };
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValidationBanner(issues),
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _detailsMaxWidth),
            child: panel,
          ),
        ),
      ],
    );
    final saveBar = SaveBar<NpcDraft>(
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

/// 0.1.6's `OverviewTab`: the name and the description, read-only.
class _OverviewPanel extends StatelessWidget {
  const _OverviewPanel({required this.draft});

  final NpcDraft draft;

  @override
  Widget build(BuildContext context) {
    final caption = context.text.labelSmall?.copyWith(
      color: context.anvil.textDisabled,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('NAME', style: caption),
        Text(
          draft.displayName.isEmpty ? '—' : draft.displayName,
          key: const ValueKey('npc-overview-name'),
          style: context.text.titleLarge,
        ),
        const SizedBox(height: AnvilSpacing.lg),
        Text('DESCRIPTION', style: caption),
        const SizedBox(height: AnvilSpacing.xs),
        Text(
          draft.description.isEmpty
              ? 'No description provided.'
              : draft.description,
          key: const ValueKey('npc-overview-description'),
          style: context.text.bodyLarge?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 0.1.6's Details tab, in its order: export key, NPC type, description,
/// then the Classes, Stat Block, Abilities, Loot Table and Type Fields
/// sections between dividers.
class _DetailsPanel extends ConsumerWidget {
  const _DetailsPanel({
    required this.state,
    required this.issues,
    required this.controller,
  });

  final EditorState<NpcDraft> state;
  final List<ValidationIssue> issues;
  final NpcEditorController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = state.draft;
    final types = ref.watch(npcTypesProvider).value ?? const [];
    final typeMessages = fieldMessages(
      blockerText(state.blockers, 'npcTypeId'),
      fieldIssue(issues, 'npcTypeId'),
    );
    final typeName = types
        .where((t) => t.id == draft.npcTypeId)
        .firstOrNull
        ?.displayName;
    const gap = SizedBox(height: AnvilSpacing.lg);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _exportKeyMaxWidth),
            child: DraftTextField(
              key: NpcEditorPage.exportKeyKey,
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
        gap,
        _Bounded(
          child: DraftPicker<String?>(
            key: NpcEditorPage.typeKey,
            label: 'NPC Type',
            isRequired: true,
            value: draft.npcTypeId.isEmpty ? null : draft.npcTypeId,
            options: [
              for (final t in types) (value: t.id, label: t.displayName),
            ],
            errorText: typeMessages.error,
            helperText: typeMessages.helper,
            helperIsWarning: typeMessages.warning,
            onChanged: (id) {
              if (id != null) unawaited(controller.setNpcType(id));
            },
          ),
        ),
        gap,
        _Bounded(
          child: DraftTextField(
            key: NpcEditorPage.descriptionKey,
            label: 'Description',
            value: draft.description,
            maxLines: 4,
            onChanged: controller.setDescription,
            issueMessage: fieldIssueText(issues, 'description'),
          ),
        ),
        gap,
        const Divider(height: 1),
        NpcSection(
          title: 'Classes',
          subtitle:
              'Assign one or more character classes at specified levels. '
              'Stat values from all assigned classes combine additively.',
          child: ClassAssignmentsSection(
            state: state,
            issues: issues,
            controller: controller,
          ),
        ),
        const Divider(height: 1),
        NpcSection(
          title: 'Stat Block',
          subtitle:
              'Inherited values are summed from assigned classes at their '
              'levels. Enter an override to replace the inherited value for '
              'any stat.',
          child: StatBlockSection(draft: draft, controller: controller),
        ),
        const Divider(height: 1),
        NpcSection(
          title: 'Abilities',
          subtitle: 'Assign abilities this NPC has access to.',
          child: AbilityAssignmentsSection(
            state: state,
            issues: issues,
            controller: controller,
          ),
        ),
        const Divider(height: 1),
        NpcSection(
          title: 'Loot Table',
          subtitle:
              'Assign a loot table that drops when this NPC is defeated. '
              'The entries below are read-only.',
          child: LootTableSection(
            draft: draft,
            issues: issues,
            controller: controller,
          ),
        ),
        const Divider(height: 1),
        NpcSection(
          title: 'Type Fields',
          subtitle: typeName ?? 'Selected NPC type',
          child: _TypeFields(
            draft: draft,
            issues: issues,
            controller: controller,
          ),
        ),
      ],
    );
  }
}

/// 0.1.6's `maxWidth: 760`.
class _Bounded extends StatelessWidget {
  const _Bounded({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _fieldMaxWidth),
      child: child,
    ),
  );
}

/// The custom fields of the draft's type.
class _TypeFields extends ConsumerWidget {
  const _TypeFields({
    required this.draft,
    required this.issues,
    required this.controller,
  });

  final NpcDraft draft;
  final List<ValidationIssue> issues;
  final NpcEditorController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeId = draft.npcTypeId;
    final definitions = typeId.isEmpty
        ? const <CustomFieldDefinition>[]
        : ref.watch(npcCustomFieldDefinitionsProvider(typeId)).value;
    return CustomFieldsPanel(
      scope: CustomFieldScope.npcType,
      definitions: definitions,
      values: draft.customFieldValues,
      issues: issues,
      onChanged: controller.setCustomFieldValue,
    );
  }
}

/// 0.1.6's not-found view: the error and a way back.
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
        ForgeErrorCard(key: const ValueKey('npc-load-error'), message: message),
        const SizedBox(height: AnvilSpacing.md),
        TextButton(onPressed: onBack, child: const Text('Back to NPCs')),
      ],
    ),
  );
}
