/// The dashboard's `Save history` card (0.1.6 `DashboardPage.tsx`).
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:forge_ui/forge_ui.dart';

import '../lists/list_columns.dart' show formatDeletedAt;
import '../theme/anvil_metrics.dart';
import '../widgets/formatting.dart';
import 'dashboard_card.dart';

/// `Auto-save` for a 0.1.6 auto-save row, `Manual save` otherwise; 0.2.0
/// writes only manual rows.
String saveEntryKind(SaveHistoryEntry entry) =>
    entry.isAutoSave ? 'Auto-save' : 'Manual save';

/// The row's main line: the description, or [saveEntryKind] for a row that
/// has none (0.1.6 rows from before its change tracking).
String saveEntryTitle(SaveHistoryEntry entry) =>
    entry.description.isNotEmpty ? entry.description : saveEntryKind(entry);

/// The card: a header with `last N saves`, then one row per entry with the
/// title, the kind as a second line when the title is a description, and
/// the relative time with the full local time in a tooltip.
class SaveHistoryFeed extends StatelessWidget {
  const SaveHistoryFeed({
    super.key,
    required this.entries,
    required this.now,
    this.error,
  });

  final List<SaveHistoryEntry> entries;

  /// The time the relative timestamps are measured from.
  final DateTime now;

  /// Shown in place of the rows when the history could not be read.
  final String? error;

  static const iconBoxSize = 28.0;

  /// The row of the [index]th entry.
  static ValueKey<String> rowKey(int index) => ValueKey('dash-save-$index');

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final muted = c.onSurfaceVariant;
    final caption = context.text.labelSmall?.copyWith(color: muted);
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.history, size: 16, color: muted),
              const SizedBox(width: AnvilSpacing.sm - 2),
              Text(
                'Save history',
                style: context.text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text('last ${entries.length} saves', style: caption),
            ],
          ),
          const SizedBox(height: AnvilSpacing.sm),
          if (error != null)
            Text(
              error!,
              style: context.text.bodyMedium?.copyWith(color: c.error),
            )
          else if (entries.isEmpty)
            Text(
              'No saves recorded yet.',
              style: context.text.bodyMedium?.copyWith(color: muted),
            )
          else
            for (final (i, entry) in entries.indexed) ...[
              if (i > 0) const SizedBox(height: AnvilSpacing.sm - 2),
              Row(
                key: rowKey(i),
                children: [
                  Container(
                    width: iconBoxSize,
                    height: iconBoxSize,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.surfaceContainerHighest,
                      border: Border.all(color: c.primary),
                      borderRadius: BorderRadius.circular(AnvilRadii.control),
                    ),
                    child: Icon(Icons.history, size: 14, color: c.primary),
                  ),
                  const SizedBox(width: AnvilSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          saveEntryTitle(entry),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodyMedium,
                        ),
                        if (entry.description.isNotEmpty)
                          Text(
                            saveEntryKind(entry),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: caption,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AnvilSpacing.sm),
                  _Timestamp(entry.savedAt, now: now),
                ],
              ),
            ],
        ],
      ),
    );
  }
}

class _Timestamp extends StatelessWidget {
  const _Timestamp(this.savedAt, {required this.now});

  final String savedAt;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final time = DateTime.tryParse(savedAt);
    final style = context.text.labelSmall?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    if (time == null) return Text(savedAt, style: style);
    return Tooltip(
      message: formatDeletedAt(savedAt),
      child: Text(formatRelativeTimestamp(time, now: now), style: style),
    );
  }
}
