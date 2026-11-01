/// The Custom Fields tab: 0.1.6's `CustomFieldsSection`, `FieldList` and
/// `FieldDialog` (`ProjectSettingsTab.tsx`). Every change is written at
/// once through [CustomFieldsTabController].
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../../theme/anvil_metrics.dart';
import 'custom_fields_controller.dart';
import 'meta_list_section.dart';

/// 0.1.6 `FIELD_TYPE_LABELS`.
String customFieldTypeLabel(CustomFieldType type) => switch (type) {
  CustomFieldType.text => 'Text',
  CustomFieldType.integer => 'Integer',
  CustomFieldType.decimal => 'Decimal',
  CustomFieldType.boolean => 'Boolean',
  CustomFieldType.enumeration => 'Enum',
};

class CustomFieldsSection extends ConsumerWidget {
  const CustomFieldsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(customFieldsTabProvider);
    final controller = ref.read(customFieldsTabProvider.notifier);
    final secondary = context.text.bodySmall?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    final s = async.value;
    if (s == null) {
      return async.hasError
          ? ForgeErrorCard(message: '${async.error}')
          : const Text('Loading custom fields...');
    }
    final selected = s.selected;
    final selectedRow = s.selectedRow;

    Widget rail(
      CustomFieldScope type,
      String title,
      String singular,
      String description,
    ) => MetaListSection(
      key: ValueKey('rail-${type.value}'),
      title: title,
      singularName: singular,
      description: description,
      compact: true,
      rows: [
        for (final r in s.rowsOf(type))
          MetaListRow(
            id: r.id,
            displayName: r.displayName,
            exportKey: r.exportKey,
          ),
      ],
      selectedId: selected?.type == type ? selected?.id : null,
      onSelectItem: (row) => controller.select((type: type, id: row.id)),
      onAdd: (input) => controller.addScopeRow(type, input),
      onUpdate: (id, input) => controller.updateScopeRow(type, id, input),
      onDelete: (id) => controller.deleteScopeRow(type, id),
      onMove: (from, to) => controller.moveScopeRow(type, from, to),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Custom Fields', style: context.text.titleSmall),
        const SizedBox(height: AnvilSpacing.xs),
        Text(
          'Manage item categories and NPC types, and define custom fields '
          'for each. Select a category or type to edit its fields.',
          style: secondary,
        ),
        const SizedBox(height: AnvilSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 320,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  rail(
                    CustomFieldScope.itemCategory,
                    'Item Categories',
                    'Item Category',
                    'Categories used to organize items.',
                  ),
                  const Divider(height: AnvilSpacing.xl),
                  rail(
                    CustomFieldScope.npcType,
                    'NPC Types',
                    'NPC Type',
                    'Types used to categorize NPCs.',
                  ),
                ],
              ),
            ),
            const SizedBox(width: AnvilSpacing.lg),
            Expanded(
              child: selected == null || selectedRow == null
                  ? Text(
                      'Select a category or type on the left to manage its '
                      'custom fields.',
                      style: context.text.bodyMedium?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                selectedRow.displayName,
                                key: const ValueKey('custom-fields-scope'),
                                style: context.text.titleLarge,
                              ),
                            ),
                            Text(
                              selected.type == CustomFieldScope.itemCategory
                                  ? 'Item Category'
                                  : 'NPC Type',
                              style: secondary,
                            ),
                          ],
                        ),
                        const SizedBox(height: AnvilSpacing.md),
                        FieldList(
                          key: ValueKey(
                            '${selected.type.value}:${selected.id}',
                          ),
                          scope: selected,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The definitions of one scope with Add Field, edit and delete.
class FieldList extends ConsumerStatefulWidget {
  const FieldList({super.key, required this.scope});

  final CustomFieldScopeRef scope;

  @override
  ConsumerState<FieldList> createState() => _FieldListState();
}

class _FieldListState extends ConsumerState<FieldList> {
  String? _deleteError;

  Future<void> _openDialog([CustomFieldDefinition? editing]) async {
    setState(() => _deleteError = null);
    await showDialog<void>(
      context: context,
      builder: (_) => FieldDialog(scope: widget.scope, editing: editing),
    );
  }

  Future<void> _delete(CustomFieldDefinition def) async {
    setState(() => _deleteError = null);
    final error = await ref
        .read(customFieldsTabProvider.notifier)
        .deleteField(def.id);
    if (mounted && error != null) setState(() => _deleteError = error);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(customFieldDefinitionsProvider(widget.scope));
    final defs = async.value;
    final error = _deleteError;
    final center = context.text.bodyMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null)
          MetaSectionError(
            message: error,
            onDismiss: () => setState(() => _deleteError = null),
          ),
        if (defs == null)
          async.hasError
              ? ForgeErrorCard(message: '${async.error}')
              : const SizedBox.shrink()
        else if (defs.isEmpty)
          const MetaNoneDefined(text: 'No custom fields defined.')
        else
          MetaTable(
            columns: const [
              MetaColumn('Field Name', flex: 3),
              MetaColumn('Type', flex: 2),
              MetaColumn('Required', width: 72),
              MetaColumn('Searchable', width: 80),
            ],
            actionCount: 2,
            rows: [
              for (final def in defs)
                MetaTableRow(
                  key: ValueKey('field-row-${def.id}'),
                  cells: [
                    Text(def.fieldName, overflow: TextOverflow.ellipsis),
                    Text(customFieldTypeLabel(def.fieldType)),
                    Text(def.isRequired ? '✓' : '—', style: center),
                    Text(def.isSearchable ? '✓' : '—', style: center),
                  ],
                  actions: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MetaActionButton(
                        tooltip: 'Edit',
                        icon: Icons.edit,
                        onPressed: () => _openDialog(def),
                      ),
                      MetaActionButton(
                        tooltip: 'Delete',
                        icon: Icons.delete,
                        color: context.colors.error,
                        onPressed: () => _delete(def),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        const SizedBox(height: AnvilSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: MetaAddButton(
            label: 'Add Field',
            onPressed: () => _openDialog(),
          ),
        ),
      ],
    );
  }
}

/// 0.1.6 `FieldDialog`: add or edit one definition, written on submit. The
/// field type is fixed once created; the repository's refusals (an enum
/// option in use, a duplicate name) show at the top and keep the dialog
/// open.
class FieldDialog extends ConsumerStatefulWidget {
  const FieldDialog({super.key, required this.scope, this.editing});

  final CustomFieldScopeRef scope;
  final CustomFieldDefinition? editing;

  @override
  ConsumerState<FieldDialog> createState() => _FieldDialogState();
}

class _FieldDialogState extends ConsumerState<FieldDialog> {
  late final _name = TextEditingController(
    text: widget.editing?.fieldName ?? '',
  );
  late final _default = TextEditingController(
    text: widget.editing?.defaultValue ?? '',
  );
  final _newOption = TextEditingController();
  late var _type = widget.editing?.fieldType ?? CustomFieldType.text;
  late var _required = widget.editing?.isRequired ?? false;
  late var _searchable = widget.editing?.isSearchable ?? false;
  late final _options = [...?widget.editing?.enumOptions];
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _default.dispose();
    _newOption.dispose();
    super.dispose();
  }

  void _addOption() {
    final option = _newOption.text.trim();
    if (option.isEmpty || _options.contains(option)) return;
    setState(() {
      _options.add(option);
      _newOption.clear();
    });
  }

  Future<void> _save() async {
    final controller = ref.read(customFieldsTabProvider.notifier);
    final editing = widget.editing;
    final name = _name.text.trim();
    // 0.1.6 `defaultValue || null`.
    final defaultValue = _default.text.isEmpty ? null : _default.text;
    final isEnum = _type == CustomFieldType.enumeration;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = editing == null
        ? await controller.createField(
            CreateCustomFieldDefinitionInput(
              scopeType: widget.scope.type,
              scopeId: widget.scope.id,
              fieldName: name,
              fieldType: _type,
              defaultValue: defaultValue,
              enumOptions: isEnum ? _options : const [],
              isRequired: _required,
              isSearchable: _searchable,
            ),
          )
        : await controller.updateField(
            editing.id,
            UpdateCustomFieldDefinitionInput(
              fieldName: name,
              defaultValue: defaultValue,
              enumOptions: isEnum ? _options : null,
              isRequired: _required,
              isSearchable: _searchable,
            ),
          );
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
    final editing = widget.editing;
    final isEnum = _type == CustomFieldType.enumeration;
    final canSave =
        _name.text.trim().isNotEmpty &&
        (!isEnum || _options.isNotEmpty) &&
        !_busy;
    final error = _error;
    final secondary = context.text.bodyMedium?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    return AlertDialog(
      title: Text(
        editing == null
            ? 'Add Custom Field'
            : 'Edit Field: ${editing.fieldName}',
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null) ...[
                Semantics(
                  liveRegion: true,
                  child: ForgeErrorCard(
                    key: const ValueKey('field-dialog-error'),
                    message: error,
                  ),
                ),
                const SizedBox(height: AnvilSpacing.md),
              ],
              TextField(
                key: const ValueKey('field-name'),
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Field Name *'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AnvilSpacing.md),
              MetaPicker<CustomFieldType>(
                key: const ValueKey('field-type'),
                label: 'Field Type',
                value: _type,
                values: CustomFieldType.values,
                labelOf: customFieldTypeLabel,
                enabled: editing == null,
                helperText: editing == null
                    ? null
                    : 'Field type cannot be changed after creation.',
                onChanged: (t) => setState(() => _type = t),
              ),
              const SizedBox(height: AnvilSpacing.md),
              if (isEnum) ...[
                Text('Enum Options', style: context.text.titleSmall),
                const SizedBox(height: AnvilSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('field-new-option'),
                        controller: _newOption,
                        decoration: const InputDecoration(
                          labelText: 'New option',
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _addOption(),
                      ),
                    ),
                    const SizedBox(width: AnvilSpacing.sm),
                    OutlinedButton(
                      onPressed: _newOption.text.trim().isEmpty
                          ? null
                          : _addOption,
                      child: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: AnvilSpacing.sm),
                if (_options.isEmpty)
                  Text(
                    'No options defined. Add at least one.',
                    style: secondary,
                  )
                else
                  Wrap(
                    spacing: AnvilSpacing.sm,
                    runSpacing: AnvilSpacing.sm,
                    children: [
                      for (final option in _options)
                        InputChip(
                          key: ValueKey('field-option-$option'),
                          label: Text(option),
                          onDeleted: () =>
                              setState(() => _options.remove(option)),
                        ),
                    ],
                  ),
              ] else
                TextField(
                  key: const ValueKey('field-default'),
                  controller: _default,
                  decoration: const InputDecoration(
                    labelText: 'Default Value',
                    helperText:
                        'Optional. Pre-populated when a new record is created.',
                  ),
                ),
              const SizedBox(height: AnvilSpacing.md),
              Row(
                children: [
                  _CheckLabel(
                    label: 'Required',
                    value: _required,
                    onChanged: (v) => setState(() => _required = v),
                  ),
                  const SizedBox(width: AnvilSpacing.md),
                  _CheckLabel(
                    label: 'Searchable / Filterable',
                    value: _searchable,
                    onChanged: (v) => setState(() => _searchable = v),
                  ),
                ],
              ),
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
          key: const ValueKey('field-dialog-submit'),
          onPressed: canSave ? _save : null,
          child: Text(editing == null ? 'Add Field' : 'Save Changes'),
        ),
      ],
    );
  }
}

class _CheckLabel extends StatelessWidget {
  const _CheckLabel({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => onChanged(!value),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
        Text(label),
      ],
    ),
  );
}
