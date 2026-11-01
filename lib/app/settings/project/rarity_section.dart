/// 0.1.6's `RaritySection` (`ProjectSettingsTab.tsx`): the rarity table
/// with each tier's colour swatch, and its add / edit dialog with the hex
/// colour field.
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:forge_ui/forge_ui.dart';

import '../../theme/anvil_metrics.dart';
import '../../theme/color_math.dart';
import 'meta_list_section.dart';

/// `#RRGGBB`, the only colour form 0.1.6's dialog accepted.
final RegExp rarityHexPattern = RegExp(r'^#[0-9a-fA-F]{6}$');

/// A 20 px swatch of [hex], or an empty box with a border when [hex] is
/// not `#RRGGBB`. The colour is the user's data, built through
/// `hexToColor`, not a theme colour.
class RaritySwatch extends StatelessWidget {
  const RaritySwatch(this.hex, {super.key, this.size = 20});

  final String hex;
  final double size;

  @override
  Widget build(BuildContext context) {
    final valid = rarityHexPattern.hasMatch(hex.trim());
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: valid ? hexToColor(hex.trim()) : null,
        borderRadius: BorderRadius.circular(AnvilRadii.control),
        border: Border.all(color: context.colors.outlineVariant),
      ),
    );
  }
}

class RaritySection extends StatefulWidget {
  const RaritySection({
    super.key,
    required this.rows,
    required this.onAdd,
    required this.onUpdate,
    required this.onDelete,
    required this.onMove,
  });

  final List<RarityRowDraft> rows;
  final Future<String?> Function(MetaRarityInput input) onAdd;
  final Future<String?> Function(String id, MetaRarityInput input) onUpdate;
  final Future<String?> Function(String id) onDelete;
  final Future<String?> Function(int from, int to) onMove;

  @override
  State<RaritySection> createState() => _RaritySectionState();
}

class _RaritySectionState extends State<RaritySection> {
  String? _error;

  Future<void> _openDialog([RarityRowDraft? editing]) => showDialog<void>(
    context: context,
    builder: (_) => _RarityDialog(
      editing: editing,
      onSubmit: (input) => editing == null
          ? widget.onAdd(input)
          : widget.onUpdate(editing.id, input),
    ),
  );

  Future<void> _run(Future<String?> action) async {
    setState(() => _error = null);
    final error = await action;
    if (mounted && error != null) setState(() => _error = error);
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    final error = _error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MetaSectionHeader(
          title: 'Rarities',
          description:
              'Rarity tiers used by items. Each has a display color shown in '
              'list views.',
          trailing: MetaAddButton(onPressed: () => _openDialog()),
        ),
        if (error != null)
          MetaSectionError(
            message: error,
            onDismiss: () => setState(() => _error = null),
          ),
        if (rows.isEmpty)
          const MetaNoneDefined()
        else
          MetaTable(
            columns: const [
              MetaColumn('Color', width: 40),
              MetaColumn('Name'),
              MetaColumn('Export Key'),
            ],
            rows: [
              for (var i = 0; i < rows.length; i++)
                MetaTableRow(
                  key: ValueKey('meta-row-${rows[i].id}'),
                  cells: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: RaritySwatch(rows[i].colorHex),
                    ),
                    Text(rows[i].displayName, overflow: TextOverflow.ellipsis),
                    ExportKeyText(rows[i].exportKey),
                  ],
                  actions: MetaRowActions(
                    isFirst: i == 0,
                    isLast: i == rows.length - 1,
                    onMoveUp: () => _run(widget.onMove(i, i - 1)),
                    onMoveDown: () => _run(widget.onMove(i, i + 1)),
                    onEdit: () => _openDialog(rows[i]),
                    onDelete: () => _run(widget.onDelete(rows[i].id)),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _RarityDialog extends StatefulWidget {
  const _RarityDialog({required this.editing, required this.onSubmit});

  final RarityRowDraft? editing;
  final Future<String?> Function(MetaRarityInput input) onSubmit;

  @override
  State<_RarityDialog> createState() => _RarityDialogState();
}

class _RarityDialogState extends State<_RarityDialog> {
  late final _fields = NameKeyControllers(
    name: widget.editing?.displayName ?? '',
    key: widget.editing?.exportKey ?? '',
    keyTouched: widget.editing != null,
  );
  late final _color = TextEditingController(
    text: widget.editing?.colorHex ?? '#ffffff',
  );

  @override
  void dispose() {
    _fields.dispose();
    _color.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing;
    final hex = _color.text.trim();
    final hexValid = rarityHexPattern.hasMatch(hex);
    final canSubmit =
        _fields.trimmedName.isNotEmpty &&
        _fields.trimmedKey.isNotEmpty &&
        exportKeyError(_fields.key.text, original: editing?.exportKey) ==
            null &&
        hexValid;
    return MetaRowDialogFrame(
      title: editing == null ? 'Add Rarity' : 'Edit Rarity',
      editing: editing != null,
      canSubmit: canSubmit,
      onSubmit: () => widget.onSubmit(
        MetaRarityInput(
          displayName: _fields.trimmedName,
          exportKey: _fields.trimmedKey,
          colorHex: hex,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NameKeyFields(
            controllers: _fields,
            originalKey: editing?.exportKey,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: AnvilSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('rarity-color'),
                  controller: _color,
                  style: ForgeType.code(color: context.colors.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Color (hex) *',
                    hintText: '#RRGGBB',
                    helperText: 'Hex format: #RRGGBB',
                    errorText: hex.isNotEmpty && !hexValid
                        ? 'Hex format: #RRGGBB'
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: AnvilSpacing.sm),
                child: RaritySwatch(hex, size: 40),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
