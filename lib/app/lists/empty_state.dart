import 'package:flutter/material.dart';
import 'package:forge_ui/forge_ui.dart';

import '../theme/anvil_colors.dart';
import '../theme/anvil_metrics.dart';

/// The centred empty state of a list (0.1.6 `EmptyState.tsx`): an optional
/// [icon] tile, the [title], an optional [body] and an optional call to
/// action, shown when both [ctaLabel] and [onCta] are set.
///
/// Not `ForgeEmptyState`, which requires an icon and an aside where 0.1.6's
/// "No results match your filters" has neither.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.icon,
    required this.title,
    this.body,
    this.ctaLabel,
    this.onCta,
  });

  /// 0.1.6's 96 px icon tile with a 36 px glyph.
  static const iconTileSize = 96.0;
  static const iconSize = 36.0;

  final IconData? icon;
  final String title;
  final String? body;
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final muted = c.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AnvilSpacing.xl * 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon case final icon?) ...[
            Container(
              width: iconTileSize,
              height: iconTileSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.surfaceContainer,
                border: Border.all(color: c.outlineVariant),
                borderRadius: BorderRadius.circular(AnvilRadii.panel),
              ),
              child: Icon(
                icon,
                size: iconSize,
                color: context.anvil.textDisabled,
              ),
            ),
            const SizedBox(height: AnvilSpacing.sm),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.text.titleLarge?.copyWith(color: muted),
          ),
          if (body case final body?) ...[
            const SizedBox(height: AnvilSpacing.sm),
            Text(
              body,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: muted),
            ),
          ],
          if ((ctaLabel, onCta) case (final label?, final onCta?)) ...[
            const SizedBox(height: AnvilSpacing.lg),
            FilledButton(onPressed: onCta, child: Text(label)),
          ],
        ],
      ),
    );
  }
}
