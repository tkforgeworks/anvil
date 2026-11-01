/// The Project Settings dialog (design §13.5): 0.1.6's
/// `ProjectSettingsModal.tsx` with its four tabs. General, Stats & Formulas
/// and Crafting edit a buffer that Save commits in one transaction
/// (ANVL-121); Custom Fields writes each change at once (ANVL-123).
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../../editor/widgets/draft_text_field.dart';
import '../../providers.dart';
import '../../theme/anvil_metrics.dart';
import 'custom_fields_section.dart';
import 'derived_stat_section.dart';
import 'meta_list_section.dart';
import 'project_settings_controller.dart';
import 'rarity_section.dart';

/// The dialog's tabs, in order. 0.1.6 could open only on Custom Fields
/// (`modalOptions.initialTab: 'custom-fields'`); 0.2.0 opens on any.
enum ProjectSettingsTab { general, statsAndFormulas, crafting, customFields }

/// Opens the dialog on [initialTab] and completes when it closes. Does
/// nothing when no project is open, as 0.1.6's modal rendered nothing
/// without an active project.
Future<void> showProjectSettingsDialog(
  BuildContext context,
  WidgetRef ref, {
  ProjectSettingsTab initialTab = ProjectSettingsTab.general,
}) async {
  if (ref.read(projectSessionProvider) == null) return;
  await showDialog<void>(
    context: context,
    builder: (_) => ProjectSettingsDialog(initialTab: initialTab),
  );
}

/// The dialog. Cancel, the close button, Escape and a click outside all
/// discard the buffered edits without a prompt; the controller is
/// auto-disposed with the dialog. Save is enabled while the buffer is
/// dirty and breaks no rule, and closes the dialog once the save landed; a
/// failed save shows its message and keeps the dialog and the edits.
class ProjectSettingsDialog extends ConsumerWidget {
  const ProjectSettingsDialog({
    super.key,
    this.initialTab = ProjectSettingsTab.general,
  });

  /// 0.1.6's `maxWidth: 700` for the buffered tabs' content.
  static const contentMaxWidth = 700.0;

  final ProjectSettingsTab initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(projectSettingsProvider);
    final s = async.value;
    final saving = s?.saving ?? false;
    final height = MediaQuery.sizeOf(context).height * 0.85;

    Widget buffered(Widget Function(ProjectSettingsState s) build) {
      if (s == null) {
        return Padding(
          padding: const EdgeInsets.all(AnvilSpacing.lg),
          child: async.hasError
              ? ForgeErrorCard(message: '${async.error}')
              : Text(
                  'Loading project settings...',
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
        );
      }
      return _TabScroll(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: contentMaxWidth),
          child: build(s),
        ),
      );
    }

    return PopScope(
      canPop: !saving,
      child: Dialog(
        insetPadding: const EdgeInsets.all(AnvilSpacing.xl),
        constraints: const BoxConstraints(
          maxWidth: AnvilLayout.editorDialogMaxWidth,
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: double.infinity,
          height: height,
          child: DefaultTabController(
            length: ProjectSettingsTab.values.length,
            initialIndex: initialTab.index,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AnvilSpacing.lg,
                    AnvilSpacing.sm,
                    AnvilSpacing.sm,
                    0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Project Settings',
                          style: context.text.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: saving
                            ? null
                            : () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  padding: EdgeInsets.symmetric(horizontal: AnvilSpacing.md),
                  tabs: [
                    Tab(text: 'General'),
                    Tab(text: 'Stats & Formulas'),
                    Tab(text: 'Crafting'),
                    Tab(text: 'Custom Fields'),
                  ],
                ),
                const Divider(height: 1),
                Expanded(
                  child: TabBarView(
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      buffered((s) => _GeneralTab(state: s)),
                      buffered((s) => _StatsTab(state: s)),
                      buffered((s) => _CraftingTab(state: s)),
                      const _TabScroll(child: CustomFieldsSection()),
                    ],
                  ),
                ),
                _Footer(state: s),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabScroll extends StatelessWidget {
  const _TabScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(AnvilSpacing.lg),
    child: Align(alignment: Alignment.topLeft, child: child),
  );
}

/// The save failure, the first rule the buffer breaks, Cancel and Save.
class _Footer extends ConsumerWidget {
  const _Footer({required this.state});

  final ProjectSettingsState? state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = state;
    final controller = ref.read(projectSettingsProvider.notifier);
    final saving = s?.saving ?? false;
    final error = s?.error;
    final blockers = s == null || !s.isDirty ? const <String>[] : s.blockers;

    Future<void> save() async {
      final saved = await controller.save();
      if (saved && context.mounted) Navigator.of(context).pop();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AnvilSpacing.lg,
        12,
        AnvilSpacing.lg,
        AnvilSpacing.md,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.colors.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) ...[
            Semantics(
              liveRegion: true,
              child: ForgeErrorCard(
                key: const ValueKey('project-settings-error'),
                message: error,
                onRetry: controller.clearError,
                retryLabel: 'Dismiss',
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: blockers.isEmpty
                    ? const SizedBox.shrink()
                    : Text(
                        blockers.first,
                        key: const ValueKey('project-settings-blocker'),
                        style: context.text.bodyMedium?.copyWith(
                          color: context.forge.warning,
                        ),
                      ),
              ),
              TextButton(
                key: const ValueKey('project-settings-cancel'),
                onPressed: saving ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: AnvilSpacing.sm),
              FilledButton(
                key: const ValueKey('project-settings-save'),
                onPressed: s != null && s.canSave ? save : null,
                child: Text(saving ? 'Saving…' : 'Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A heading over one General-tab setting (0.1.6 `subtitle2`).
class _SettingLabel extends StatelessWidget {
  const _SettingLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AnvilSpacing.sm),
    child: Text(text, style: context.text.titleSmall),
  );
}

class _GeneralTab extends ConsumerWidget {
  const _GeneralTab({required this.state});

  final ProjectSettingsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final header = ref.watch(projectSettingsHeaderProvider);
    final c = ref.read(projectSettingsProvider.notifier);
    final secondary = context.text.bodySmall?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    const gap = SizedBox(height: AnvilSpacing.lg);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SettingLabel('Project'),
        Text(
          header.projectName,
          key: const ValueKey('settings-project-name'),
          style: context.text.bodyMedium,
        ),
        const SizedBox(height: AnvilSpacing.md),
        const _SettingLabel('Project File'),
        Text(
          header.location,
          key: const ValueKey('settings-project-file'),
          style: ForgeType.code(
            size: 12.8,
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const Divider(height: AnvilSpacing.xl * 1.5),
        const _SettingLabel('Game Title'),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 360,
            child: DraftTextField(
              key: const ValueKey('settings-game-title'),
              value: state.gameTitle,
              onChanged: c.setGameTitle,
              blockerMessage: state.gameTitle.trim().isEmpty
                  ? 'Game title is required.'
                  : null,
            ),
          ),
        ),
        gap,
        const _SettingLabel('Max Level'),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 100,
            child: DraftTextField(
              key: const ValueKey('settings-max-level'),
              value: state.maxLevelText,
              onChanged: c.setMaxLevelText,
            ),
          ),
        ),
        gap,
        const _SettingLabel('Soft-Delete Reference Severity'),
        Text(
          'Controls how the validation engine treats references to '
          'soft-deleted (archived) records.',
          style: secondary,
        ),
        const SizedBox(height: 12),
        RadioGroup<SoftDeleteReferenceSeverity>(
          groupValue: state.severity,
          onChanged: (v) {
            if (v != null) c.setSeverity(v);
          },
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RadioListTile<SoftDeleteReferenceSeverity>(
                key: ValueKey('settings-severity-warning'),
                value: SoftDeleteReferenceSeverity.warning,
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('Warning'),
                subtitle: Text(
                  'Flag references to archived records, but allow export.',
                ),
              ),
              RadioListTile<SoftDeleteReferenceSeverity>(
                key: ValueKey('settings-severity-error'),
                value: SoftDeleteReferenceSeverity.error,
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('Error'),
                subtitle: Text(
                  'Block export when references to archived records exist.',
                ),
              ),
            ],
          ),
        ),
        const Divider(height: AnvilSpacing.xl * 1.5),
        RaritySection(
          rows: state.rarities.toList(),
          onAdd: (input) async => c.addRarity(input),
          onUpdate: (id, input) async => c.updateRarity(id, input),
          onDelete: (id) => c.tryDelete(ProjectSettingsList.rarities, id),
          onMove: (from, to) async {
            c.moveRow(ProjectSettingsList.rarities, from, to);
            return null;
          },
        ),
      ],
    );
  }
}

/// A buffered display name + export key list.
class _PlainSection extends ConsumerWidget {
  const _PlainSection({
    required this.state,
    required this.list,
    required this.title,
    required this.description,
  });

  final ProjectSettingsState state;
  final ProjectSettingsList list;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(projectSettingsProvider.notifier);
    return MetaListSection(
      key: ValueKey('section-${list.name}'),
      title: title,
      singularName: list.singularName,
      description: description,
      rows: [
        for (final r in state.plain(list).toList())
          MetaListRow(
            id: r.id,
            displayName: r.displayName,
            exportKey: r.exportKey,
          ),
      ],
      onAdd: (input) async => c.addMetaRow(list, input),
      onUpdate: (id, input) async => c.updateMetaRow(list, id, input),
      onDelete: (id) => c.tryDelete(list, id),
      onMove: (from, to) async {
        c.moveRow(list, from, to);
        return null;
      },
    );
  }
}

class _StatsTab extends ConsumerWidget {
  const _StatsTab({required this.state});

  final ProjectSettingsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(projectSettingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PlainSection(
          state: state,
          list: ProjectSettingsList.stats,
          title: 'Primary Stats',
          description:
              'Stats used in class growth curves and derived stat formulas.',
        ),
        const Divider(height: AnvilSpacing.xl * 2),
        DerivedStatSection(
          rows: state.derivedStats.toList(),
          onAdd: (input) async => c.addDerivedStat(input),
          onUpdate: (id, input) async => c.updateDerivedStat(id, input),
          onDelete: (id) => c.tryDelete(ProjectSettingsList.derivedStats, id),
          onMove: (from, to) async {
            c.moveRow(ProjectSettingsList.derivedStats, from, to);
            return null;
          },
        ),
      ],
    );
  }
}

class _CraftingTab extends StatelessWidget {
  const _CraftingTab({required this.state});

  final ProjectSettingsState state;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _PlainSection(
        state: state,
        list: ProjectSettingsList.craftingStations,
        title: 'Crafting Stations',
        description: 'Stations that recipes can require.',
      ),
      const Divider(height: AnvilSpacing.xl * 2),
      _PlainSection(
        state: state,
        list: ProjectSettingsList.craftingSpecializations,
        title: 'Crafting Specializations',
        description: 'Specializations that recipes can require.',
      ),
    ],
  );
}
