/// The item editor (0.1.6 `ItemEditorPage.tsx`) on the shared editor
/// scaffold: header, the Overview / Details / Custom Fields tabs, the
/// record's validation, the save bar and the Used By rail.
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../../editor/editor_state.dart';
import '../../editor/record_editor_scope.dart';
import '../../editor/widgets/custom_fields_panel.dart';
import '../../editor/widgets/dirty_dot.dart';
import '../../editor/widgets/draft_text_field.dart';
import '../../editor/widgets/edit_header.dart';
import '../../editor/widgets/record_validation.dart';
import '../../editor/widgets/save_bar.dart';
import '../../editor/widgets/validation_banner.dart';
import '../../shell/app_router.dart' show routerProvider;
import '../../shell/shell_domain.dart';
import '../../theme/anvil_colors.dart';
import '../../theme/anvil_metrics.dart';
import '../../widgets/inspector_rail.dart';
import 'item_meta_providers.dart';
import 'items_editor_controller.dart';

import 'package:anvil/app/editor/widgets/draft_picker.dart';

/// The editor tabs, 0.1.6's three.
enum ItemEditorTab {
  overview('Overview'),
  details('Details'),
  customFields('Custom Fields');

  const ItemEditorTab(this.label);

  final String label;

  Key get key => ValueKey('item-tab-$name');
}

/// 0.1.6's `maxWidth: 680` on the tab panels.
const _panelMaxWidth = 680.0;

/// 0.1.6's `maxWidth: 360` on the export key field.
const _exportKeyMaxWidth = 360.0;

/// 0.1.6's `fontSize: '0.85rem'` on the export key input.
const _exportKeyFontSize = 13.6;

/// Edits item [id]. In the full-page mode it fills the route and scrolls
/// its tab body between the header and the save bar; in the editor dialog,
/// which already scrolls, it lays out at its natural height.
///
/// [onBack] leaves the editor; by default it pops the editor dialog (the
/// dialog's leave guard runs) or goes to the items list (the route's
/// leave guard runs).
class ItemEditorPage extends ConsumerStatefulWidget {
  const ItemEditorPage(this.id, {super.key, this.onBack});

  final String id;
  final VoidCallback? onBack;

  @override
  ConsumerState<ItemEditorPage> createState() => _ItemEditorPageState();
}

class _ItemEditorPageState extends ConsumerState<ItemEditorPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: ItemEditorTab.values.length,
    vsync: this,
  )..addListener(_onTab);

  void _onTab() {
    if (!_tabs.indexIsChanging) setState(() {});
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  RecordValidationKey get _validationKey => (ValidationDomain.items, widget.id);

  void _back() {
    if (widget.onBack case final onBack?) return onBack();
    if (ModalRoute.of(context) is PopupRoute) {
      Navigator.of(context).maybePop();
    } else {
      // Through the router as the menu navigates, so go_router stays
      // imported only under `lib/app/shell/`.
      ref.read(routerProvider).go(ShellDomain.items.location);
    }
  }

  void _onSaveOutcome(SaveOutcome outcome) => ref
      .read(recordValidationProvider(_validationKey).notifier)
      .afterSave(outcome);

  @override
  Widget build(BuildContext context) {
    final provider = itemsEditorProvider(widget.id);
    final async = ref.watch(provider);
    return RecordEditorScope<ItemDraft>(
      provider: provider,
      onSaveOutcome: _onSaveOutcome,
      child: switch (async) {
        AsyncValue(:final EditorState<ItemDraft> value) => _editor(
          context,
          value,
        ),
        AsyncError(:final error) => _LoadFailed(
          message: error is RecordNotFound
              ? 'Item not found.'
              : 'Failed to load item.',
          onBack: _back,
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _editor(BuildContext context, EditorState<ItemDraft> state) {
    final provider = itemsEditorProvider(widget.id);
    final controller = ref.read(provider.notifier);
    final issues = ref.watch(recordValidationProvider(_validationKey));
    final dirty = dirtyTabs<ItemDraft>(state.baseline, state.draft, {
      ItemEditorTab.details.name: (a, b) =>
          a.exportKey == b.exportKey &&
          a.description == b.description &&
          a.itemCategoryId == b.itemCategoryId &&
          a.rarityId == b.rarityId,
      ItemEditorTab.customFields.name: (a, b) =>
          mapEquals(a.customFieldValues, b.customFieldValues),
    });
    final tab = ItemEditorTab.values[_tabs.index];

    final header = EditHeader<ItemDraft>(
      provider: provider,
      backLabel: ShellDomain.items.label,
      onBack: _back,
      displayNameOf: (d) => d.displayName,
      exportKeyOf: (d) => d.exportKey,
      onDisplayNameChanged: controller.setDisplayName,
      onSaveOutcome: _onSaveOutcome,
    );
    final tabBar = TabBar(
      controller: _tabs,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      tabs: [
        for (final t in ItemEditorTab.values)
          Tab(
            key: t.key,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t.label),
                DirtyDot(
                  key: ValueKey('item-tab-dot-${t.name}'),
                  visible: dirty.contains(t.name),
                ),
              ],
            ),
          ),
      ],
    );
    final panel = switch (tab) {
      ItemEditorTab.overview => _OverviewPanel(draft: state.draft),
      ItemEditorTab.details => _DetailsPanel(
        state: state,
        issues: issues,
        controller: controller,
      ),
      ItemEditorTab.customFields => _CustomFieldsTab(
        draft: state.draft,
        issues: issues,
        controller: controller,
      ),
    };
    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ValidationBanner(issues),
              Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _panelMaxWidth),
                  child: panel,
                ),
              ),
            ],
          ),
        ),
        _UsedByRail(id: widget.id),
      ],
    );
    final saveBar = SaveBar<ItemDraft>(
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
              tabBar,
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
            tabBar,
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

  final ItemDraft draft;

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
          key: const ValueKey('item-overview-name'),
          style: context.text.titleLarge,
        ),
        const SizedBox(height: AnvilSpacing.lg),
        Text('DESCRIPTION', style: caption),
        const SizedBox(height: AnvilSpacing.xs),
        Text(
          draft.description.isEmpty
              ? 'No description provided.'
              : draft.description,
          key: const ValueKey('item-overview-description'),
          style: context.text.bodyLarge?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Export key, category, rarity and description (0.1.6's Details tab).
class _DetailsPanel extends ConsumerWidget {
  const _DetailsPanel({
    required this.state,
    required this.issues,
    required this.controller,
  });

  static const exportKeyKey = ValueKey('item-export-key');
  static const categoryKey = ValueKey('item-category');
  static const rarityKey = ValueKey('item-rarity');
  static const descriptionKey = ValueKey('item-description');

  final EditorState<ItemDraft> state;
  final List<ValidationIssue> issues;
  final ItemEditorController controller;

  /// The save blocker on [field], else its validation issue.
  String? _error(String field) =>
      blockerText(state.blockers, field) ?? fieldIssueText(issues, field);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = state.draft;
    final categories = ref.watch(itemCategoriesProvider).value ?? const [];
    final rarities = ref.watch(itemRaritiesProvider).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _exportKeyMaxWidth),
            child: DraftTextField(
              key: exportKeyKey,
              label: 'Export Key',
              value: draft.exportKey,
              hintText: 'export-key',
              onChanged: controller.setExportKey,
              blockerMessage: blockerText(state.blockers, 'exportKey'),
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DraftPicker<String?>(
                key: categoryKey,
                label: 'Category',
                isRequired: true,
                value: draft.itemCategoryId.isEmpty
                    ? null
                    : draft.itemCategoryId,
                options: [
                  for (final c in categories)
                    (value: c.id, label: c.displayName),
                ],
                errorText: _error('itemCategoryId'),
                onChanged: (id) {
                  if (id != null) controller.setCategory(id);
                },
              ),
            ),
            const SizedBox(width: AnvilSpacing.md),
            Expanded(
              child: DraftPicker<String?>(
                key: rarityKey,
                label: 'Rarity',
                isRequired: true,
                value: draft.rarityId.isEmpty ? null : draft.rarityId,
                options: [
                  for (final r in rarities) (value: r.id, label: r.displayName),
                ],
                errorText: _error('rarityId'),
                onChanged: (id) {
                  if (id != null) controller.setRarity(id);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AnvilSpacing.lg),
        DraftTextField(
          key: descriptionKey,
          label: 'Description',
          value: draft.description,
          maxLines: 4,
          onChanged: controller.setDescription,
          issueMessage: fieldIssueText(issues, 'description'),
        ),
      ],
    );
  }
}

/// The custom fields of the draft's category.
class _CustomFieldsTab extends ConsumerWidget {
  const _CustomFieldsTab({
    required this.draft,
    required this.issues,
    required this.controller,
  });

  final ItemDraft draft;
  final List<ValidationIssue> issues;
  final ItemEditorController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryId = draft.itemCategoryId;
    final definitions = categoryId.isEmpty
        ? const <CustomFieldDefinition>[]
        : ref.watch(itemCustomFieldDefinitionsProvider(categoryId)).value;
    return CustomFieldsPanel(
      scope: CustomFieldScope.itemCategory,
      definitions: definitions,
      values: draft.customFieldValues,
      issues: issues,
      onChanged: controller.setCustomFieldValue,
    );
  }
}

/// The rail of the recipes (as output or ingredient) and loot tables that
/// use the item, re-read after every write.
class _UsedByRail extends ConsumerWidget {
  const _UsedByRail({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usedBy = ref.watch(itemUsedByProvider(id));
    final value = usedBy.value;
    return InspectorRail(
      loading: value == null && usedBy.isLoading,
      sections: [
        UsedBySection(
          title: 'Crafting Recipes',
          domain: ShellDomain.recipes,
          refs: value?.recipes ?? const [],
        ),
        UsedBySection(
          title: 'Loot Tables',
          domain: ShellDomain.lootTables,
          refs: value?.lootTables ?? const [],
        ),
      ],
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
        ForgeErrorCard(
          key: const ValueKey('item-load-error'),
          message: message,
        ),
        const SizedBox(height: AnvilSpacing.md),
        TextButton(onPressed: onBack, child: const Text('Back to Items')),
      ],
    ),
  );
}
