/// The dashboard's Quick add: the hero's menu and the card of chips, both
/// over the domains' create dialogs (0.1.6 `QUICK_ADD_DOMAINS`).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../domains/abilities/create_ability_dialog.dart';
import '../domains/classes/classes_create_dialog.dart';
import '../domains/items/item_create_dialog.dart';
import '../domains/loot_tables/loot_tables_create_dialog.dart';
import '../domains/npcs/npcs_create_dialog.dart';
import '../domains/recipes/recipes_create_dialog.dart';
import '../shell/open_editor.dart';
import '../shell/shell_domain.dart';
import '../theme/anvil_metrics.dart';
import 'dashboard_card.dart';

/// Shows a domain's create dialog and returns the new record's id, or null
/// when the user cancels.
typedef QuickAddCreate = Future<String?> Function(BuildContext context);

/// The create dialog of each domain. Each dialog creates the record at
/// once and bumps the write epoch. A domain missing here (none in 0.2.0)
/// gets a disabled row and chip.
final Map<ShellDomain, QuickAddCreate> quickAddCreators = {
  ShellDomain.classes: (c) async => (await showCreateClassDialog(c))?.id,
  ShellDomain.abilities: (c) async => (await showCreateAbilityDialog(c))?.id,
  ShellDomain.items: (c) async => (await showCreateItemDialog(c))?.id,
  ShellDomain.recipes: (c) async => (await showCreateRecipeDialog(c))?.id,
  ShellDomain.npcs: (c) async => (await showCreateNpcDialog(c))?.id,
  ShellDomain.lootTables: (c) async => (await showCreateLootTableDialog(c))?.id,
};

/// The tooltip of a domain with no create dialog yet.
const quickAddUnavailable = 'Coming soon';

/// Shows [domain]'s create dialog and opens the created record the way the
/// editing mode says. 0.1.6 only refreshed the dashboard after a create;
/// 0.2.0 opens the record, as the list pages do after `New`.
Future<void> quickAdd(
  BuildContext context,
  WidgetRef ref,
  ShellDomain domain,
) async {
  final create = quickAddCreators[domain];
  if (create == null) return;
  final id = await create(context);
  if (id != null && context.mounted) openEditor(context, ref, domain, id);
}

/// The hero's `Quick add` button and its menu of the six domains.
class QuickAddButton extends ConsumerWidget {
  const QuickAddButton({super.key});

  static const buttonKey = ValueKey('dash-quick-add');

  /// The menu row of [domain].
  static ValueKey<String> itemKey(ShellDomain domain) =>
      ValueKey('dash-quick-add-${domain.path}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return MenuAnchor(
      menuChildren: [
        for (final domain in ShellDomain.values)
          MenuItemButton(
            key: itemKey(domain),
            onPressed: quickAddCreators.containsKey(domain)
                ? () => unawaited(quickAdd(context, ref, domain))
                : null,
            child: Text(domain.singular),
          ),
      ],
      builder: (context, controller, _) => FilledButton.icon(
        key: buttonKey,
        style: FilledButton.styleFrom(
          backgroundColor: c.onPrimary.withValues(alpha: 0.2),
          foregroundColor: c.onPrimary,
        ),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.add),
        label: const Text('Quick add'),
      ),
    );
  }
}

/// The `Quick add` card: one chip per domain.
class QuickAddCard extends ConsumerWidget {
  const QuickAddCard({super.key});

  /// The chip of [domain].
  static ValueKey<String> chipKey(ShellDomain domain) =>
      ValueKey('dash-quick-add-chip-${domain.path}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = context.colors.onSurfaceVariant;
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.add, size: 16, color: muted),
              const SizedBox(width: AnvilSpacing.sm - 2),
              Text(
                'Quick add',
                style: context.text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AnvilSpacing.sm),
          Wrap(
            spacing: AnvilSpacing.sm - 2,
            runSpacing: AnvilSpacing.sm - 2,
            children: [
              for (final domain in ShellDomain.values)
                if (quickAddCreators.containsKey(domain))
                  ActionChip(
                    key: chipKey(domain),
                    label: Text(domain.singular),
                    onPressed: () => unawaited(quickAdd(context, ref, domain)),
                  )
                else
                  Tooltip(
                    message: quickAddUnavailable,
                    child: ActionChip(
                      key: chipKey(domain),
                      label: Text(domain.singular),
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}
