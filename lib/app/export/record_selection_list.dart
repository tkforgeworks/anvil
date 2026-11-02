/// The Record Selection checklist of the export page (0.1.6 `ExportPage.tsx`):
/// a tristate `Select All (n/N)` row over one row per record.
library;

import 'package:flutter/material.dart';
import 'package:forge_ui/forge_ui.dart';

import '../theme/anvil_metrics.dart';
import 'export_controller.dart';

class RecordSelectionList extends StatelessWidget {
  const RecordSelectionList({
    super.key,
    required this.records,
    required this.checked,
    required this.onToggle,
    required this.onToggleAll,
  });

  static const selectAllKey = ValueKey('export-select-all');

  static Key recordKey(String id) => ValueKey('export-record-$id');

  /// 0.1.6's `maxHeight: 300`.
  static const maxHeight = 300.0;

  final List<ExportRecordRef> records;
  final Set<String> checked;
  final ValueChanged<String> onToggle;
  final VoidCallback onToggleAll;

  @override
  Widget build(BuildContext context) {
    final count = checked.length;
    final total = records.length;
    final bool? all = count == 0
        ? false
        : count == total
        ? true
        : null;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: context.colors.outlineVariant),
        borderRadius: BorderRadius.circular(AnvilRadii.control),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: maxHeight),
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          children: [
            _Row(
              key: selectAllKey,
              value: all,
              tristate: true,
              onTap: onToggleAll,
              label: Text(
                'Select All ($count/$total)',
                style: context.text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final record in records)
              _Row(
                key: recordKey(record.id),
                value: checked.contains(record.id),
                onTap: () => onToggle(record.id),
                label: Text(
                  record.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.value,
    required this.onTap,
    required this.label,
    this.tristate = false,
  });

  final bool? value;
  final VoidCallback onTap;
  final Widget label;
  final bool tristate;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: AnvilSpacing.sm),
      child: Row(
        children: [
          Checkbox(value: value, tristate: tristate, onChanged: (_) => onTap()),
          const SizedBox(width: AnvilSpacing.xs),
          Expanded(child: label),
        ],
      ),
    ),
  );
}
