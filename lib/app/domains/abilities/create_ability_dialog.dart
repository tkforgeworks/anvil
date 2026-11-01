/// 0.1.6's `CreateAbilityDialog.tsx`: a display name and an export key
/// filled in from it until the user types one.
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../../editor/editor_state.dart' show saveErrorMessage;
import '../../shell/shell_providers.dart';
import '../../theme/anvil_colors.dart';
import '../../theme/anvil_metrics.dart';

/// Shows `New Ability` and returns the created ability, or null when the
/// user cancels. The create is a write path, so it bumps the write epoch
/// once after the repository returns.
Future<AbilityRecord?> showCreateAbilityDialog(BuildContext context) =>
    showDialog<AbilityRecord>(
      context: context,
      builder: (_) => const CreateAbilityDialog(),
    );

class CreateAbilityDialog extends ConsumerStatefulWidget {
  const CreateAbilityDialog({super.key});

  static const nameKey = ValueKey('create-ability-name');
  static const exportKeyKey = ValueKey('create-ability-export-key');
  static const createKey = ValueKey('create-ability-confirm');
  static const errorKey = ValueKey('create-ability-error');

  @override
  ConsumerState<CreateAbilityDialog> createState() =>
      _CreateAbilityDialogState();
}

class _CreateAbilityDialogState extends ConsumerState<CreateAbilityDialog> {
  final _name = TextEditingController();
  final _exportKey = TextEditingController();
  var _exportKeyTouched = false;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _exportKey.dispose();
    super.dispose();
  }

  void _nameChanged(String value) {
    setState(() {
      if (!_exportKeyTouched) _exportKey.text = slugifyExportKey(value);
    });
  }

  void _exportKeyChanged(String _) => setState(() => _exportKeyTouched = true);

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final repository = ref.read(abilityRepositoryProvider);
    final epoch = ref.read(writeEpochProvider.notifier);
    try {
      final key = _exportKey.text.trim();
      final record = await repository.create(
        CreateAbilityInput(
          displayName: name,
          exportKey: key.isEmpty ? slugifyExportKey(name) : key,
        ),
      );
      epoch.bump();
      if (mounted) Navigator.of(context).pop(record);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = switch (error) {
          DuplicateExportKey() ||
          SaveFailed() ||
          SaveBlocked() => saveErrorMessage(error),
          _ => 'Failed to create ability.',
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = _name.text.trim().isNotEmpty && !_busy;
    return AlertDialog(
      title: const Text('New Ability'),
      content: SizedBox(
        width: 552,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error case final error?) ...[
              Text(
                error,
                key: CreateAbilityDialog.errorKey,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.error,
                ),
              ),
              const SizedBox(height: AnvilSpacing.md),
            ],
            TextField(
              key: CreateAbilityDialog.nameKey,
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Display Name *'),
              onChanged: _nameChanged,
              onSubmitted: (_) => _create(),
            ),
            const SizedBox(height: AnvilSpacing.md),
            TextField(
              key: CreateAbilityDialog.exportKeyKey,
              controller: _exportKey,
              decoration: InputDecoration(
                labelText: 'Export Key',
                helperText:
                    'Used in exported files. Auto-generated from the display '
                    'name.',
                prefixText: _exportKey.text.isEmpty ? 'auto ' : null,
                prefixStyle: context.text.bodySmall?.copyWith(
                  color: context.anvil.textDisabled,
                ),
              ),
              onChanged: _exportKeyChanged,
              onSubmitted: (_) => _create(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: CreateAbilityDialog.createKey,
          onPressed: canCreate ? _create : null,
          child: const Text('Create Ability'),
        ),
      ],
    );
  }
}

/// 0.1.6's `slugify` (`utils/slugify.ts`): lower case, every run of
/// characters outside `a-z0-9` becomes one `-`, a leading and a trailing
/// `-` stripped.
String slugifyExportKey(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-|-$'), '');
