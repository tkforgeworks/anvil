import 'package:flutter/material.dart';
import 'package:forge_ui/forge_ui.dart';

import '../theme/anvil_metrics.dart';

/// A key binding as a small bordered monospace label (0.1.6 `KbdPill`),
/// showing the binding string as written, such as `Ctrl+Shift+Z`.
class KbdPill extends StatelessWidget {
  const KbdPill(this.binding, {super.key});

  final String binding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AnvilSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        border: Border.all(color: context.colors.outlineVariant),
        borderRadius: BorderRadius.circular(AnvilRadii.control),
      ),
      child: Text(
        binding,
        softWrap: false,
        style: ForgeType.code(size: 11, color: context.forge.textTertiary),
      ),
    );
  }
}
