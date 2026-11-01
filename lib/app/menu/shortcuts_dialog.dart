import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../theme/anvil_metrics.dart';
import 'kbd_pill.dart';
import 'shortcut_registry.dart';

/// Opens the keyboard shortcuts cheatsheet (Ctrl+/, 0.1.6 `ShortcutsModal`).
Future<void> showShortcutsDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const ShortcutsDialog());

/// The registry's groups in two columns, each entry's label beside the
/// binding in effect (the user's override or the default).
class ShortcutsDialog extends ConsumerWidget {
  const ShortcutsDialog({super.key});

  /// MUI `maxWidth="md"`.
  static const maxWidth = 900.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bindings = ref.watch(shortcutBindingsProvider);
    final groups = [
      for (final group in ShortcutGroup.values)
        if (bindings.where((b) => b.entry.group == group).toList()
            case final entries when entries.isNotEmpty)
          _Group(group.label, entries),
    ];
    return Dialog(
      insetPadding: const EdgeInsets.all(AnvilSpacing.xl),
      constraints: const BoxConstraints(maxWidth: maxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                Expanded(
                  child: Text(
                    'Keyboard Shortcuts',
                    style: context.text.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.colors.outlineVariant),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AnvilSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < groups.length; i += 2)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AnvilSpacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: groups[i]),
                          const SizedBox(width: AnvilSpacing.lg),
                          Expanded(
                            child: i + 1 < groups.length
                                ? groups[i + 1]
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  Divider(
                    height: AnvilSpacing.lg,
                    color: context.colors.outlineVariant,
                  ),
                  Text(
                    'Press Esc to close.',
                    style: context.text.bodySmall?.copyWith(
                      color: context.forge.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group(this.label, this.entries);

  final String label;
  final List<ShortcutBinding> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AnvilSpacing.xs),
          child: Text(
            label.toUpperCase(),
            style: context.text.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: context.forge.textTertiary,
            ),
          ),
        ),
        for (final b in entries)
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: context.colors.outlineVariant),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AnvilSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(b.entry.label, style: context.text.bodyMedium),
                  ),
                  KbdPill(b.binding, key: ValueKey('kbd-${b.entry.id}')),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
