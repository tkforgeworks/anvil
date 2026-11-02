/// 0.1.6's `StatusTag.tsx` over the 0.2.0 [SaveStatus].
library;

import 'package:flutter/material.dart';
import 'package:forge_ui/forge_ui.dart';

import '../editor/save_status.dart';
import '../theme/anvil_metrics.dart';

/// A small outlined pill: `saved` in the success tone, `saving…` in the info
/// tone with a 12 px progress ring, `unsaved` in the warning tone, `error`
/// in the error tone.
///
/// 0.1.6 drew it with a transparent fill over the hero's primary colour; it
/// sits on the surface colour here so the tones stay readable on any theme.
class StatusTag extends StatelessWidget {
  const StatusTag(this.status, {super.key});

  static const ringSize = 12.0;

  final SaveStatus status;

  /// The 0.1.6 label for [status].
  static String labelOf(SaveStatus status) => switch (status) {
    AllSaved() => 'saved',
    Saving() => 'saving…',
    Unsaved() => 'unsaved',
    SaveError() => 'error',
  };

  @override
  Widget build(BuildContext context) {
    final forge = context.forge;
    final tone = switch (status) {
      AllSaved() => forge.success,
      Saving() => forge.info,
      Unsaved() => forge.warning,
      SaveError() => context.colors.error,
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(
        horizontal: AnvilSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border.all(color: tone),
        borderRadius: BorderRadius.circular(AnvilSpacing.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status is Saving) ...[
            SizedBox.square(
              dimension: ringSize,
              child: CircularProgressIndicator(strokeWidth: 2, color: tone),
            ),
            const SizedBox(width: AnvilSpacing.xs),
          ],
          Text(
            labelOf(status),
            style: context.text.labelSmall?.copyWith(color: tone),
          ),
        ],
      ),
    );
  }
}
