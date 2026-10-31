import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/recipe_draft.dart';
import '../core/recipe_repository.dart';
import '../core/recipe_rules.dart';
import 'draft_text_field.dart';
import 'editor_shortcuts.dart';
import 'providers.dart';
import 'recipe_editor_controller.dart';

enum LeaveChoice { save, discard, cancel }

class RecipeEditorPage extends ConsumerStatefulWidget {
  const RecipeEditorPage({super.key, required this.recipeId});

  final String recipeId;

  @override
  ConsumerState<RecipeEditorPage> createState() => _RecipeEditorPageState();
}

class _RecipeEditorPageState extends ConsumerState<RecipeEditorPage> {
  /// Takes primary focus whenever no field has it (on open, and when a click
  /// outside a field unfocuses it), so editor shortcuts keep working.
  final FocusScopeNode _editorScope = FocusScopeNode(debugLabel: 'editor');
  String? _status;

  RecipeEditorController get _controller =>
      ref.read(recipeEditorProvider(widget.recipeId).notifier);

  @override
  void dispose() {
    _editorScope.dispose();
    super.dispose();
  }

  Future<SaveOutcome> _save() async {
    final outcome = await _controller.save();
    if (mounted) {
      setState(() {
        _status = switch (outcome) {
          SaveOutcome.saved => 'Saved.',
          SaveOutcome.failed => 'Save failed. Nothing was written.',
          SaveOutcome.blocked => 'Save is blocked (see above).',
          SaveOutcome.nothingToSave || SaveOutcome.busy => _status,
        };
      });
    }
    return outcome;
  }

  Future<void> _confirmLeave(RecipeEditorState state) async {
    final blocked = state.blockers.isNotEmpty;
    final choice = await showDialog<LeaveChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: Text(
          blocked
              ? "'${state.draft.displayName}' has changes that cannot be saved "
                    'until the problems are fixed.'
              : "Save changes to '${state.draft.displayName}' before leaving?",
        ),
        actions: [
          TextButton(
            key: const Key('leave-cancel'),
            onPressed: () => Navigator.of(context).pop(LeaveChoice.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('leave-discard'),
            onPressed: () => Navigator.of(context).pop(LeaveChoice.discard),
            child: const Text('Discard'),
          ),
          FilledButton(
            key: const Key('leave-save'),
            onPressed: blocked
                ? null
                : () => Navigator.of(context).pop(LeaveChoice.save),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case LeaveChoice.save:
        if (await _save() == SaveOutcome.saved && mounted) {
          Navigator.of(context).pop();
        }
      case LeaveChoice.discard:
        // Navigator.pop ignores PopScope.canPop; the autoDispose provider
        // drops the draft once the page is gone.
        Navigator.of(context).pop();
      case LeaveChoice.cancel || null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final editor = ref.watch(recipeEditorProvider(widget.recipeId));
    final lookups = ref.watch(recipeLookupsProvider);
    final state = editor.value;
    final options = lookups.value;
    if (state == null || options == null) {
      final error = editor.error ?? lookups.error;
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: error != null
              ? Text('Could not open recipe: $error')
              : const CircularProgressIndicator(),
        ),
      );
    }

    return PopScope<Object?>(
      canPop: !state.isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave(state);
      },
      child: RecordEditorShortcuts(
        onSave: _save,
        onUndo: _controller.undo,
        onRedo: _controller.redo,
        child: FocusScope(
          node: _editorScope,
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      state.draft.displayName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (state.isDirty)
                    const Padding(
                      key: Key('dirty-marker'),
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.circle, size: 10),
                    ),
                ],
              ),
              actions: [
                IconButton(
                  key: const Key('undo-button'),
                  tooltip: 'Undo (Ctrl+Z outside a field)',
                  onPressed: state.canUndo ? _controller.undo : null,
                  icon: const Icon(Icons.undo),
                ),
                IconButton(
                  key: const Key('redo-button'),
                  tooltip: 'Redo',
                  onPressed: state.canRedo ? _controller.redo : null,
                  icon: const Icon(Icons.redo),
                ),
                const _ForceFailureToggle(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: FilledButton(
                    key: const Key('save-button'),
                    onPressed: state.canSave ? _save : null,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
            body: _EditorBody(
              state: state,
              lookups: options,
              controller: _controller,
              status: _status,
            ),
          ),
        ),
      ),
    );
  }
}

class _ForceFailureToggle extends ConsumerWidget {
  const _ForceFailureToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        const Text('Force failure'),
        Switch(
          key: const Key('force-failure-toggle'),
          value: ref.watch(forceSaveFailureProvider),
          onChanged: ref.read(forceSaveFailureProvider.notifier).set,
        ),
      ],
    );
  }
}

class _EditorBody extends StatelessWidget {
  const _EditorBody({
    required this.state,
    required this.lookups,
    required this.controller,
    required this.status,
  });

  final RecipeEditorState state;
  final RecipeLookups lookups;
  final RecipeEditorController controller;
  final String? status;

  String _blockerMessage(RecipeBlocker blocker) => switch (blocker.kind) {
    RecipeBlockerKind.outputUsedAsIngredient =>
      "The output item '${lookups.itemName(blocker.itemId!)}' is also an "
          'ingredient. A recipe cannot consume what it produces.',
    RecipeBlockerKind.duplicateIngredient =>
      "'${lookups.itemName(blocker.itemId!)}' is listed more than once.",
    RecipeBlockerKind.nonPositiveQuantity => 'Quantities must be at least 1.',
  };

  @override
  Widget build(BuildContext context) {
    final draft = state.draft;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (state.blockers.isNotEmpty)
          Card(
            key: const Key('blocker-message'),
            color: scheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final blocker in state.blockers)
                    Text(
                      _blockerMessage(blocker),
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                ],
              ),
            ),
          ),
        if (state.saveError != null)
          Text(
            key: const Key('save-error'),
            state.saveError!,
            style: TextStyle(color: scheme.error),
          ),
        if (status != null) Text(status!, key: const Key('save-status')),
        DraftTextField(
          key: const Key('field-displayName'),
          label: 'Display name',
          value: draft.displayName,
          onChanged: controller.setDisplayName,
        ),
        DraftTextField(
          key: const Key('field-exportKey'),
          label: 'Export key',
          value: draft.exportKey,
          onChanged: controller.setExportKey,
        ),
        DraftTextField(
          key: const Key('field-description'),
          label: 'Description',
          value: draft.description,
          onChanged: controller.setDescription,
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text('Output'),
            const SizedBox(width: 16),
            _ItemPicker(
              key: const Key('output-item'),
              lookups: lookups,
              value: draft.outputItemId,
              onChanged: controller.setOutputItem,
            ),
            _QuantityStepper(
              keyPrefix: 'output',
              value: draft.outputQuantity,
              onChanged: controller.setOutputQuantity,
            ),
          ],
        ),
        Row(
          children: [
            const Text('Station'),
            const SizedBox(width: 16),
            _NullablePicker(
              key: const Key('station'),
              options: lookups.stations,
              value: draft.craftingStationId,
              onChanged: controller.setStation,
            ),
            const SizedBox(width: 24),
            const Text('Specialization'),
            const SizedBox(width: 16),
            _NullablePicker(
              key: const Key('specialization'),
              options: lookups.specializations,
              value: draft.craftingSpecializationId,
              onChanged: controller.setSpecialization,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Ingredients', style: Theme.of(context).textTheme.titleMedium),
        for (final (i, line) in draft.ingredients.indexed)
          _IngredientRow(
            key: Key('ingredient-$i'),
            index: i,
            line: line,
            isLast: i == draft.ingredients.length - 1,
            lookups: lookups,
            controller: controller,
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('add-ingredient'),
            onPressed: () => controller.addIngredient(_nextFreeItem(draft)),
            icon: const Icon(Icons.add),
            label: const Text('Add ingredient'),
          ),
        ),
      ],
    );
  }

  String _nextFreeItem(RecipeDraft draft) {
    final used = {
      draft.outputItemId,
      ...draft.ingredients.map((l) => l.itemId),
    };
    final active = lookups.items.where((i) => !i.archived);
    return active
        .firstWhere((i) => !used.contains(i.id), orElse: () => active.first)
        .id;
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    super.key,
    required this.index,
    required this.line,
    required this.isLast,
    required this.lookups,
    required this.controller,
  });

  final int index;
  final IngredientLine line;
  final bool isLast;
  final RecipeLookups lookups;
  final RecipeEditorController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ItemPicker(
          key: Key('ingredient-item-$index'),
          lookups: lookups,
          value: line.itemId,
          onChanged: (id) => controller.setIngredientItem(index, id),
        ),
        _QuantityStepper(
          keyPrefix: 'ingredient-$index',
          value: line.quantity,
          onChanged: (q) => controller.setIngredientQuantity(index, q),
        ),
        IconButton(
          key: Key('ingredient-up-$index'),
          tooltip: 'Move up',
          onPressed: index == 0
              ? null
              : () => controller.moveIngredient(index, index - 1),
          icon: const Icon(Icons.arrow_upward),
        ),
        IconButton(
          key: Key('ingredient-down-$index'),
          tooltip: 'Move down',
          onPressed: isLast
              ? null
              : () => controller.moveIngredient(index, index + 1),
          icon: const Icon(Icons.arrow_downward),
        ),
        IconButton(
          key: Key('ingredient-remove-$index'),
          tooltip: 'Remove',
          onPressed: () => controller.removeIngredient(index),
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }
}

class _ItemPicker extends StatelessWidget {
  const _ItemPicker({
    super.key,
    required this.lookups,
    required this.value,
    required this.onChanged,
  });

  final RecipeLookups lookups;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    // DropdownButton, not DropdownMenu: DropdownMenu hosts an EditableText,
    // which would make Ctrl+Z on the picker a text-field undo.
    return DropdownButton<String>(
      value: value,
      items: [
        for (final item in lookups.items)
          if (!item.archived || item.id == value)
            DropdownMenuItem(
              value: item.id,
              child: Text(
                item.archived
                    ? '${item.displayName} (archived)'
                    : item.displayName,
              ),
            ),
      ],
      onChanged: (id) {
        if (id != null) onChanged(id);
      },
    );
  }
}

class _NullablePicker extends StatelessWidget {
  const _NullablePicker({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<LookupOption> options;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String?>(
      value: value,
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('None')),
        for (final option in options)
          DropdownMenuItem<String?>(
            value: option.id,
            child: Text(option.displayName),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.keyPrefix,
    required this.value,
    required this.onChanged,
  });

  final String keyPrefix;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: Key('$keyPrefix-dec'),
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        Text('x$value', key: Key('$keyPrefix-qty')),
        IconButton(
          key: Key('$keyPrefix-inc'),
          onPressed: () => onChanged(value + 1),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
