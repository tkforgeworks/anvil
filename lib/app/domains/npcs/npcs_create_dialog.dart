/// The New NPC dialog (0.1.6 `create-dialogs/CreateNpcDialog.tsx`).
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../../editor/editor_state.dart';
import '../../editor/export_key_slug.dart';
import '../../editor/widgets/draft_picker.dart';
import '../../shell/shell_providers.dart';
import '../../theme/anvil_colors.dart';
import '../../theme/anvil_metrics.dart';
import 'npcs_providers.dart';

/// 0.1.6's `maxWidth="sm"` (600 px) less the dialog's 24 px padding on
/// each side.
const _contentWidth = 552.0;

/// Shows the New NPC dialog and returns the created NPC, or null when it
/// was cancelled. The create is a write path: it bumps `writeEpochProvider`
/// once after the repository returns.
Future<NpcRecord?> showCreateNpcDialog(BuildContext context) =>
    showDialog<NpcRecord>(
      context: context,
      builder: (_) => const CreateNpcDialog(),
    );

/// Display Name, Export Key (filled from the name until edited, `auto`
/// while empty) and NPC Type (the first preselected), as 0.1.6's dialog;
/// with no NPC type it shows 0.1.6's `Create an NPC type before adding
/// NPCs.` Create NPC is enabled once the name and type are set. The name
/// and key are trimmed, and an empty key falls back to the slug of the
/// name, as 0.1.6's `handleCreate` did.
class CreateNpcDialog extends ConsumerStatefulWidget {
  const CreateNpcDialog({super.key});

  static const nameKey = ValueKey('create-npc-name');
  static const exportKeyKey = ValueKey('create-npc-export-key');
  static const typeKey = ValueKey('create-npc-type');
  static const createKey = ValueKey('create-npc-confirm');
  static const cancelKey = ValueKey('create-npc-cancel');

  @override
  ConsumerState<CreateNpcDialog> createState() => _CreateNpcDialogState();
}

class _CreateNpcDialogState extends ConsumerState<CreateNpcDialog> {
  final _name = TextEditingController();
  final _exportKey = TextEditingController();
  var _exportKeyTouched = false;
  String? _typeId;
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

  bool get _canCreate =>
      _name.text.trim().isNotEmpty && _typeId != null && !_busy;

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
          .read(npcRepositoryProvider)
          .create(
            CreateNpcInput(
              displayName: name,
              exportKey: key.isEmpty ? slugifyExportKey(name) : key,
              npcTypeId: _typeId!,
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
          _ => 'Failed to create NPC.',
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final typesAsync = ref.watch(npcTypesProvider);
    final types = typesAsync.value ?? const [];
    // 0.1.6 preselected the first NPC type.
    _typeId ??= types.firstOrNull?.id;

    return AlertDialog(
      title: const Text('New NPC'),
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
              if (typesAsync.hasValue && types.isEmpty) ...[
                Container(
                  key: const ValueKey('create-npc-no-types'),
                  padding: const EdgeInsets.all(AnvilSpacing.md),
                  decoration: BoxDecoration(
                    color: context.forge.infoContainer,
                    borderRadius: BorderRadius.circular(ForgeRadii.card),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: context.forge.info,
                      ),
                      const SizedBox(width: AnvilSpacing.md),
                      const Expanded(
                        child: Text('Create an NPC type before adding NPCs.'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AnvilSpacing.md),
              ],
              const SizedBox(height: AnvilSpacing.sm),
              TextField(
                key: CreateNpcDialog.nameKey,
                controller: _name,
                autofocus: true,
                onChanged: _onNameChanged,
                decoration: const InputDecoration(labelText: 'Display Name *'),
              ),
              const SizedBox(height: AnvilSpacing.md),
              TextField(
                key: CreateNpcDialog.exportKeyKey,
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
              DraftPicker<String?>(
                key: CreateNpcDialog.typeKey,
                label: 'NPC Type',
                isRequired: true,
                value: _typeId,
                options: [
                  for (final t in types) (value: t.id, label: t.displayName),
                ],
                onChanged: (id) => setState(() => _typeId = id),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: CreateNpcDialog.cancelKey,
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: CreateNpcDialog.createKey,
          onPressed: _canCreate ? _create : null,
          child: const Text('Create NPC'),
        ),
      ],
    );
  }
}
