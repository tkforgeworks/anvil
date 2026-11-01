import 'package:flutter/material.dart';
import 'package:forge_ui/forge_ui.dart';

import '../theme/anvil_colors.dart';
import '../theme/anvil_metrics.dart';

/// One quick-action tile on the welcome page (`ActionTile` in 0.1.6's
/// `WelcomePage.tsx`): an icon box, a title and a subtitle. The [brand]
/// tile is filled with the primary colour.
class WelcomeTile extends StatelessWidget {
  const WelcomeTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
    this.brand = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// Null disables the tile.
  final VoidCallback? onPressed;
  final bool brand;

  static const _iconBox = 44.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final foreground = brand ? c.onPrimary : c.onSurface;
    final secondary = brand
        ? c.onPrimary.withValues(alpha: 0.7)
        : c.onSurfaceVariant;
    final radius = BorderRadius.circular(AnvilRadii.panel);
    return Material(
      color: brand ? c.primary : c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: brand ? c.primary : c.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        hoverColor: brand ? context.anvil.primaryEmphasis : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: _iconBox,
                height: _iconBox,
                decoration: BoxDecoration(
                  color: brand
                      ? context.anvil.primaryEmphasis
                      : c.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AnvilRadii.control),
                  border: brand ? null : Border.all(color: c.outlineVariant),
                ),
                child: Icon(icon, size: brand ? 22 : 18, color: foreground),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: foreground,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: context.text.bodySmall?.copyWith(color: secondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
