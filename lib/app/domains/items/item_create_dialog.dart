/// The New Item dialog (0.1.6 `create-dialogs/CreateItemDialog.tsx`).
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../../editor/editor_state.dart';
import '../../shell/shell_providers.dart';
import '../../theme/anvil_colors.dart';
import '../../theme/anvil_metrics.dart';
import 'item_meta_providers.dart';

import 'package:anvil/app/editor/widgets/draft_picker.dart';
import 'package:anvil/app/editor/export_key_slug.dart';

/// 0.1.6's `maxWidth="sm"` (600 px) less the dialog's 24 px padding on
/// each side.
const _contentWidth = 552.0;

/// Shows the New Item dialog and returns the created item, or null when it
/// was cancelled. The create is a write path: it bumps `writeEpochProvider`
/// once after the repository returns.
Future<ItemRecord?> showCreateItemDialog(BuildContext context) =>
    showDialog<ItemRecord>(
      context: context,
      builder: (_) => const CreateItemDialog(),
    );

/// Display Name, Export Key (filled from the name until edited, `auto`
/// while empty), Category and Rarity (the first of each preselected),
/// Description; Create Item is enabled once the name, category and rarity
/// are set. Name, key and description are trimmed, and an empty key falls
/// back to the slug of the name, as 0.1.6's `handleCreate` did.
class CreateItemDialog extends ConsumerStatefulWidget {
  const CreateItemDialog({super.key});

  static const nameKey = ValueKey('create-item-name');
  static const exportKeyKey = ValueKey('create-item-export-key');
  static const categoryKey = ValueKey('create-item-category');
  static const rarityKey = ValueKey('create-item-rarity');
  static const descriptionKey = ValueKey('create-item-description');
  static const createKey = ValueKey('create-item-confirm');
  static const cancelKey = ValueKey('create-item-cancel');

  @override
  ConsumerState<CreateItemDialog> createState() => _CreateItemDialogState();
}

class _CreateItemDialogState extends ConsumerState<CreateItemDialog> {
  final _name = TextEditingController();
  final _exportKey = TextEditingController();
  final _description = TextEditingController();
  var _exportKeyTouched = false;
  String? _categoryId;
  String? _rarityId;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _exportKey.dispose();
    _description.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    setState(() {
      if (!_exportKeyTouched) _exportKey.text = slugifyExportKey(value);
    });
  }

  bool get _canCreate =>
      _name.text.trim().isNotEmpty &&
      _categoryId != null &&
      _rarityId != null &&
      !_busy;

  Future<void> _create() async {
    if (!_canCreate) return;
    final name = _name.text.trim();
    final key = _exportKey.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final record = await ref
          .read(itemRepositoryProvider)
          .create(
            CreateItemInput(
              displayName: name,
              exportKey: key.isEmpty ? slugifyExportKey(name) : key,
              description: _description.text.trim(),
              itemCategoryId: _categoryId!,
              rarityId: _rarityId!,
            ),
          );
      if (!mounted) return;
      ref.read(writeEpochProvider.notifier).bump();
      Navigator.of(context).pop(record);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = switch (error) {
          SaveFailed() ||
          DuplicateExportKey() ||
          SaveBlocked() => saveErrorMessage(error),
          _ => 'Failed to create item.',
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(itemCategoriesProvider).value ?? const [];
    final rarities = ref.watch(itemRaritiesProvider).value ?? const [];
    // 0.1.6 preselected the first category and rarity.
    _categoryId ??= categories.firstOrNull?.id;
    _rarityId ??= rarities.firstOrNull?.id;

    return AlertDialog(
      title: const Text('New Item'),
      content: SizedBox(
        width: _contentWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error case final error?) ...[
                ForgeErrorCard(message: error),
                const SizedBox(height: AnvilSpacing.md),
              ],
              const SizedBox(height: AnvilSpacing.sm),
              TextField(
                key: CreateItemDialog.nameKey,
                controller: _name,
                autofocus: true,
                onChanged: _onNameChanged,
                decoration: const InputDecoration(labelText: 'Display Name *'),
              ),
              const SizedBox(height: AnvilSpacing.md),
              TextField(
                key: CreateItemDialog.exportKeyKey,
                controller: _exportKey,
                onChanged: (_) => setState(() => _exportKeyTouched = true),
                decoration: InputDecoration(
                  labelText: 'Export Key',
                  helperText:
                      'Used in exported files. Auto-generated from the '
                      'display name.',
                  prefixText: _exportKey.text.isEmpty ? 'auto  ' : null,
                  prefixStyle: context.text.bodySmall?.copyWith(
                    color: context.anvil.textDisabled,
                  ),
                ),
              ),
              const SizedBox(height: AnvilSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: DraftPicker<String?>(
                      key: CreateItemDialog.categoryKey,
                      label: 'Category',
                      isRequired: true,
                      value: _categoryId,
                      options: [
                        for (final c in categories)
                          (value: c.id, label: c.displayName),
                      ],
                      onChanged: (id) => setState(() => _categoryId = id),
                    ),
                  ),
                  const SizedBox(width: AnvilSpacing.md),
                  Expanded(
                    child: DraftPicker<String?>(
                      key: CreateItemDialog.rarityKey,
                      label: 'Rarity',
                      isRequired: true,
                      value: _rarityId,
                      options: [
                        for (final r in rarities)
                          (value: r.id, label: r.displayName),
                      ],
                      onChanged: (id) => setState(() => _rarityId = id),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AnvilSpacing.md),
              TextField(
                key: CreateItemDialog.descriptionKey,
                controller: _description,
                minLines: 3,
                maxLines: null,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: CreateItemDialog.cancelKey,
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: CreateItemDialog.createKey,
          onPressed: _canCreate ? _create : null,
          child: const Text('Create Item'),
        ),
      ],
    );
  }
}
