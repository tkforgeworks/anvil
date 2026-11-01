/// The editor's validation summary and per-field lookups (0.1.6
/// `ValidationBanner.tsx` and `fieldValidationProps.ts`, design §10.2).
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:forge_ui/forge_ui.dart';

import '../../theme/anvil_metrics.dart';

/// The record's validation issues from the last save
/// (`recordValidationProvider`): nothing while [issues] is empty, otherwise
/// a block titled `Validation: 2 errors, 1 warning` with one line per issue,
/// `field: message` when the issue names a field.
///
/// Errors come first, then warnings, then anything else, each group in the
/// engine's order; 0.1.6 listed the issues in the engine's order. The block
/// is error-tinted while there is an error and warning-tinted otherwise;
/// error lines use the error colour and the others the warning colour, as
/// 0.1.6's MUI `Alert` did.
class ValidationBanner extends StatelessWidget {
  const ValidationBanner(this.issues, {super.key});

  final List<ValidationIssue> issues;

  /// 0.1.6's title: the error and warning counts, singular for one; other
  /// severities are listed but not counted.
  static String title(List<ValidationIssue> issues) {
    final errors = _count(issues, ValidationSeverity.error);
    final warnings = _count(issues, ValidationSeverity.warning);
    return 'Validation: ${[if (errors > 0) _plural(errors, 'error'), if (warnings > 0) _plural(warnings, 'warning')].join(', ')}';
  }

  /// [issues] with errors first, then warnings, then the rest.
  static List<ValidationIssue> ordered(List<ValidationIssue> issues) => [
    for (final s in [ValidationSeverity.error, ValidationSeverity.warning])
      ...issues.where((i) => i.severity == s),
    ...issues.where(
      (i) =>
          i.severity != ValidationSeverity.error &&
          i.severity != ValidationSeverity.warning,
    ),
  ];

  static int _count(List<ValidationIssue> issues, ValidationSeverity s) =>
      issues.where((i) => i.severity == s).length;

  static String _plural(int n, String word) =>
      '$n ${n == 1 ? word : '${word}s'}';

  @override
  Widget build(BuildContext context) {
    if (issues.isEmpty) return const SizedBox.shrink();
    final hasErrors = issues.any((i) => i.severity == ValidationSeverity.error);
    final forge = context.forge;
    final accent = hasErrors ? context.colors.error : forge.warning;
    return Container(
      key: const ValueKey('validation-banner'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AnvilSpacing.md),
      padding: const EdgeInsets.all(AnvilSpacing.md),
      decoration: BoxDecoration(
        color: hasErrors ? forge.errorTint : forge.warningContainer,
        borderRadius: BorderRadius.circular(ForgeRadii.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasErrors ? Icons.error_outline : Icons.warning_amber,
            color: accent,
            size: 20,
          ),
          const SizedBox(width: AnvilSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title(issues), style: context.text.titleSmall),
                const SizedBox(height: AnvilSpacing.xs),
                for (final issue in ordered(issues))
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${issue.field == null ? '' : '${issue.field}: '}'
                      '${issue.message}',
                      style: context.text.bodyMedium?.copyWith(
                        color: issue.severity == ValidationSeverity.error
                            ? context.colors.error
                            : forge.warning,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The first of [issues] about [field] (a `ValidationIssue.field` value
/// such as `rarityId` or `custom:damage`), or null; 0.1.6's
/// `fieldValidationProps` over `issuesForField(field)`.
ValidationIssue? fieldIssue(List<ValidationIssue> issues, String field) {
  for (final issue in issues) {
    if (issue.field == field) return issue;
  }
  return null;
}

/// The message of [fieldIssue], for a field's error or helper text.
String? fieldIssueText(List<ValidationIssue> issues, String field) =>
    fieldIssue(issues, field)?.message;
