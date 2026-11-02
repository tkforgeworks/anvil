import 'package:flutter/material.dart';
import 'package:forge_ui/forge_ui.dart';

import '../theme/anvil_metrics.dart';

/// 0.1.6's two-step `EmptyTrashDialog` (`BulkActions.tsx`) over [count]
/// soft-deleted records: step 1 explains and offers Cancel / Continue,
/// step 2 warns again and offers Cancel / Permanently Delete All. Resolves
/// true only on the second confirmation; Cancel, Escape and a tap outside
/// resolve false at either step.
Future<bool> showEmptyTrashDialog(
  BuildContext context, {
  required int count,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => EmptyTrashDialog(count: count),
    ) ??
    false;

class EmptyTrashDialog extends StatefulWidget {
  const EmptyTrashDialog({super.key, required this.count});

  static const continueKey = ValueKey('empty-trash-continue');
  static const confirmKey = ValueKey('empty-trash-confirm');
  static const cancelKey = ValueKey('empty-trash-cancel');

  final int count;

  @override
  State<EmptyTrashDialog> createState() => _EmptyTrashDialogState();
}

class _EmptyTrashDialogState extends State<EmptyTrashDialog> {
  var _confirming = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = widget.count;
    final s = n == 1 ? '' : 's';
    final destructive = FilledButton.styleFrom(
      backgroundColor: c.error,
      foregroundColor: c.onError,
    );
    return AlertDialog(
      title: const Text('Empty Trash?'),
      content: SizedBox(
        width: _dialogWidth,
        child: _confirming
            ? Container(
                padding: const EdgeInsets.all(AnvilSpacing.md),
                decoration: BoxDecoration(
                  color: c.errorContainer,
                  borderRadius: BorderRadius.circular(AnvilRadii.control),
                ),
                child: Text(
                  'Are you absolutely sure? This will permanently remove '
                  '$n record$s. There is no way to recover them.',
                  style: context.text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: c.onErrorContainer,
                  ),
                ),
              )
            : Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'This will permanently delete '),
                    TextSpan(
                      text: 'all $n archived record$s',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const TextSpan(
                      text:
                          ' across all domains. This action cannot be undone.',
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          key: EmptyTrashDialog.cancelKey,
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        if (_confirming)
          FilledButton(
            key: EmptyTrashDialog.confirmKey,
            style: destructive,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Permanently Delete All'),
          )
        else
          FilledButton(
            key: EmptyTrashDialog.continueKey,
            style: destructive,
            onPressed: () => setState(() => _confirming = true),
            child: const Text('Continue'),
          ),
      ],
    );
  }
}

/// The width the list dialogs use (MUI's `sm` less the dialog padding).
const _dialogWidth = 552.0;
