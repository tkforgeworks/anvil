import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../editor/dirty_editors.dart';
import '../editor/exit_prompt.dart';
import '../theme/anvil_metrics.dart';
import 'shell_domain.dart';

/// The modal editing mode's frame around an editor (0.1.6 `EditorModal`):
/// a dialog up to [AnvilLayout.editorDialogMaxWidth] wide (MUI `lg`) and
/// [heightFraction] of the window high, a title row with a close button,
/// and the editor in a scroll view. Escape, a click outside and the close
/// button close it, as MUI's `onClose` did, but through the leave guard
/// (design §8.8): while record [id] of [domain] has unsaved changes they
/// ask Save / Discard / Cancel (`confirmLeaveEditor`) and close only when
/// it answers to leave.
class EditorDialog extends StatelessWidget {
  const EditorDialog({
    super.key,
    required this.domain,
    required this.id,
    required this.child,
  });

  /// 0.1.6's `height: '85vh'`.
  static const heightFraction = 0.85;

  final ShellDomain domain;
  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * heightFraction;
    final dialog = Dialog(
      // MUI's dialog paper margin.
      insetPadding: const EdgeInsets.all(AnvilSpacing.xl),
      constraints: const BoxConstraints(
        maxWidth: AnvilLayout.editorDialogMaxWidth,
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AnvilSpacing.lg,
                AnvilSpacing.sm,
                AnvilSpacing.sm,
                AnvilSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      domain.editorTitle,
                      style: context.text.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AnvilSpacing.lg,
                  0,
                  AnvilSpacing.lg,
                  AnvilSpacing.lg,
                ),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
    return Consumer(
      builder: (context, ref, child) {
        final entry = findDirtyEditor(
          ref.watch(dirtyEditorsProvider),
          domain.saveDomain,
          id,
        );
        return PopScope<Object?>(
          canPop: entry == null,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final navigator = Navigator.of(context);
            if (await confirmLeaveEditor(context, entry)) navigator.pop();
          },
          child: child!,
        );
      },
      child: dialog,
    );
  }
}
