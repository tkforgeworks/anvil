/// 0.1.6's `CreateRecipeDialog`: a new recipe from its name, export key,
/// output item and quantity, station and specialization.
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../../editor/editor_state.dart';
import '../../shell/shell_providers.dart';
import '../../theme/anvil_metrics.dart';
import 'recipes_editor_page.dart';
import 'recipes_fields.dart';
import 'recipes_lookups.dart';

/// Shows the dialog; completes with the created recipe, or null when it
/// was cancelled. The create is a write path, so it bumps
/// `writeEpochProvider` once after the repository returns.
Future<RecipeRecord?> showCreateRecipeDialog(BuildContext context) =>
    showDialog<RecipeRecord>(
      context: context,
      builder: (_) => const CreateRecipeDialog(),
    );

class CreateRecipeDialog extends ConsumerStatefulWidget {
  const CreateRecipeDialog({super.key});

  static const nameKey = ValueKey('create-recipe-name');
  static const exportKeyKey = ValueKey('create-recipe-export-key');
  static const outputKey = ValueKey('create-recipe-output-item');
  static const quantityKey = ValueKey('create-recipe-output-quantity');
  static const stationKey = ValueKey('create-recipe-station');
  static const specializationKey = ValueKey('create-recipe-specialization');
  static const createKey = ValueKey('create-recipe-confirm');
  static const cancelKey = ValueKey('create-recipe-cancel');

  @override
  ConsumerState<CreateRecipeDialog> createState() => _CreateRecipeDialogState();
}

class _CreateRecipeDialogState extends ConsumerState<CreateRecipeDialog> {
  final _name = TextEditingController();
  final _exportKey = TextEditingController();
  var _exportKeyTouched = false;

  /// Null until the user picks; the first active item is the default.
  String? _outputItemId;
  var _outputQuantity = 1;
  String? _stationId;
  String? _specializationId;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _exportKey.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    setState(() {
      if (!_exportKeyTouched) _exportKey.text = slugifyExportKey(value);
    });
  }

  Future<void> _create(String outputItemId) async {
    final name = _name.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final key = _exportKey.text.trim();
      final record = await ref
          .read(recipeRepositoryProvider)
          .create(
            CreateRecipeInput(
              displayName: name,
              exportKey: key.isEmpty ? slugifyExportKey(name) : key,
              outputItemId: outputItemId,
              outputQuantity: _outputQuantity < 1 ? 1 : _outputQuantity,
              craftingStationId: _stationId,
              craftingSpecializationId: _specializationId,
            ),
          );
      ref.read(writeEpochProvider.notifier).bump();
      if (mounted) Navigator.of(context).pop(record);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = saveErrorMessage(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lookups =
        ref.watch(recipeLookupsProvider).value ?? RecipeLookups.empty;
    final items = lookups.activeItems;
    final outputItemId = _outputItemId ?? (items.isEmpty ? '' : items.first.id);
    final canCreate =
        !_busy && _name.text.trim().isNotEmpty && outputItemId.isNotEmpty;
    const gap = SizedBox(height: AnvilSpacing.md);
    const across = SizedBox(width: AnvilSpacing.md);
    return AlertDialog(
      title: const Text('New Recipe'),
      content: SizedBox(
        width: 552,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error case final error?) ...[
                ForgeErrorCard(message: error),
                gap,
              ],
              if (lookups.items.isEmpty &&
                  ref.watch(recipeLookupsProvider).hasValue) ...[
                Text(
                  'Create an item before adding a recipe.',
                  style: context.text.bodyMedium?.copyWith(
                    color: context.forge.info,
                  ),
                ),
                gap,
              ],
              TextField(
                key: CreateRecipeDialog.nameKey,
                controller: _name,
                autofocus: true,
                onChanged: _onNameChanged,
                decoration: const InputDecoration(labelText: 'Display Name *'),
              ),
              gap,
              TextField(
                key: CreateRecipeDialog.exportKeyKey,
                controller: _exportKey,
                onChanged: (_) => _exportKeyTouched = true,
                decoration: const InputDecoration(
                  labelText: 'Export Key',
                  helperText:
                      'Used in exported files. Auto-generated from the '
                      'display name.',
                ),
              ),
              gap,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: RecipePicker(
                      key: CreateRecipeDialog.outputKey,
                      label: 'Output Item *',
                      value: outputItemId,
                      options: itemPickerOptions(lookups, outputItemId),
                      onChanged: (v) => setState(() => _outputItemId = v),
                    ),
                  ),
                  across,
                  SizedBox(
                    width: 180,
                    child: IntDraftField(
                      key: CreateRecipeDialog.quantityKey,
                      label: 'Output Quantity',
                      value: _outputQuantity,
                      onChanged: (q) => setState(() => _outputQuantity = q),
                    ),
                  ),
                ],
              ),
              gap,
              Row(
                children: [
                  Expanded(
                    child: RecipePicker(
                      key: CreateRecipeDialog.stationKey,
                      label: 'Crafting Station',
                      value: _stationId ?? '',
                      options: nullablePickerOptions([
                        for (final s in lookups.stations)
                          (id: s.id, displayName: s.displayName),
                      ], _stationId),
                      onChanged: (v) =>
                          setState(() => _stationId = v.isEmpty ? null : v),
                    ),
                  ),
                  across,
                  Expanded(
                    child: RecipePicker(
                      key: CreateRecipeDialog.specializationKey,
                      label: 'Specialization',
                      value: _specializationId ?? '',
                      options: nullablePickerOptions([
                        for (final s in lookups.specializations)
                          (id: s.id, displayName: s.displayName),
                      ], _specializationId),
                      onChanged: (v) => setState(
                        () => _specializationId = v.isEmpty ? null : v,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: CreateRecipeDialog.cancelKey,
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: CreateRecipeDialog.createKey,
          onPressed: canCreate ? () => _create(outputItemId) : null,
          child: const Text('Create Recipe'),
        ),
      ],
    );
  }
}
