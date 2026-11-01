/// The list confirmations, with 0.1.6's titles, texts and buttons
/// (`BulkActions.tsx`, `ArchiveView.tsx`). Each helper resolves to true only
/// when the user confirms; Cancel, Escape and a tap outside resolve false.
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:forge_ui/forge_ui.dart';

import '../theme/anvil_metrics.dart';

/// `1 Record`, `3 Records`; lower case with [lower].
String _records(int n, {bool lower = false}) =>
    '$n ${lower ? 'record' : 'Record'}${n == 1 ? '' : 's'}';

/// 0.1.6 `BulkDeleteDialog`: computes the impact of soft-deleting [count]
/// records through [impact] while showing `Computing impact...`, then lists
/// each affected reference as `<n> <description>`. Delete stays disabled
/// while the impact loads; a failed load shows `Failed to compute impact.`
/// and still allows the delete, as 0.1.6 did.
Future<bool> showBulkDeleteDialog(
  BuildContext context, {
  required int count,
  required Future<DeleteImpact> Function() impact,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => BulkDeleteDialog(count: count, impact: impact),
    ) ??
    false;

class BulkDeleteDialog extends StatefulWidget {
  const BulkDeleteDialog({
    super.key,
    required this.count,
    required this.impact,
  });

  static const confirmKey = ValueKey('bulk-delete-confirm');

  final int count;
  final Future<DeleteImpact> Function() impact;

  @override
  State<BulkDeleteDialog> createState() => _BulkDeleteDialogState();
}

class _BulkDeleteDialogState extends State<BulkDeleteDialog> {
  DeleteImpact? _impact;
  String? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final impact = await widget.impact();
      if (mounted) setState(() => _impact = impact);
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to compute impact.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final forge = context.forge;
    final n = widget.count;
    final references = _impact?.references ?? const [];
    return AlertDialog(
      title: Text('Delete ${_records(n)}?'),
      content: SizedBox(
        width: _dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error case final error?) ...[
              ForgeErrorCard(message: error),
              const SizedBox(height: AnvilSpacing.md),
            ],
            if (_loading)
              Column(
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(height: AnvilSpacing.sm),
                  Text(
                    'Computing impact...',
                    style: context.text.bodyMedium?.copyWith(
                      color: c.onSurfaceVariant,
                    ),
                  ),
                ],
              )
            else ...[
              Text(
                '${_records(n, lower: true)} will be moved to the archive. '
                'You can restore them from the Recycle Bin.',
              ),
              if (references.isNotEmpty) ...[
                const SizedBox(height: AnvilSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AnvilSpacing.md),
                  decoration: BoxDecoration(
                    color: forge.warningContainer,
                    borderRadius: BorderRadius.circular(AnvilRadii.control),
                  ),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: forge.onWarningContainer),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'This will affect references in other domains:',
                          style: context.text.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: forge.onWarningContainer,
                          ),
                        ),
                        const SizedBox(height: AnvilSpacing.xs),
                        for (final ref in references)
                          Text('•  ${ref.recordCount} ${ref.description}'),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        _DestructiveButton(
          key: BulkDeleteDialog.confirmKey,
          label: 'Delete',
          onPressed: _loading ? null : () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

/// 0.1.6 `BulkHardDeleteDialog`.
Future<bool> showBulkHardDeleteDialog(
  BuildContext context, {
  required int count,
}) => _confirmPermanent(
  context,
  title: 'Permanently Delete ${_records(count)}?',
  subject: _records(count, lower: true),
);

/// 0.1.6 `PermanentDeleteDialog` for one record: [domainLabel] is the
/// singular (`Item`), [displayName] the record's name.
Future<bool> showPermanentDeleteDialog(
  BuildContext context, {
  required String domainLabel,
  required String displayName,
}) => _confirmPermanent(
  context,
  title: 'Permanently Delete $domainLabel?',
  subject: displayName,
);

/// The Permanently Delete confirm button of both permanent dialogs.
const permanentDeleteConfirmKey = ValueKey('permanent-delete-confirm');

Future<bool> _confirmPermanent(
  BuildContext context, {
  required String title,
  required String subject,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: _dialogWidth,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: subject,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const TextSpan(
                  text:
                      ' will be permanently deleted. '
                      'This action cannot be undone.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          _DestructiveButton(
            key: permanentDeleteConfirmKey,
            label: 'Permanently Delete',
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    ) ??
    false;

/// MUI's `sm` dialog width, which 0.1.6's `BulkDeleteDialog` used
/// (`maxWidth="sm" fullWidth`), less the dialog's own padding.
const _dialogWidth = 552.0;

class _DestructiveButton extends StatelessWidget {
  const _DestructiveButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: c.error,
        foregroundColor: c.onError,
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
