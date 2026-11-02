/// The recipe editor (0.1.6 `RecipeEditorPage.tsx`) on the shared editor
/// scaffold (ANVL-187).
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/foundation.dart';
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
import '../../shell/app_router.dart';
import '../../shell/shell_domain.dart';
import '../../theme/anvil_colors.dart';
import '../../theme/anvil_metrics.dart';
import 'recipes_editor_controller.dart';
import 'recipes_lookups.dart';

import 'package:anvil/app/editor/widgets/draft_picker.dart';
import 'package:anvil/app/editor/widgets/number_draft_field.dart';
import 'package:anvil/app/editor/widgets/field_messages.dart';

/// The editor of recipe [id]: the header with the name, undo, redo and
/// Save; the Overview, Details and Ingredients tabs as 0.1.6 had them, with
/// dirty dots on Details and Ingredients; the validation banner after a
/// save; and the save bar while dirty. Recipes have no Used By, so there is
/// no inspector rail.
///
/// The same widget is the full-page route and the body of the modal editor
/// dialog. With a bounded height (the route) the tab body scrolls between
/// the header and the save bar; with an unbounded one (the dialog's scroll
/// view) everything is laid out in one column.
class RecipeEditorPage extends ConsumerStatefulWidget {
  const RecipeEditorPage({super.key, required this.id});

  final String id;

  /// 0.1.6's tab labels.
  static const tabLabels = ['Overview', 'Details', 'Ingredients'];

  /// 0.1.6's back label (`EditHeader` `backLabel`).
  static const backLabel = 'Crafting Recipes';

  @override
  ConsumerState<RecipeEditorPage> createState() => _RecipeEditorPageState();
}

class _RecipeEditorPageState extends ConsumerState<RecipeEditorPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: RecipeEditorPage.tabLabels.length,
    vsync: this,
  )..addListener(_onTabChanged);

  RecordValidationKey get _validationKey =>
      (ValidationDomain.recipes, widget.id);

  void _onTabChanged() {
    if (mounted) setState(() {});
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

  /// Closes the dialog in the modal editing mode, else goes to the list
  /// route, whose `onExit` guard asks about unsaved changes.
  void _back() {
    if (ModalRoute.of(context) is PopupRoute) {
      Navigator.of(context).maybePop();
    } else {
      ref.read(routerProvider).go(ShellDomain.recipes.location);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = recipeEditorProvider(widget.id);
    final async = ref.watch(provider);
    final issues = ref.watch(recordValidationProvider(_validationKey));
    final lookups =
        ref.watch(recipeLookupsProvider).value ?? RecipeLookups.empty;
    final state = async.value;
    if (state == null) {
      if (async.error case final error?) {
        return _LoadFailed(
          message: error is RecordNotFound
              ? 'Recipe not found.'
              : error.toString(),
          onBack: _back,
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    final controller = ref.read(provider.notifier);
    final dirty = dirtyTabs<RecipeDraft>(state.baseline, state.draft, {
      'details': (a, b) =>
          a.exportKey == b.exportKey &&
          a.description == b.description &&
          a.outputItemId == b.outputItemId &&
          a.outputQuantity == b.outputQuantity &&
          a.craftingStationId == b.craftingStationId &&
          a.craftingSpecializationId == b.craftingSpecializationId,
      'ingredients': (a, b) => listEquals(a.ingredients, b.ingredients),
    });

    final header = EditHeader<RecipeDraft>(
      provider: provider,
      backLabel: RecipeEditorPage.backLabel,
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
        const Tab(key: ValueKey('recipe-tab-overview'), text: 'Overview'),
        Tab(
          key: const ValueKey('recipe-tab-details'),
          child: _TabLabel('Details', dirty: dirty.contains('details')),
        ),
        Tab(
          key: const ValueKey('recipe-tab-ingredients'),
          child: _TabLabel('Ingredients', dirty: dirty.contains('ingredients')),
        ),
      ],
    );
    final draft = state.draft;
    final body = Padding(
      padding: const EdgeInsets.only(top: AnvilSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ValidationBanner(issues),
          if (_referencesDeletedItem(draft, lookups))
            const _Notice(
              key: ValueKey('recipe-deleted-reference-warning'),
              message:
                  'This recipe references a soft-deleted item. Validation '
                  'will flag this recipe.',
            ),
          switch (_tabs.index) {
            0 => _OverviewTab(draft: draft),
            1 => _DetailsTab(
              state: state,
              controller: controller,
              issues: issues,
              lookups: lookups,
            ),
            _ => _IngredientsTab(
              state: state,
              controller: controller,
              lookups: lookups,
            ),
          },
        ],
      ),
    );
    final saveBar = SaveBar<RecipeDraft>(
      provider: provider,
      onSaveOutcome: _onSaveOutcome,
    );

    return RecordEditorScope<RecipeDraft>(
      provider: provider,
      onSaveOutcome: _onSaveOutcome,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.hasBoundedHeight) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                tabBar,
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: AnvilSpacing.lg),
                    child: body,
                  ),
                ),
                saveBar,
              ],
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              tabBar,
              body,
              const SizedBox(height: AnvilSpacing.lg),
              saveBar,
            ],
          );
        },
      ),
    );
  }

  /// 0.1.6's `hasDeletedReferences`: the output or an ingredient is a
  /// soft-deleted item.
  static bool _referencesDeletedItem(RecipeDraft draft, RecipeLookups lookups) {
    bool deleted(String id) => lookups.item(id)?.deletedAt != null;
    return deleted(draft.outputItemId) ||
        draft.ingredients.any((i) => deleted(i.itemId));
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
      DirtyDot(key: ValueKey('recipe-dot-$label'), visible: dirty),
    ],
  );
}

/// The options of an item picker: the active items, plus [current] when it
/// is a soft-deleted item (`<name> (deleted)`, 0.1.6's `itemLabel`) or an
/// unknown id, so the picker can still show it.
List<PickerOption<String>> itemPickerOptions(
  RecipeLookups lookups,
  String current,
) {
  final options = [
    for (final item in lookups.activeItems)
      (value: item.id, label: item.displayName),
  ];
  if (current.isNotEmpty && !options.any((o) => o.value == current)) {
    final item = lookups.item(current);
    options.add((
      value: current,
      label: item == null ? current : '${item.displayName} (deleted)',
    ));
  }
  return options;
}

/// `None` (the empty value) and [entries], plus [current] when it is an
/// id [entries] do not hold.
List<PickerOption<String>> nullablePickerOptions(
  Iterable<({String id, String displayName})> entries,
  String? current,
) {
  final options = <PickerOption<String>>[
    (value: '', label: 'None'),
    for (final e in entries) (value: e.id, label: e.displayName),
  ];
  if (current != null && !options.any((o) => o.value == current)) {
    options.add((value: current, label: current));
  }
  return options;
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.draft});

  final RecipeDraft draft;

  @override
  Widget build(BuildContext context) {
    final caption = context.text.labelSmall?.copyWith(
      color: context.anvil.textDisabled,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
    );
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('NAME', style: caption),
            Text(
              draft.displayName.isEmpty ? '—' : draft.displayName,
              key: const ValueKey('recipe-overview-name'),
              style: context.text.titleLarge,
            ),
            const SizedBox(height: AnvilSpacing.lg),
            Text('DESCRIPTION', style: caption),
            const SizedBox(height: AnvilSpacing.xs),
            Text(
              draft.description.isEmpty
                  ? 'No description provided.'
                  : draft.description,
              key: const ValueKey('recipe-overview-description'),
              style: context.text.bodyLarge?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({
    required this.state,
    required this.controller,
    required this.issues,
    required this.lookups,
  });

  final EditorState<RecipeDraft> state;
  final RecipeEditorController controller;
  final List<ValidationIssue> issues;
  final RecipeLookups lookups;

  @override
  Widget build(BuildContext context) {
    final draft = state.draft;
    final blockers = state.blockers;
    final output = fieldMessages(
      blockerText(blockers, 'outputItemId'),
      fieldIssue(issues, 'outputItemId'),
    );
    final station = fieldMessages(
      null,
      fieldIssue(issues, 'craftingStationId'),
    );
    final specialization = fieldMessages(
      null,
      fieldIssue(issues, 'craftingSpecializationId'),
    );
    final outputDeleted = lookups.item(draft.outputItemId)?.deletedAt != null;
    const gap = SizedBox(height: AnvilSpacing.lg);
    const across = SizedBox(width: AnvilSpacing.md);
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 360,
                child: DraftTextField(
                  key: const ValueKey('recipe-export-key'),
                  label: 'Export Key',
                  value: draft.exportKey,
                  onChanged: controller.setExportKey,
                  hintText: 'export-key',
                  blockerMessage: blockerText(blockers, 'exportKey'),
                  issueMessage: fieldIssueText(issues, 'exportKey'),
                  style: ForgeType.code(
                    size: 13.6,
                    color: context.colors.onSurface,
                  ),
                  decoration: const InputDecoration(
                    helperText: 'Export key — used in exported files',
                  ),
                ),
              ),
            ),
            gap,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DraftPicker<String>(
                    key: const ValueKey('recipe-output-item'),
                    label: 'Output Item *',
                    value: draft.outputItemId,
                    options: itemPickerOptions(lookups, draft.outputItemId),
                    onChanged: controller.setOutputItem,
                    errorText: output.error,
                    helperText: output.helper,
                    helperIsWarning: output.warning,
                  ),
                ),
                across,
                SizedBox(
                  width: 180,
                  child: IntDraftField(
                    key: const ValueKey('recipe-output-quantity'),
                    label: 'Output Quantity',
                    value: draft.outputQuantity,
                    onChanged: controller.setOutputQuantity,
                    errorText: blockerText(blockers, 'outputQuantity'),
                  ),
                ),
              ],
            ),
            if (outputDeleted) ...[
              const SizedBox(height: AnvilSpacing.md),
              const _Notice(
                key: ValueKey('recipe-output-deleted-warning'),
                message: 'The selected output item is soft-deleted.',
              ),
            ],
            gap,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DraftPicker<String>(
                    key: const ValueKey('recipe-station'),
                    label: 'Crafting Station',
                    value: draft.craftingStationId ?? '',
                    options: nullablePickerOptions([
                      for (final s in lookups.stations)
                        (id: s.id, displayName: s.displayName),
                    ], draft.craftingStationId),
                    onChanged: (v) =>
                        controller.setStation(v.isEmpty ? null : v),
                    errorText: station.error,
                    helperText: station.helper,
                    helperIsWarning: station.warning,
                  ),
                ),
                across,
                Expanded(
                  child: DraftPicker<String>(
                    key: const ValueKey('recipe-specialization'),
                    label: 'Specialization',
                    value: draft.craftingSpecializationId ?? '',
                    options: nullablePickerOptions([
                      for (final s in lookups.specializations)
                        (id: s.id, displayName: s.displayName),
                    ], draft.craftingSpecializationId),
                    onChanged: (v) =>
                        controller.setSpecialization(v.isEmpty ? null : v),
                    errorText: specialization.error,
                    helperText: specialization.helper,
                    helperIsWarning: specialization.warning,
                  ),
                ),
              ],
            ),
            gap,
            DraftTextField(
              key: const ValueKey('recipe-description'),
              label: 'Description',
              value: draft.description,
              onChanged: controller.setDescription,
              issueMessage: fieldIssueText(issues, 'description'),
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }
}

class _IngredientsTab extends StatelessWidget {
  const _IngredientsTab({
    required this.state,
    required this.controller,
    required this.lookups,
  });

  final EditorState<RecipeDraft> state;
  final RecipeEditorController controller;
  final RecipeLookups lookups;

  static const _quantityWidth = 140.0;
  static const _actionsWidth = 140.0;

  /// The item a new ingredient starts with: the first active item that is
  /// neither the output nor already an ingredient, else the first active
  /// item (0.1.6 always took the first active item).
  static String? _newIngredientItem(RecipeDraft draft, RecipeLookups lookups) {
    final active = lookups.activeItems;
    if (active.isEmpty) return null;
    final used = {
      draft.outputItemId,
      for (final i in draft.ingredients) i.itemId,
    };
    for (final item in active) {
      if (!used.contains(item.id)) return item.id;
    }
    return active.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final draft = state.draft;
    final lines = draft.ingredients;
    final newItem = _newIngredientItem(draft, lookups);
    final muted = context.text.bodyMedium?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    final headerStyle = context.text.labelMedium?.copyWith(
      color: context.colors.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Ingredients', style: context.text.titleMedium),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('recipe-add-ingredient'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Ingredient'),
                  onPressed: newItem == null
                      ? null
                      : () => controller.addIngredient(newItem),
                ),
              ],
            ),
            const SizedBox(height: AnvilSpacing.md),
            if (lookups.activeItems.isEmpty) ...[
              const _Notice(
                message: 'Create an active item before adding ingredients.',
                info: true,
              ),
              const SizedBox(height: AnvilSpacing.md),
            ],
            if (lines.isEmpty)
              Text('No ingredients yet.', style: muted)
            else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: AnvilSpacing.sm),
                child: Row(
                  children: [
                    Expanded(child: Text('Item', style: headerStyle)),
                    const SizedBox(width: AnvilSpacing.md),
                    SizedBox(
                      width: _quantityWidth,
                      child: Text('Quantity', style: headerStyle),
                    ),
                    const SizedBox(width: AnvilSpacing.md),
                    SizedBox(
                      width: _actionsWidth,
                      child: Text(
                        'Actions',
                        style: headerStyle,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ),
              for (final (i, line) in lines.indexed)
                _IngredientRow(
                  key: ValueKey('recipe-ingredient-row-$i'),
                  index: i,
                  line: line,
                  count: lines.length,
                  blockers: state.blockers,
                  controller: controller,
                  lookups: lookups,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    super.key,
    required this.index,
    required this.line,
    required this.count,
    required this.blockers,
    required this.controller,
    required this.lookups,
  });

  final int index;
  final RecipeIngredient line;
  final int count;
  final List<SaveBlocker> blockers;
  final RecipeEditorController controller;
  final RecipeLookups lookups;

  @override
  Widget build(BuildContext context) {
    final i = index;
    final deleted = lookups.item(line.itemId)?.deletedAt != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: AnvilSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: DraftPicker<String>(
              key: ValueKey('recipe-ingredient-$i-item'),
              label: 'Ingredient Item',
              dense: true,
              value: line.itemId,
              options: itemPickerOptions(lookups, line.itemId),
              onChanged: (v) => controller.setIngredientItem(i, v),
              errorText: blockerText(blockers, 'ingredients[$i].itemId'),
              helperText: deleted ? 'Soft-deleted item reference' : null,
              helperIsWarning: true,
            ),
          ),
          const SizedBox(width: AnvilSpacing.md),
          SizedBox(
            width: _IngredientsTab._quantityWidth,
            child: IntDraftField(
              key: ValueKey('recipe-ingredient-$i-quantity'),
              dense: true,
              value: line.quantity,
              onChanged: (q) => controller.setIngredientQuantity(i, q),
              errorText: blockerText(blockers, 'ingredients[$i].quantity'),
            ),
          ),
          const SizedBox(width: AnvilSpacing.md),
          SizedBox(
            width: _IngredientsTab._actionsWidth,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  key: ValueKey('recipe-ingredient-$i-up'),
                  tooltip: 'Move up',
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  onPressed: i == 0
                      ? null
                      : () => controller.moveIngredient(i, i - 1),
                ),
                IconButton(
                  key: ValueKey('recipe-ingredient-$i-down'),
                  tooltip: 'Move down',
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  onPressed: i == count - 1
                      ? null
                      : () => controller.moveIngredient(i, i + 1),
                ),
                IconButton(
                  key: ValueKey('recipe-ingredient-$i-remove'),
                  tooltip: 'Remove',
                  color: context.colors.error,
                  icon: const Icon(Icons.delete, size: 18),
                  onPressed: () => controller.removeIngredient(i),
                ),
              ],
            ),
          ),
        ],
      ),
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

/// 0.1.6's not-found view: the message and `Back to Recipes`.
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
          key: const ValueKey('recipe-load-error'),
          message: message,
        ),
        const SizedBox(height: AnvilSpacing.md),
        TextButton(onPressed: onBack, child: const Text('Back to Recipes')),
      ],
    ),
  );
}
