/// The project-wide validation panel at `/validation` (design §10.2; 0.1.6
/// `ValidationPage.tsx`): every issue of the last pass grouped by domain,
/// errors first, with a click through to the record and Re-run.
library;

import 'dart:async';

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../lists/empty_state.dart';
import '../settings/project/project_settings_dialog.dart';
import '../shell/open_editor.dart';
import '../shell/shell_providers.dart';
import '../theme/anvil_metrics.dart';
import 'last_checked.dart';
import 'validation_grouping.dart';

/// Reads `validationIssuesProvider`, which already runs the pass on a
/// background isolate on open and after every write; the page does not
/// start a run of its own when it opens. While a run is in flight the
/// previous list stays on screen and the button reads `Running...`.
class ValidationPage extends ConsumerWidget {
  const ValidationPage({super.key});

  static const rerunKey = ValueKey('validation-rerun');
  static const emptyKey = ValueKey('validation-empty');
  static const errorChipKey = ValueKey('validation-errors');
  static const warningChipKey = ValueKey('validation-warnings');

  /// The row of the [index]th issue of [domain]'s group.
  static ValueKey<String> rowKey(ValidationDomain domain, int index) =>
      ValueKey('validation-row-${domain.value}-$index');

  /// The heading of [domain]'s group.
  static ValueKey<String> groupKey(ValidationDomain domain) =>
      ValueKey('validation-group-${domain.value}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(validationIssuesProvider);
    final lastChecked = ref.watch(validationLastCheckedProvider);
    final running = result.isLoading;
    final issues = result.value;
    final muted = context.colors.onSurfaceVariant;

    void rerun() => unawaited(
      ref
          .read(validationIssuesProvider.notifier)
          .refresh()
          .then<void>((_) {}, onError: (Object _) {}),
    );

    final Widget body;
    if (issues == null) {
      body = result.hasError && !running
          ? ForgeErrorCard(
              message: 'Validation failed: ${result.error}',
              onRetry: rerun,
              retryLabel: 'Re-run',
            )
          : const Center(child: CircularProgressIndicator());
    } else if (issues.isEmpty && !running) {
      body = SingleChildScrollView(
        child: DecoratedBox(
          key: emptyKey,
          decoration: BoxDecoration(
            border: Border.all(color: context.colors.outlineVariant),
            borderRadius: BorderRadius.circular(AnvilRadii.panel),
          ),
          child: const Center(
            child: EmptyState(
              icon: Icons.check_circle_outline,
              title: 'No issues found',
              body: 'All records passed validation checks.',
            ),
          ),
        ),
      );
    } else {
      final groups = groupIssuesByDomain(issues);
      body = SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, group) in groups.indexed) ...[
              if (i > 0) const SizedBox(height: AnvilSpacing.lg),
              Text(
                group.label,
                key: groupKey(group.domain),
                style: context.text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AnvilSpacing.sm),
              _IssueTable(
                group: group,
                onOpen: (issue) => _open(context, ref, issue),
              ),
            ],
          ],
        ),
      );
    }

    final counts = countIssues(issues ?? const []);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Validation',
                    style: context.text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (lastChecked != null)
                    Text(
                      'Last checked: ${formatLastChecked(lastChecked)}',
                      style: context.text.bodyMedium?.copyWith(color: muted),
                    ),
                ],
              ),
            ),
            OutlinedButton.icon(
              key: rerunKey,
              onPressed: running ? null : rerun,
              icon: const Icon(Icons.refresh),
              label: Text(running ? 'Running...' : 'Re-run'),
            ),
          ],
        ),
        const SizedBox(height: AnvilSpacing.md),
        if (result.hasError && issues != null && !running) ...[
          ForgeErrorCard(
            message: 'Validation failed: ${result.error}',
            onRetry: rerun,
            retryLabel: 'Re-run',
          ),
          const SizedBox(height: AnvilSpacing.md),
        ],
        if (issues != null && issues.isNotEmpty) ...[
          Wrap(
            spacing: AnvilSpacing.md,
            runSpacing: AnvilSpacing.sm,
            children: [
              if (counts.errors > 0)
                _CountChip(
                  key: errorChipKey,
                  icon: Icons.error,
                  label: errorsLabel(counts.errors),
                  color: context.colors.error,
                ),
              if (counts.warnings > 0)
                _CountChip(
                  key: warningChipKey,
                  icon: Icons.warning,
                  label: warningsLabel(counts.warnings),
                  color: context.forge.warning,
                ),
            ],
          ),
          const SizedBox(height: AnvilSpacing.md),
        ],
        Expanded(child: body),
      ],
    );
  }

  /// A record issue opens its editor the way the editing mode says; a
  /// derived stat issue opens Project Settings on Stats & Formulas.
  static void _open(BuildContext context, WidgetRef ref, ValidationIssue i) {
    switch (issueRoute(i)) {
      case RecordTarget(:final domain, :final id):
        openEditor(context, ref, domain, id);
      case SettingsTarget(:final tab):
        unawaited(showProjectSettingsDialog(context, ref, initialTab: tab));
    }
  }
}

/// 0.1.6's outlined count chip.
class _CountChip extends StatelessWidget {
  const _CountChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AnvilSpacing.md - AnvilSpacing.xs,
      vertical: AnvilSpacing.xs,
    ),
    decoration: BoxDecoration(
      border: Border.all(color: color),
      borderRadius: BorderRadius.circular(AnvilSpacing.md),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AnvilSpacing.xs),
        Text(label, style: context.text.bodyMedium?.copyWith(color: color)),
      ],
    ),
  );
}

/// One group's table: severity icon, `Record`, `Field`, `Message`, with the
/// 0.1.6 column widths (40, 220, 160, the rest).
class _IssueTable extends StatelessWidget {
  const _IssueTable({required this.group, required this.onOpen});

  static const iconWidth = 40.0;
  static const recordWidth = 220.0;
  static const fieldWidth = 160.0;

  final IssueGroup group;
  final void Function(ValidationIssue issue) onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final muted = c.onSurfaceVariant;
    Widget cells(List<Widget> children) => Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AnvilSpacing.md,
        vertical: AnvilSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: iconWidth, child: children[0]),
          SizedBox(width: recordWidth, child: children[1]),
          SizedBox(width: fieldWidth, child: children[2]),
          Expanded(child: children[3]),
        ],
      ),
    );
    final headerStyle = context.text.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: c.outlineVariant),
        borderRadius: BorderRadius.circular(AnvilRadii.panel),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AnvilRadii.panel),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            cells([
              const SizedBox.shrink(),
              Text('Record', style: headerStyle),
              Text('Field', style: headerStyle),
              Text('Message', style: headerStyle),
            ]),
            for (final (index, issue) in group.issues.indexed) ...[
              Divider(height: 1, thickness: 1, color: c.outlineVariant),
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  key: ValidationPage.rowKey(group.domain, index),
                  onTap: () => onOpen(issue),
                  child: cells([
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _SeverityIcon(issue.severity),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: AnvilSpacing.sm),
                      child: Text(
                        issue.recordDisplayName,
                        style: context.text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: AnvilSpacing.sm),
                      child: Text(
                        issue.field ?? '',
                        style: ForgeType.code(size: 12.8, color: muted),
                      ),
                    ),
                    Text(issue.message, style: context.text.bodyMedium),
                  ]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 0.1.6's `severityIcon`: error in the error tone, warning in the warning
/// tone, anything else a warning glyph in the info tone.
class _SeverityIcon extends StatelessWidget {
  const _SeverityIcon(this.severity);

  final ValidationSeverity severity;

  @override
  Widget build(BuildContext context) => switch (severity) {
    ValidationSeverity.error => Icon(
      Icons.error,
      size: 20,
      color: context.colors.error,
      semanticLabel: 'Error',
    ),
    ValidationSeverity.warning => Icon(
      Icons.warning,
      size: 20,
      color: context.forge.warning,
      semanticLabel: 'Warning',
    ),
    ValidationSeverity.info => Icon(
      Icons.warning,
      size: 20,
      color: context.forge.info,
      semanticLabel: 'Info',
    ),
  };
}
