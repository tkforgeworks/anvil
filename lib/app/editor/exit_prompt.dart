/// The prompts in front of leaving unsaved drafts (design §8.8): one for
/// leaving every open editor at once (closing the window, closing or
/// switching the project) and one for leaving a single editor (Back, a
/// route change, closing the editor dialog). 0.1.6 never asked, because
/// auto-save had already written everything.
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../shell/app_router.dart' show rootNavigatorKeyProvider;
import '../theme/anvil_metrics.dart';
import 'dirty_editors.dart';
import 'editor_state.dart';

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
Future<bool> confirmLeaveAll(BuildContext context, WidgetRef ref) =>
    _confirmLeaveAll(context, ref.read(dirtyEditorsProvider));

Future<bool> _confirmLeaveAll(BuildContext context, DirtyEditors dirty) async {
  if (dirty.isEmpty) return true;
  final leave = await showDialog<bool>(
    context: context,
    builder: (_) => const LeaveAllDialog(),
  );
  return leave ?? false;
}

/// The project-level leave guard: what `ProjectLifecycleNotifier` asks
/// before it closes the open project (Close Project, Open, New, Save As).
/// True to go ahead, false to stay with nothing changed.
///
/// The default shows [confirmLeaveAll]'s prompt on the router's root
/// navigator ([rootNavigatorKeyProvider]), and answers true at once when
/// nothing is dirty or no navigator is mounted. Tests override it.
final leaveGuardProvider = Provider<Future<bool> Function()>(
  (ref) => () async {
    final context = ref.read(rootNavigatorKeyProvider).currentContext;
    if (context == null) return true;
    return _confirmLeaveAll(context, ref.read(dirtyEditorsProvider));
  },
);

/// The registry entry of the editor for [domain] and [recordId], or null
/// when that editor is clean (or not open).
DirtyEditor? findDirtyEditor(
  DirtyEditors editors,
  SaveDomain domain,
  String recordId,
) {
  for (final entry in editors.entries) {
    if (entry.domain == domain && entry.recordId == recordId) return entry;
  }
  return null;
}

/// True when leaving one editor loses nothing: at once when [entry] is null
/// (the editor is clean, so it has no registry entry), else after the
/// [LeaveEditorDialog] for it answers:
///
/// - **Save** (disabled while the draft has save blockers) saves and
///   returns true. A failed save keeps the dialog open with the error and
///   returns nothing yet.
/// - **Discard** throws the draft back to its baseline and returns true.
/// - **Cancel** (also Escape or a click outside) returns false.
///
/// The full-page editor routes' `onExit` and the editor dialog's
/// `PopScope` call it. The dialog follows the live entry in
/// [dirtyEditorsProvider], so [entry] only names the editor.
Future<bool> confirmLeaveEditor(
  BuildContext context,
  DirtyEditor? entry,
) async {
  if (entry == null) return true;
  final leave = await showDialog<bool>(
    context: context,
    builder: (_) =>
        LeaveEditorDialog(domain: entry.domain, recordId: entry.recordId),
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
                      if (_problemOf(entry) case final problem?)
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
}

/// What stops [entry] from saving: its last save's error, else its first
/// save blocker.
String? _problemOf(DirtyEditor entry) =>
    entry.saveError ??
    (entry.blockers.isEmpty ? null : entry.blockers.first.message);

/// The Save / Discard / Cancel dialog of [confirmLeaveEditor] for the
/// editor of [domain] and [recordId]; pops true to leave and false to
/// stay. It pops true by itself if the editor turns clean while it is
/// open.
class LeaveEditorDialog extends ConsumerStatefulWidget {
  const LeaveEditorDialog({
    super.key,
    required this.domain,
    required this.recordId,
  });

  final SaveDomain domain;
  final String recordId;

  @override
  ConsumerState<LeaveEditorDialog> createState() => _LeaveEditorDialogState();
}

class _LeaveEditorDialogState extends ConsumerState<LeaveEditorDialog> {
  var _saving = false;
  var _popped = false;

  DirtyEditor? _entry() => findDirtyEditor(
    ref.read(dirtyEditorsProvider),
    widget.domain,
    widget.recordId,
  );

  void _pop(bool leave) {
    if (_popped) return;
    _popped = true;
    Navigator.of(context).pop(leave);
  }

  Future<void> _save() async {
    final entry = _entry();
    if (entry == null) return _pop(true);
    setState(() => _saving = true);
    final outcome = await entry.save();
    if (!mounted) return;
    if (outcome == SaveOutcome.saved) {
      _pop(true);
    } else {
      setState(() => _saving = false);
    }
  }

  void _discard() {
    _entry()?.discard();
    _pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final entry = findDirtyEditor(
      ref.watch(dirtyEditorsProvider),
      widget.domain,
      widget.recordId,
    );
    if (entry == null && !_saving) {
      // Clean now (saved or discarded elsewhere): nothing left to ask.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pop(true);
      });
    }
    final colors = context.colors;
    final busy = _saving || (entry?.saving ?? false);
    final problem = entry == null ? null : _problemOf(entry);
    final dialog = AlertDialog(
      title: const Text('Unsaved changes'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This record has unsaved changes:'),
            const SizedBox(height: AnvilSpacing.sm),
            if (entry != null)
              Text(
                '${entry.displayName} (${entry.domain.singular})',
                style: context.text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (problem != null)
              Text(
                problem,
                key: const ValueKey('leave-editor-problem'),
                style: context.text.bodySmall?.copyWith(color: colors.error),
              ),
            if (busy) ...[
              const SizedBox(height: AnvilSpacing.md),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('leave-editor-cancel'),
          onPressed: busy ? null : () => _pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const ValueKey('leave-editor-discard'),
          onPressed: busy ? null : _discard,
          child: const Text('Discard'),
        ),
        FilledButton(
          key: const ValueKey('leave-editor-save'),
          onPressed: busy || entry == null || entry.blockers.isNotEmpty
              ? null
              : _save,
          child: const Text('Save'),
        ),
      ],
    );
    // Escape and the barrier are Cancel, except while the save runs.
    return PopScope(canPop: !busy, child: dialog);
  }
}
