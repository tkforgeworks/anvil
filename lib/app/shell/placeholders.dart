/// What every shell route shows until its ticket lands, and the registry
/// of the pages that have landed. Each domain ticket replaces its entries
/// here (a later map entry overrides the placeholder), so the router and
/// `openEditor` never change: the route and the editor dialog both build
/// editors from [editorBuilders].
library;

import 'package:flutter/material.dart';
import 'package:forge_ui/forge_ui.dart';

import '../dashboard/dashboard_page.dart';
import '../domains/abilities/abilities_pages.dart';
import '../domains/classes/classes_pages.dart';
import '../domains/items/items_pages.dart';
import '../domains/loot_tables/loot_tables_pages.dart';
import '../domains/npcs/npcs_pages.dart';
import '../domains/recipes/recipes_pages.dart';
import '../export/export_page.dart';
import '../recycle_bin/recycle_bin_page.dart';
import '../theme/anvil_metrics.dart';
import '../validation/validation_page.dart';
import 'shell_domain.dart';

/// The ticket that builds each domain's list page and editor.
const _domainTickets = {
  ShellDomain.classes: 'ANVL-195',
  ShellDomain.abilities: 'ANVL-191',
  ShellDomain.items: 'ANVL-192',
  ShellDomain.recipes: 'ANVL-193',
  ShellDomain.npcs: 'ANVL-197',
  ShellDomain.lootTables: 'ANVL-194',
};

/// The dashboard at `/`.
Widget dashboardPage() => const DashboardPage();

/// The validation panel at `/validation`.
Widget validationPage() => const ValidationPage();

/// The recycle bin at `/recycle-bin`.
Widget recycleBinPage() => const RecycleBinPage();

/// The export page at `/export`.
Widget exportPage() => const ExportPage();

/// Each domain's list page, at `ShellDomain.location`.
final Map<ShellDomain, Widget Function()> listPageBuilders = {
  for (final domain in ShellDomain.values)
    domain: () =>
        PagePlaceholder(domain.label, ticket: _domainTickets[domain]!),
  ShellDomain.classes: classesListPage,
  ShellDomain.abilities: abilitiesListPage,
  ShellDomain.items: itemsListPage,
  ShellDomain.recipes: recipesListPage,
  ShellDomain.npcs: npcsListPage,
  ShellDomain.lootTables: lootTablesListPage,
};

/// Each domain's editor for one record id: the page at
/// `ShellDomain.editorLocation` and the body of the modal editor dialog.
final Map<ShellDomain, Widget Function(String id)> editorBuilders = {
  for (final domain in ShellDomain.values)
    domain: (id) => EditorPlaceholder(domain, id),
  ShellDomain.classes: classEditor,
  ShellDomain.abilities: abilityEditor,
  ShellDomain.items: itemEditor,
  ShellDomain.recipes: recipeEditor,
  ShellDomain.npcs: npcEditor,
  ShellDomain.lootTables: lootTableEditor,
};

/// A page that is not built yet: its title, centred, and the ticket that
/// builds it.
class PagePlaceholder extends StatelessWidget {
  const PagePlaceholder(this.title, {super.key, required this.ticket});

  final String title;
  final String ticket;

  @override
  Widget build(BuildContext context) =>
      _Placeholder(title: title, caption: 'Coming in $ticket');
}

/// An editor that is not built yet: the domain, the record id and the
/// ticket that builds it.
class EditorPlaceholder extends StatelessWidget {
  const EditorPlaceholder(this.domain, this.id, {super.key});

  final ShellDomain domain;
  final String id;

  @override
  Widget build(BuildContext context) => _Placeholder(
    title: '${domain.singular} editor',
    detail: id,
    caption: 'Coming in ${_domainTickets[domain]}',
  );
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.title, this.detail, required this.caption});

  final String title;
  final String? detail;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final muted = context.colors.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AnvilSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: context.text.headlineSmall),
            if (detail case final detail?) ...[
              const SizedBox(height: AnvilSpacing.xs),
              SelectableText(detail, style: ForgeType.code(color: muted)),
            ],
            const SizedBox(height: AnvilSpacing.sm),
            Text(
              caption,
              style: context.text.bodySmall?.copyWith(color: muted),
            ),
          ],
        ),
      ),
    );
  }
}
