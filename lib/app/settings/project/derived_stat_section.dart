/// 0.1.6's `DerivedStatSection` (`ProjectSettingsTab.tsx`): the derived
/// stat table and its add / edit dialog with formula, output type and
/// rounding mode.
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:forge_ui/forge_ui.dart';

import '../../theme/anvil_metrics.dart';
import 'meta_list_section.dart';

String _outputLabel(DerivedStatOutputType t) => switch (t) {
  DerivedStatOutputType.integer => 'Integer',
  DerivedStatOutputType.float => 'Float',
};

String _roundingLabel(RoundingMode m) => switch (m) {
  RoundingMode.floor => 'Floor',
  RoundingMode.round => 'Round',
  RoundingMode.none => 'None',
};

class DerivedStatSection extends StatefulWidget {
  const DerivedStatSection({
    super.key,
    required this.rows,
    required this.onAdd,
    required this.onUpdate,
    required this.onDelete,
    required this.onMove,
  });

  final List<DerivedStatRowDraft> rows;
  final Future<String?> Function(DerivedStatInput input) onAdd;
  final Future<String?> Function(String id, DerivedStatInput input) onUpdate;
  final Future<String?> Function(String id) onDelete;
  final Future<String?> Function(int from, int to) onMove;

  @override
  State<DerivedStatSection> createState() => _DerivedStatSectionState();
}

class _DerivedStatSectionState extends State<DerivedStatSection> {
  String? _error;

  Future<void> _openDialog([DerivedStatRowDraft? editing]) => showDialog<void>(
    context: context,
    builder: (_) => _DerivedStatDialog(
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
    final small = context.text.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MetaSectionHeader(
          title: 'Derived Stat Definitions',
          description:
              'Calculated stats with formulas referencing primary stats. '
              'Per-class overrides are managed in the class editor.',
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
              MetaColumn('Name', flex: 2),
              MetaColumn('Export Key', flex: 2),
              MetaColumn('Formula', flex: 3),
              MetaColumn('Output', width: 64),
              MetaColumn('Rounding', width: 64),
            ],
            rows: [
              for (var i = 0; i < rows.length; i++)
                MetaTableRow(
                  key: ValueKey('meta-row-${rows[i].id}'),
                  cells: [
                    Text(rows[i].displayName, overflow: TextOverflow.ellipsis),
                    ExportKeyText(rows[i].exportKey),
                    Text(
                      rows[i].formula,
                      overflow: TextOverflow.ellipsis,
                      style: ForgeType.code(
                        size: 12,
                        color: context.colors.onSurface,
                      ),
                    ),
                    Text(rows[i].outputType.value, style: small),
                    Text(rows[i].roundingMode.value, style: small),
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

class _DerivedStatDialog extends StatefulWidget {
  const _DerivedStatDialog({required this.editing, required this.onSubmit});

  final DerivedStatRowDraft? editing;
  final Future<String?> Function(DerivedStatInput input) onSubmit;

  @override
  State<_DerivedStatDialog> createState() => _DerivedStatDialogState();
}

class _DerivedStatDialogState extends State<_DerivedStatDialog> {
  late final _fields = NameKeyControllers(
    name: widget.editing?.displayName ?? '',
    key: widget.editing?.exportKey ?? '',
    keyTouched: widget.editing != null,
  );
  late final _formula = TextEditingController(
    text: widget.editing?.formula ?? '',
  );
  late var _outputType =
      widget.editing?.outputType ?? DerivedStatOutputType.integer;
  late var _roundingMode = widget.editing?.roundingMode ?? RoundingMode.floor;

  @override
  void dispose() {
    _fields.dispose();
    _formula.dispose();
    super.dispose();
  }

  /// `validateFormula`'s message for a formula that is typed and differs
  /// from the stored one; a stored formula that no longer parses is left
  /// to the validation panel, as 0.1.6 left every formula.
  String? get _formulaError {
    final formula = _formula.text.trim();
    if (formula.isEmpty || formula == widget.editing?.formula) return null;
    return validateFormula(formula);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing;
    final formulaError = _formulaError;
    final canSubmit =
        _fields.trimmedName.isNotEmpty &&
        _fields.trimmedKey.isNotEmpty &&
        exportKeyError(_fields.key.text, original: editing?.exportKey) ==
            null &&
        _formula.text.trim().isNotEmpty &&
        formulaError == null;
    return MetaRowDialogFrame(
      title: editing == null ? 'Add Derived Stat' : 'Edit Derived Stat',
      editing: editing != null,
      canSubmit: canSubmit,
      width: 560,
      onSubmit: () => widget.onSubmit(
        DerivedStatInput(
          displayName: _fields.trimmedName,
          exportKey: _fields.trimmedKey,
          formula: _formula.text.trim(),
          outputType: _outputType,
          roundingMode: _roundingMode,
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
          TextField(
            key: const ValueKey('derived-stat-formula'),
            controller: _formula,
            minLines: 2,
            maxLines: 4,
            style: ForgeType.code(size: 13.6, color: context.colors.onSurface),
            decoration: InputDecoration(
              labelText: 'Formula *',
              helperText:
                  'Reference primary stats by export key. E.g., '
                  '(strength * 2) + (vitality * 5)',
              helperMaxLines: 2,
              errorText: formulaError,
              errorMaxLines: 3,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AnvilSpacing.md),
          Row(
            children: [
              SizedBox(
                width: 160,
                child: MetaPicker<DerivedStatOutputType>(
                  key: const ValueKey('derived-stat-output'),
                  label: 'Output Type',
                  value: _outputType,
                  values: DerivedStatOutputType.values,
                  labelOf: _outputLabel,
                  onChanged: (v) => setState(() => _outputType = v),
                ),
              ),
              const SizedBox(width: AnvilSpacing.md),
              SizedBox(
                width: 160,
                child: MetaPicker<RoundingMode>(
                  key: const ValueKey('derived-stat-rounding'),
                  label: 'Rounding',
                  value: _roundingMode,
                  values: RoundingMode.values,
                  labelOf: _roundingLabel,
                  onChanged: (v) => setState(() => _roundingMode = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
