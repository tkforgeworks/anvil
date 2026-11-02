/// The dashboard's validation tile (0.1.6 `DashboardPage.tsx`).
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:forge_ui/forge_ui.dart';

import '../theme/anvil_metrics.dart';
import '../validation/validation_grouping.dart';
import 'dashboard_card.dart';

/// `No issues`, `1 issue`, `3 issues` over errors plus warnings.
String validationTileTitle(int total) =>
    total == 0 ? 'No issues' : '$total ${total == 1 ? 'issue' : 'issues'}';

/// `2 errors, 1 warning`, leaving out a zero count; empty with no issues.
String validationTileDetail(int errors, int warnings) => [
  if (errors > 0) errorsLabel(errors),
  if (warnings > 0) warningsLabel(warnings),
].join(', ');

/// The issue count with its breakdown; the border is in the error tone when
/// any error is open, the warning tone when only warnings are, and the
/// title and icon in the warning tone whenever there is an issue, as 0.1.6
/// drew them. A tap opens the Validation page.
class ValidationTile extends StatelessWidget {
  const ValidationTile({super.key, required this.issues, required this.onTap});

  static const tileKey = ValueKey('dash-validation');

  /// Null while the first pass runs.
  final List<ValidationIssue>? issues;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final warning = context.forge.warning;
    final (:errors, :warnings) = countIssues(issues ?? const []);
    final total = errors + warnings;
    final detail = validationTileDetail(errors, warnings);
    return DashboardCard(
      key: tileKey,
      onTap: onTap,
      borderColor: total == 0 ? null : (errors > 0 ? c.error : warning),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning,
                size: 16,
                color: total > 0 ? warning : c.onSurfaceVariant,
              ),
              const SizedBox(width: AnvilSpacing.sm - 2),
              Text(
                issues == null ? 'Checking...' : validationTileTitle(total),
                style: context.text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: total > 0 ? warning : c.onSurface,
                ),
              ),
            ],
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              detail,
              style: context.text.labelSmall?.copyWith(
                color: c.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
