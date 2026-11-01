import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../shell/open_editor.dart';
import '../shell/shell_domain.dart';
import '../theme/anvil_colors.dart';
import '../theme/anvil_metrics.dart';

/// One titled list in the [InspectorRail]: the records of [domain] that use
/// the edited record (`Classes`, `NPCs`, `Recipes`, `Loot Tables`).
class UsedBySection {
  const UsedBySection({
    required this.title,
    required this.domain,
    required this.refs,
  });

  final String title;
  final ShellDomain domain;
  final List<UsedByRef> refs;
}

/// The Used By panel on the right of the ability, item, loot table and
/// class editors (0.1.6 `InspectorRail.tsx`, design §13.7):
/// [AnvilLayout.inspectorRailWidth] wide, a `USED BY` heading, then each
/// section with its count and its records. A record is a link that opens
/// it through `openEditor`, so the editing mode applies; an empty section
/// shows `Not used`. The editor tickets place the rail and load its refs.
class InspectorRail extends ConsumerWidget {
  const InspectorRail({
    super.key,
    required this.sections,
    this.loading = false,
  });

  /// Shown when there are no sections at all (0.1.6's `emptyMessage`).
  static const noSectionsMessage = 'Not referenced by any records';
  static const emptySectionMessage = 'Not used';

  /// The link to record [id].
  static Key entryKey(String id) => ValueKey('inspector-rail-entry-$id');

  final List<UsedBySection> sections;

  /// Shows a progress indicator in place of the sections.
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final disabled = context.anvil.textDisabled;
    return Padding(
      padding: const EdgeInsets.only(left: AnvilSpacing.md),
      child: SizedBox(
        width: AnvilLayout.inspectorRailWidth - AnvilSpacing.md,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: c.outlineVariant),
            borderRadius: BorderRadius.circular(AnvilRadii.panel),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AnvilSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'USED BY',
                  style: ForgeType.ui(
                    size: 11,
                    weight: FontWeight.w700,
                    color: c.onSurface,
                  ).copyWith(letterSpacing: 0.88),
                ),
                const SizedBox(height: AnvilSpacing.sm + AnvilSpacing.xs),
                if (loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: AnvilSpacing.md),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  )
                else if (sections.isEmpty)
                  Text(
                    noSectionsMessage,
                    style: context.text.bodyMedium?.copyWith(
                      color: c.onSurfaceVariant,
                    ),
                  )
                else
                  for (final (i, section) in sections.indexed) ...[
                    if (i > 0) ...[
                      const SizedBox(height: AnvilSpacing.sm + AnvilSpacing.xs),
                      Divider(height: 1, color: c.outlineVariant),
                      const SizedBox(height: AnvilSpacing.sm + AnvilSpacing.xs),
                    ],
                    _Section(section: section, disabled: disabled),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends ConsumerWidget {
  const _Section({required this.section, required this.disabled});

  final UsedBySection section;
  final Color disabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final small = context.text.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                section.title,
                style: context.text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${section.refs.length}',
              style: ForgeType.code(size: 11, color: disabled),
            ),
          ],
        ),
        const SizedBox(height: AnvilSpacing.sm),
        if (section.refs.isEmpty)
          Text(
            InspectorRail.emptySectionMessage,
            style: small?.copyWith(
              fontStyle: FontStyle.italic,
              color: disabled,
            ),
          )
        else
          for (final usedBy in section.refs)
            InkWell(
              key: InspectorRail.entryKey(usedBy.id),
              borderRadius: BorderRadius.circular(AnvilRadii.control),
              onTap: () => openEditor(context, ref, section.domain, usedBy.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AnvilSpacing.sm,
                  vertical: AnvilSpacing.xs + 2,
                ),
                child: Row(
                  children: [
                    Text('›', style: small?.copyWith(color: disabled)),
                    const SizedBox(width: AnvilSpacing.sm),
                    Expanded(
                      child: Text(
                        usedBy.displayName,
                        style: small,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('→', style: small?.copyWith(color: disabled)),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
