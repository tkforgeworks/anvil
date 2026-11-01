import 'package:flutter/material.dart';
import 'package:forge_ui/forge_ui.dart';

import '../theme/anvil_metrics.dart';

/// The modal editing mode's frame around an editor (0.1.6 `EditorModal`):
/// a dialog up to [AnvilLayout.editorDialogMaxWidth] wide (MUI `lg`) and
/// [heightFraction] of the window high, a title row with a close button,
/// and the editor in a scroll view. Escape and a click outside close it,
/// as MUI's `onClose` did.
class EditorDialog extends StatelessWidget {
  const EditorDialog({super.key, required this.title, required this.child});

  /// 0.1.6's `height: '85vh'`.
  static const heightFraction = 0.85;

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * heightFraction;
    return Dialog(
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
                  Expanded(child: Text(title, style: context.text.titleLarge)),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
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
  }
}
