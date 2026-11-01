/// The prompt in front of leaving every open editor at once: closing the
/// window, and from ANVL-161 closing or switching the project (design
/// §8.8). 0.1.6 never asked, because auto-save had already written
/// everything.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../theme/anvil_metrics.dart';
import 'dirty_editors.dart';

/// True when nothing unsaved stands in the way of leaving.
///
/// With no dirty editors in [dirtyEditorsProvider] it returns true without
/// showing anything. Otherwise it shows a dialog listing each dirty editor
/// as `<display name> (<domain>)` with three choices:
///
/// - **Save all** saves the editors in order (`saveAll()`) and returns true
///   when every one saved. When one fails or is blocked the dialog stays
///   open with that editor's error or first blocker on its line, the
///   editors saved before it stay saved, and the user can fix it (Cancel)
///   or discard.
/// - **Discard all** throws every draft back to its baseline and returns
///   true.
/// - **Cancel** (also Escape or a click outside) returns false.
///
/// The dialog is a route on [context]'s root navigator, so it sits outside
/// every editor's keyboard layer (design §8.7).
Future<bool> confirmLeaveAll(BuildContext context, WidgetRef ref) async {
  if (ref.read(dirtyEditorsProvider).isEmpty) return true;
  final leave = await showDialog<bool>(
    context: context,
    builder: (_) => const LeaveAllDialog(),
  );
  return leave ?? false;
}

/// The Save all / Discard all / Cancel dialog of [confirmLeaveAll]; pops
/// true to leave and false to stay.
class LeaveAllDialog extends ConsumerStatefulWidget {
  const LeaveAllDialog({super.key});

  @override
  ConsumerState<LeaveAllDialog> createState() => _LeaveAllDialogState();
}

class _LeaveAllDialogState extends ConsumerState<LeaveAllDialog> {
  var _saving = false;

  Future<void> _saveAll() async {
    setState(() => _saving = true);
    final saved = await ref.read(dirtyEditorsProvider.notifier).saveAll();
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _saving = false);
    }
  }

  void _discardAll() {
    for (final entry in ref.read(dirtyEditorsProvider).entries) {
      entry.discard();
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(dirtyEditorsProvider).entries;
    final colors = context.colors;
    final dialog = AlertDialog(
      title: const Text('Unsaved changes'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entries.length == 1
                    ? 'This record has unsaved changes:'
                    : 'These records have unsaved changes:',
              ),
              const SizedBox(height: AnvilSpacing.sm),
              for (final entry in entries)
                Padding(
                  key: ValueKey(
                    'leave-all-${entry.domain.name}-'
                    '${entry.recordId}',
                  ),
                  padding: const EdgeInsets.only(top: AnvilSpacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.displayName} (${entry.domain.singular})',
                        style: context.text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_problem(entry) case final problem?)
                        Text(
                          problem,
                          style: context.text.bodySmall?.copyWith(
                            color: colors.error,
                          ),
                        ),
                    ],
                  ),
                ),
              if (_saving) ...[
                const SizedBox(height: AnvilSpacing.md),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('leave-all-cancel'),
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const ValueKey('leave-all-discard'),
          onPressed: _saving ? null : _discardAll,
          child: const Text('Discard all'),
        ),
        FilledButton(
          key: const ValueKey('leave-all-save'),
          onPressed: _saving ? null : _saveAll,
          child: const Text('Save all'),
        ),
      ],
    );
    // Escape and the barrier are Cancel, except while the saves run.
    return PopScope(canPop: !_saving, child: dialog);
  }

  /// What stops [entry] from saving: its last save's error, else its first
  /// save blocker.
  static String? _problem(DirtyEditor entry) =>
      entry.saveError ??
      (entry.blockers.isEmpty ? null : entry.blockers.first.message);
}
