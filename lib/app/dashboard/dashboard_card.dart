import 'package:flutter/material.dart';
import 'package:forge_ui/forge_ui.dart';

import '../theme/anvil_metrics.dart';

/// The dashboard's outlined card (0.1.6 `Paper variant="outlined"`), with
/// an optional tap and an optional border colour in place of the outline.
class DashboardCard extends StatelessWidget {
  const DashboardCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final content = Padding(
      padding: const EdgeInsets.all(AnvilSpacing.sm + AnvilSpacing.xs),
      child: child,
    );
    return Material(
      color: c.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor ?? c.outlineVariant),
        borderRadius: BorderRadius.circular(AnvilRadii.panel),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}
