/// The meta tables of the Project Settings dialog: 0.1.6's
/// `MetaListSection.tsx` and `MetaRowActions.tsx`, plus the pieces the
/// rarity and derived stat sections share with it.
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:forge_ui/forge_ui.dart';

import '../../theme/anvil_metrics.dart';
import 'meta_buffer.dart';

/// A section's title, description and (unless compact) its Add button.
class MetaSectionHeader extends StatelessWidget {
  const MetaSectionHeader({
    super.key,
    required this.title,
    this.description,
    this.trailing,
  });

  final String title;
  final String? description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final description = this.description;
    return Padding(
      padding: const EdgeInsets.only(bottom: AnvilSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSmall),
                if (description != null)
                  Text(
                    description,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// The section's Add button (0.1.6: outlined, small, `+ Add`).
class MetaAddButton extends StatelessWidget {
  const MetaAddButton({super.key, required this.onPressed, this.label = 'Add'});

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: const Icon(Icons.add, size: 18),
    label: Text(label),
  );
}

/// A refusal or failure shown above a section's table until dismissed
/// (0.1.6's `<Alert severity="error" onClose>`).
class MetaSectionError extends StatelessWidget {
  const MetaSectionError({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AnvilSpacing.sm),
    child: Semantics(
      liveRegion: true,
      child: ForgeErrorCard(
        message: message,
        onRetry: onDismiss,
        retryLabel: 'Dismiss',
      ),
    ),
  );
}

/// `None defined.`
class MetaNoneDefined extends StatelessWidget {
  const MetaNoneDefined({super.key, this.text = 'None defined.'});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: context.text.bodyMedium?.copyWith(
      color: context.colors.onSurfaceVariant,
    ),
  );
}

/// A column of a [MetaTable]: a flexible share of the width, or a fixed
/// [width].
class MetaColumn {
  const MetaColumn(this.label, {this.flex = 1, this.width});

  final String label;
  final int flex;
  final double? width;
}

/// One row of a [MetaTable].
class MetaTableRow {
  const MetaTableRow({
    required this.key,
    required this.cells,
    required this.actions,
    this.selected = false,
    this.onTap,
  });

  final Key key;
  final List<Widget> cells;

  /// The row's [MetaRowActions]; its column is as wide as its content, as
  /// 0.1.6's `width: 1%` + `nowrap` cell (ANVL-144).
  final Widget actions;
  final bool selected;

  /// Makes the row selectable (the Custom Fields rail).
  final VoidCallback? onTap;
}

/// The small table 0.1.6 drew with MUI `Table size="small"`: a header row,
/// then one row per entry with a divider between, and the actions last.
class MetaTable extends StatelessWidget {
  const MetaTable({
    super.key,
    required this.columns,
    required this.rows,
    this.actionCount = 4,
  });

  final List<MetaColumn> columns;
  final List<MetaTableRow> rows;

  /// How many [MetaActionButton]s each row's actions hold; the actions
  /// column is exactly that wide, so header and rows line up.
  final int actionCount;

  static const _cellPadding = EdgeInsets.symmetric(horizontal: AnvilSpacing.sm);

  Widget _cell(MetaColumn column, Widget child) {
    final padded = Padding(padding: _cellPadding, child: child);
    final width = column.width;
    return width == null
        ? Expanded(flex: column.flex, child: padded)
        : SizedBox(width: width + _cellPadding.horizontal, child: padded);
  }

  double get actionsWidth => actionCount * MetaActionButton.size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final divider = Divider(height: 1, color: context.forge.rowDivider);
    final header = context.text.labelMedium?.copyWith(
      color: c.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 36,
          child: Row(
            children: [
              for (final col in columns)
                _cell(col, Text(col.label, style: header)),
              Padding(
                padding: _cellPadding,
                child: Text('Actions', style: header),
              ),
            ],
          ),
        ),
        divider,
        for (final row in rows) ...[
          Material(
            key: row.key,
            color: row.selected
                ? c.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            child: InkWell(
              onTap: row.onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40),
                child: Row(
                  children: [
                    for (var i = 0; i < columns.length; i++)
                      _cell(columns[i], row.cells[i]),
                    SizedBox(
                      width: actionsWidth,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: row.actions,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          divider,
        ],
      ],
    );
  }
}

/// One icon button of a row's actions, at a fixed [size] so the actions
/// column has a known width.
class MetaActionButton extends StatelessWidget {
  const MetaActionButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color,
  });

  static const size = 36.0;

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    iconSize: 18,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints.tightFor(width: size, height: size),
    style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
    color: color,
    onPressed: onPressed,
    icon: Icon(icon),
  );
}

/// Move up, move down, edit and delete (0.1.6 `MetaRowActions`). Taps never
/// reach the row, so the cell is safe in selectable rows.
class MetaRowActions extends StatelessWidget {
  const MetaRowActions({
    super.key,
    required this.isFirst,
    required this.isLast,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onEdit,
    required this.onDelete,
  });

  final bool isFirst;
  final bool isLast;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      MetaActionButton(
        tooltip: 'Move up',
        icon: Icons.arrow_upward,
        onPressed: isFirst ? null : onMoveUp,
      ),
      MetaActionButton(
        tooltip: 'Move down',
        icon: Icons.arrow_downward,
        onPressed: isLast ? null : onMoveDown,
      ),
      MetaActionButton(tooltip: 'Edit', icon: Icons.edit, onPressed: onEdit),
      MetaActionButton(
        tooltip: 'Delete',
        icon: Icons.delete,
        color: context.colors.error,
        onPressed: onDelete,
      ),
    ],
  );
}

/// An export key as 0.1.6 showed it in a table cell.
class ExportKeyText extends StatelessWidget {
  const ExportKeyText(this.exportKey, {super.key});

  final String exportKey;

  @override
  Widget build(BuildContext context) => Text(
    exportKey,
    overflow: TextOverflow.ellipsis,
    style: ForgeType.code(size: 12.8, color: context.colors.onSurface),
  );
}

/// The message for [key] typed in a row dialog: null when it is empty
/// (the dialog's Add stays disabled then), unchanged from [original], or
/// matches [metaExportKeyPattern].
String? exportKeyError(String key, {String? original}) {
  final k = key.trim();
  if (k.isEmpty || k == original) return null;
  return metaExportKeyPattern.hasMatch(k) ? null : metaExportKeyPatternMessage;
}

/// The display name and export key fields every row dialog starts with;
/// the key follows the name through [slugifyMetaKey] until it is typed in,
/// as 0.1.6's `exportKeyTouched`.
class NameKeyControllers {
  NameKeyControllers({
    String name = '',
    String key = '',
    this.keyTouched = false,
  }) : name = TextEditingController(text: name),
       key = TextEditingController(text: key);

  final TextEditingController name;
  final TextEditingController key;

  /// Whether the key was typed in (or came from a stored row), which stops
  /// it following the name.
  bool keyTouched;

  void nameChanged(String value) {
    if (!keyTouched) key.text = slugifyMetaKey(value);
  }

  void keyChanged(String _) => keyTouched = true;

  String get trimmedName => name.text.trim();
  String get trimmedKey => key.text.trim();

  void dispose() {
    name.dispose();
    key.dispose();
  }
}

/// The two fields of [NameKeyControllers], with the key's pattern error.
class NameKeyFields extends StatelessWidget {
  const NameKeyFields({
    super.key,
    required this.controllers,
    required this.onChanged,
    this.originalKey,
    this.enabled = true,
  });

  final NameKeyControllers controllers;
  final VoidCallback onChanged;
  final String? originalKey;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        key: const ValueKey('meta-row-name'),
        controller: controllers.name,
        autofocus: true,
        enabled: enabled,
        decoration: const InputDecoration(labelText: 'Display Name *'),
        onChanged: (v) {
          controllers.nameChanged(v);
          onChanged();
        },
      ),
      const SizedBox(height: AnvilSpacing.md),
      TextField(
        key: const ValueKey('meta-row-key'),
        controller: controllers.key,
        enabled: enabled,
        style: ForgeType.code(color: context.colors.onSurface),
        decoration: InputDecoration(
          labelText: 'Export Key *',
          hintText: 'auto',
          errorText: exportKeyError(
            controllers.key.text,
            original: originalKey,
          ),
        ),
        onChanged: (v) {
          controllers.keyChanged(v);
          onChanged();
        },
      ),
    ],
  );
}

/// The frame of a row dialog: title, fields, the submit's refusal, and
/// Cancel with Add (new) or Save (edit). [onSubmit] answers null to close
/// the dialog or the message to show in it.
class MetaRowDialogFrame extends StatefulWidget {
  const MetaRowDialogFrame({
    super.key,
    required this.title,
    required this.editing,
    required this.canSubmit,
    required this.onSubmit,
    required this.child,
    this.width = 400,
  });

  final String title;
  final bool editing;
  final bool canSubmit;
  final Future<String?> Function() onSubmit;
  final Widget child;
  final double width;

  @override
  State<MetaRowDialogFrame> createState() => _MetaRowDialogFrameState();
}

class _MetaRowDialogFrameState extends State<MetaRowDialogFrame> {
  var _busy = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onSubmit();
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: widget.width,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    key: const ValueKey('meta-row-dialog-error'),
                    style: context.text.bodyMedium?.copyWith(
                      color: context.colors.error,
                    ),
                  ),
                ),
                const SizedBox(height: AnvilSpacing.md),
              ],
              widget.child,
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('meta-row-dialog-submit'),
          onPressed: widget.canSubmit && !_busy ? _submit : null,
          child: Text(widget.editing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

/// A row of a display name + export key list.
class MetaListRow {
  const MetaListRow({
    required this.id,
    required this.displayName,
    required this.exportKey,
  });

  final String id;
  final String displayName;
  final String exportKey;
}

/// 0.1.6's `MetaListSection`: a titled table of display name + export key
/// rows with add, edit, delete and move up / down.
///
/// The callbacks answer null on success or the message to show: [onAdd]
/// and [onUpdate] in the row dialog, [onDelete] and [onMove] above the
/// table. Whether they write to a buffer or to the database is the
/// owner's business. [compact] hides the export key column and puts a
/// full-width `Add <singular>` button below the list; with [onSelectItem]
/// rows are selectable and [selectedId] shows as selected (the Custom
/// Fields rail, ANVL-123).
class MetaListSection extends StatefulWidget {
  const MetaListSection({
    super.key,
    required this.title,
    required this.singularName,
    this.description,
    required this.rows,
    required this.onAdd,
    required this.onUpdate,
    required this.onDelete,
    required this.onMove,
    this.compact = false,
    this.selectedId,
    this.onSelectItem,
  });

  final String title;
  final String singularName;
  final String? description;
  final List<MetaListRow> rows;
  final Future<String?> Function(MetaItemInput input) onAdd;
  final Future<String?> Function(String id, MetaItemInput input) onUpdate;
  final Future<String?> Function(String id) onDelete;
  final Future<String?> Function(int from, int to) onMove;
  final bool compact;
  final String? selectedId;
  final ValueChanged<MetaListRow>? onSelectItem;

  @override
  State<MetaListSection> createState() => _MetaListSectionState();
}

class _MetaListSectionState extends State<MetaListSection> {
  String? _error;

  Future<void> _openDialog([MetaListRow? editing]) => showDialog<void>(
    context: context,
    builder: (_) => _MetaRowDialog(
      singularName: widget.singularName,
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
    final onSelect = widget.onSelectItem;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MetaSectionHeader(
          title: widget.title,
          description: widget.description,
          trailing: widget.compact
              ? null
              : MetaAddButton(onPressed: () => _openDialog()),
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
            columns: [
              const MetaColumn('Name'),
              if (!widget.compact) const MetaColumn('Export Key'),
            ],
            rows: [
              for (var i = 0; i < rows.length; i++)
                MetaTableRow(
                  key: ValueKey('meta-row-${rows[i].id}'),
                  selected: widget.selectedId == rows[i].id,
                  onTap: onSelect == null ? null : () => onSelect(rows[i]),
                  cells: [
                    Text(rows[i].displayName, overflow: TextOverflow.ellipsis),
                    if (!widget.compact) ExportKeyText(rows[i].exportKey),
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
        if (widget.compact) ...[
          const SizedBox(height: AnvilSpacing.sm),
          MetaAddButton(
            label: 'Add ${widget.singularName}',
            onPressed: () => _openDialog(),
          ),
        ],
      ],
    );
  }
}

class _MetaRowDialog extends StatefulWidget {
  const _MetaRowDialog({
    required this.singularName,
    required this.editing,
    required this.onSubmit,
  });

  final String singularName;
  final MetaListRow? editing;
  final Future<String?> Function(MetaItemInput input) onSubmit;

  @override
  State<_MetaRowDialog> createState() => _MetaRowDialogState();
}

class _MetaRowDialogState extends State<_MetaRowDialog> {
  late final _fields = NameKeyControllers(
    name: widget.editing?.displayName ?? '',
    key: widget.editing?.exportKey ?? '',
    keyTouched: widget.editing != null,
  );

  @override
  void dispose() {
    _fields.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing;
    final canSubmit =
        _fields.trimmedName.isNotEmpty &&
        _fields.trimmedKey.isNotEmpty &&
        exportKeyError(_fields.key.text, original: editing?.exportKey) == null;
    return MetaRowDialogFrame(
      title: '${editing == null ? 'Add' : 'Edit'} ${widget.singularName}',
      editing: editing != null,
      canSubmit: canSubmit,
      onSubmit: () => widget.onSubmit(
        MetaItemInput(
          displayName: _fields.trimmedName,
          exportKey: _fields.trimmedKey,
        ),
      ),
      child: NameKeyFields(
        controllers: _fields,
        originalKey: editing?.exportKey,
        onChanged: () => setState(() {}),
      ),
    );
  }
}

/// A labelled `DropdownButton` (never `DropdownMenu`, design §8.7);
/// [enabled] false shows the value without letting it change.
class MetaPicker<T> extends StatelessWidget {
  const MetaPicker({
    super.key,
    required this.label,
    required this.value,
    required this.values,
    required this.labelOf,
    required this.onChanged,
    this.enabled = true,
    this.helperText,
  });

  final String label;
  final bool enabled;
  final String? helperText;
  final T value;
  final List<T> values;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(
      labelText: label,
      helperText: helperText,
      enabled: enabled,
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        isDense: true,
        isExpanded: true,
        items: [
          for (final v in values)
            DropdownMenuItem(value: v, child: Text(labelOf(v))),
        ],
        onChanged: enabled
            ? (v) {
                if (v != null) onChanged(v);
              }
            : null,
      ),
    ),
  );
}
