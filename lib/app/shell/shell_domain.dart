import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';

/// The six first-class domains as the shell shows them: the sidebar entry,
/// the list route, the editor route and the editor dialog title, in 0.1.6's
/// sidebar order (`DOMAIN_NAV` in `Sidebar.tsx`).
enum ShellDomain {
  classes('Classes', 'Class', 'classes', SaveDomain.classes, Icons.people),
  abilities(
    'Abilities',
    'Ability',
    'abilities',
    SaveDomain.abilities,
    Icons.auto_awesome,
  ),
  items('Items', 'Item', 'items', SaveDomain.items, Icons.inventory),
  recipes(
    'Recipes',
    'Recipe',
    'recipes',
    SaveDomain.recipes,
    Icons.construction,
  ),
  npcs('NPCs', 'NPC', 'npcs', SaveDomain.npcs, Icons.smart_toy),
  lootTables(
    'Loot Tables',
    'Loot Table',
    'loot-tables',
    SaveDomain.lootTables,
    Icons.casino,
  );

  const ShellDomain(
    this.label,
    this.singular,
    this.path,
    this.saveDomain,
    this.icon,
  );

  /// The sidebar and list page label.
  final String label;

  /// One record, title case (`Edit Loot Table`).
  final String singular;

  /// The 0.1.6 route segment (`loot-tables`).
  final String path;

  /// The save-history vocabulary for this domain.
  final SaveDomain saveDomain;

  /// The 0.1.6 sidebar icon's Material equivalent.
  final IconData icon;

  /// The list route.
  String get location => '/$path';

  /// The full-page editor route for [id].
  String editorLocation(String id) => '/$path/${Uri.encodeComponent(id)}';

  /// The 0.1.6 editor dialog title (`EditorModal` `title` in each list page).
  String get editorTitle => 'Edit $singular';

  /// This domain's entry in [counts].
  int countIn(RecordCounts counts) => switch (this) {
    classes => counts.classes,
    abilities => counts.abilities,
    items => counts.items,
    recipes => counts.recipes,
    npcs => counts.npcs,
    lootTables => counts.lootTables,
  };
}
