import 'package:anvil/app/dashboard/dashboard_page.dart';
import 'package:anvil/app/domains/abilities/abilities_editor_page.dart';
import 'package:anvil/app/domains/abilities/abilities_list_page.dart';
import 'package:anvil/app/domains/classes/classes_editor_page.dart';
import 'package:anvil/app/domains/classes/classes_list_page.dart';
import 'package:anvil/app/domains/items/items_editor_page.dart';
import 'package:anvil/app/domains/items/items_list_page.dart';
import 'package:anvil/app/domains/loot_tables/loot_tables_editor_page.dart';
import 'package:anvil/app/domains/loot_tables/loot_tables_list_page.dart';
import 'package:anvil/app/domains/npcs/npcs_editor_page.dart';
import 'package:anvil/app/domains/npcs/npcs_list_page.dart';
import 'package:anvil/app/domains/recipes/recipes_editor_page.dart';
import 'package:anvil/app/domains/recipes/recipes_list_page.dart';
import 'package:anvil/app/menu/menu_commands.dart';
import 'package:anvil/app/recycle_bin/recycle_bin_page.dart';
import 'package:anvil/app/shell/app_shell.dart';
import 'package:anvil/app/shell/placeholders.dart';
import 'package:anvil/app/shell/shell_domain.dart';
import 'package:anvil/app/shell/sidebar.dart';
import 'package:anvil/app/validation/validation_page.dart';
import 'package:anvil/app/welcome/welcome_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../menu/menu_harness.dart' show openSection;
import 'shell_harness.dart';

/// The 0.1.6 route table (`App.tsx`) with the page each one shows until its
/// ticket lands.
const pages = {
  '/': ('Dashboard', 'ANVL-198'),
  '/classes': ('Classes', 'ANVL-195'),
  '/abilities': ('Abilities', 'ANVL-191'),
  '/items': ('Items', 'ANVL-192'),
  '/recipes': ('Recipes', 'ANVL-193'),
  '/npcs': ('NPCs', 'ANVL-197'),
  '/loot-tables': ('Loot Tables', 'ANVL-194'),
  '/validation': ('Validation', 'ANVL-198'),
  '/recycle-bin': ('Recycle Bin', 'ANVL-199'),
  '/export': ('Export', 'ANVL-200'),
};

/// The routes whose pages have landed: the widget the shell shows instead
/// of the placeholder. Each domain ticket adds its two entries here.
final landedPages = <String, Type>{
  '/': DashboardPage,
  '/validation': ValidationPage,
  '/abilities': AbilityListPage,
  '/classes': ClassListPage,
  '/items': ItemListPage,
  '/recipes': RecipeListPage,
  '/loot-tables': LootTableListPage,
  '/npcs': NpcListPage,
  '/recycle-bin': RecycleBinPage,
};
final landedEditors = <ShellDomain, Type>{
  ShellDomain.abilities: AbilityEditorPage,
  ShellDomain.classes: ClassEditorPage,
  ShellDomain.items: ItemEditorPage,
  ShellDomain.recipes: RecipeEditorPage,
  ShellDomain.lootTables: LootTableEditorPage,
  ShellDomain.npcs: NpcEditorPage,
};

const editors = {
  '/classes/c-1': (ShellDomain.classes, 'c-1'),
  '/abilities/a-1': (ShellDomain.abilities, 'a-1'),
  '/items/i-1': (ShellDomain.items, 'i-1'),
  '/recipes/r-1': (ShellDomain.recipes, 'r-1'),
  '/npcs/n-1': (ShellDomain.npcs, 'n-1'),
  '/loot-tables/l-1': (ShellDomain.lootTables, 'l-1'),
};

void main() {
  testWidgets(
    'no session shows the welcome page; opening redirects to the dashboard '
    'in the shell; closing returns to welcome',
    (tester) async {
      final harness = await ShellHarness.pump(tester);
      await tester.pumpAndSettle();

      expect(harness.location, '/welcome');
      expect(find.byType(WelcomePage), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);

      await harness.openProject(tester);

      expect(harness.location, '/');
      expect(find.byType(WelcomePage), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Spike Fixture'),
        ),
        findsOneWidget,
      );
      expect(find.byType(Sidebar), findsOneWidget);
      expect(find.byKey(AppShell.menuSlotKey), findsOneWidget);
      expect(find.byKey(AppShell.saveStatusSlotKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppShell),
          matching: find.byType(DashboardPage),
        ),
        findsOneWidget,
      );

      // The welcome location is not reachable while a project is open.
      tester.element(find.byType(Sidebar)).go('/welcome');
      await tester.pumpAndSettle();
      expect(harness.location, '/');

      await openSection(tester, 'File');
      await tester.tap(
        find.byKey(ValueKey('menu-${MenuCommand.closeProject.id}')),
      );
      await tester.pumpAndSettle();

      expect(harness.location, '/welcome');
      expect(find.byType(WelcomePage), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
    },
    variant: linux,
  );

  testWidgets(
    'every route renders its placeholder inside the shell, and the sidebar '
    'reaches every page',
    (tester) async {
      final harness = await ShellHarness.pump(tester);
      await harness.openProject(tester);

      for (final MapEntry(key: path, value: (title, ticket)) in pages.entries) {
        tester.element(find.byType(Sidebar)).go(path);
        await tester.pumpAndSettle();

        expect(harness.location, path);
        expect(find.byType(AppShell), findsOneWidget, reason: path);
        if (landedPages[path] case final type?) {
          expect(
            find.descendant(
              of: find.byType(AppShell),
              matching: find.byType(type),
            ),
            findsOneWidget,
            reason: path,
          );
          expect(find.byType(PagePlaceholder), findsNothing, reason: path);
          continue;
        }
        final page = tester.widget<PagePlaceholder>(
          find.descendant(
            of: find.byType(AppShell),
            matching: find.byType(PagePlaceholder),
          ),
        );
        expect((page.title, page.ticket), (title, ticket), reason: path);
        expect(find.text('Coming in $ticket'), findsOneWidget, reason: path);
      }

      for (final MapEntry(key: path, value: (domain, id)) in editors.entries) {
        tester.element(find.byType(Sidebar)).go(path);
        await tester.pumpAndSettle();

        expect(harness.location, path);
        if (landedEditors[domain] case final type?) {
          final editor = find.descendant(
            of: find.byType(AppShell),
            matching: find.byType(type),
          );
          expect(editor, findsOneWidget, reason: path);
          expect(tester.widget(editor).key, ValueKey(id), reason: path);
        } else {
          final editor = tester.widget<EditorPlaceholder>(
            find.descendant(
              of: find.byType(AppShell),
              matching: find.byType(EditorPlaceholder),
            ),
          );
          expect((editor.domain, editor.id), (domain, id), reason: path);
        }
        // The editor route highlights its list's entry.
        final label = tester.widget<Text>(
          find.descendant(
            of: find.byType(Sidebar),
            matching: find.text(domain.label),
          ),
        );
        expect(label.style?.fontWeight, FontWeight.w600, reason: path);
      }

      // Every sidebar entry navigates to its page.
      for (final MapEntry(key: path, value: (title, _)) in pages.entries) {
        await tester.tap(
          find.descendant(of: find.byType(Sidebar), matching: find.text(title)),
        );
        await tester.pumpAndSettle();
        expect(harness.location, path, reason: title);
      }
    },
    variant: linux,
  );
}
