/// The Custom Fields tab of the item editor (0.1.6 `CustomFieldsPanel.tsx`
/// with `scopeType="item_category"`): one control per definition of the
/// draft's category, bound to the draft's values.
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:forge_ui/forge_ui.dart';

import '../../editor/widgets/draft_text_field.dart';
import '../../editor/widgets/validation_banner.dart';
import '../../theme/anvil_metrics.dart';

import 'package:anvil/app/editor/widgets/draft_picker.dart';

/// 0.1.6's inline message for a required field left empty.
const requiredFieldMessage = 'This field is required.';

/// The validation issue field of custom field [definition]
/// (`custom:<field name>`, as the validation engine names it).
String customFieldIssueField(CustomFieldDefinition definition) =>
    'custom:${definition.fieldName}';

/// Text, integer and decimal fields are [DraftTextField]s, an enum a
/// picker with `None` first, a boolean a checkbox storing `true` /
/// `false`, as 0.1.6. A required field carries ` *` and, while empty,
/// 0.1.6's `This field is required.`; otherwise the field shows its issue
/// from the last validation ([issues]). Neither blocks Save: an empty
/// required field is a validation error after save (ANVL-180).
///
/// 0.1.6 saved the panel on its own `Save Custom Fields` button and asked
/// for the item to be saved first when the details were dirty; here the
/// values are part of the draft, saved and undone with the rest.
class ItemCustomFieldsPanel extends StatelessWidget {
  const ItemCustomFieldsPanel({
    super.key,
    required this.definitions,
    required this.values,
    required this.issues,
    required this.onChanged,
  });

  /// The definitions scoped to the draft's category; null while loading.
  final List<CustomFieldDefinition>? definitions;

  /// The draft's custom field values by definition id.
  final Map<String, String?> values;
  final List<ValidationIssue> issues;

  /// A new value for a definition; [typing] for text input.
  final void Function(String definitionId, String? value, {bool typing})
  onChanged;

  static Key fieldKey(String definitionId) =>
      ValueKey('item-custom-field-$definitionId');

  @override
  Widget build(BuildContext context) {
    final muted = context.text.bodyMedium?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    final definitions = this.definitions;
    if (definitions == null) {
      return Text('Loading custom fields…', style: muted);
    }
    if (definitions.isEmpty) {
      return Text(
        'No custom fields defined for this item category.',
        style: muted,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Custom Fields', style: context.text.titleSmall),
        const SizedBox(height: AnvilSpacing.sm),
        for (final definition in definitions) ...[
          _field(context, definition),
          const SizedBox(height: AnvilSpacing.md),
        ],
      ],
    );
  }

  Widget _field(BuildContext context, CustomFieldDefinition definition) {
    final id = definition.id;
    final value = values[id] ?? '';
    final requiredEmpty = definition.isRequired && value.isEmpty;
    final issue = fieldIssue(issues, customFieldIssueField(definition));
    final message = requiredEmpty ? requiredFieldMessage : issue?.message;
    final severity = requiredEmpty
        ? ValidationSeverity.error
        : issue?.severity ?? ValidationSeverity.error;
    final label = definition.isRequired
        ? '${definition.fieldName} *'
        : definition.fieldName;

    switch (definition.fieldType) {
      case CustomFieldType.boolean:
        return Column(
          key: fieldKey(id),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: value == 'true',
                  onChanged: (checked) =>
                      onChanged(id, checked == true ? 'true' : 'false'),
                ),
                Text(definition.fieldName),
                if (definition.isRequired) ...[
                  const SizedBox(width: AnvilSpacing.xs),
                  Text(
                    '*',
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.error,
                    ),
                  ),
                ],
              ],
            ),
            if (issue != null)
              Text(
                issue.message,
                style: context.text.bodySmall?.copyWith(
                  color: issue.severity == ValidationSeverity.error
                      ? context.colors.error
                      : context.forge.warning,
                ),
              ),
          ],
        );
      case CustomFieldType.enumeration:
        return DraftPicker<String?>(
          key: fieldKey(id),
          label: definition.fieldName,
          isRequired: definition.isRequired,
          value: value.isEmpty ? null : value,
          options: [
            (value: null, label: 'None'),
            for (final option in definition.enumOptions)
              (value: option, label: option),
          ],
          errorText: severity == ValidationSeverity.error ? message : null,
          helperText: severity == ValidationSeverity.error ? null : message,
          onChanged: (v) => onChanged(id, v),
        );
      case CustomFieldType.text:
      case CustomFieldType.integer:
      case CustomFieldType.decimal:
        return DraftTextField(
          key: fieldKey(id),
          label: label,
          value: value,
          issueMessage: message,
          issueSeverity: severity,
          onChanged: (text) => onChanged(id, text, typing: true),
        );
    }
  }
}
