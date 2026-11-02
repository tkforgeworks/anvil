import 'package:anvil/app/lists/record_table.dart';
import 'package:anvil/app/lists/undo_snackbar.dart';
import 'package:anvil/app/recycle_bin/recycle_bin_page.dart';
import 'package:anvil/app/recycle_bin/trash_group_table.dart';
import 'package:anvil/app/shell/shell_domain.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil/app/theme/anvil_metrics.dart';
import 'package:anvil/app/theme/anvil_theme.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../dialogs/fakes.dart' show copyFixture;

final linux = TargetPlatformVariant.only(TargetPlatform.linux);

String? headerText(WidgetTester tester, ShellDomain domain) {
  final finder = find.byKey(RecycleBinPage.groupHeaderKey(domain));
  if (finder.evaluate().isEmpty) return null;
  return tester.widget<Text>(finder).textSpan!.toPlainText();
}

void main() {
  testWidgets('over the real repositories: a recipe soft-deleted through its '
      'repository is restored from the page and its Undo deletes it again, '
      'each with its own history row', (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = ProjectDatabase.open(copyFixture());
    addTearDown(db.close);
    final recipes = SqliteRecipeRepository(db);
    final history = SqliteSaveHistoryRepository(db);
    final container = ProviderContainer(
      overrides: [
        classRepositoryProvider.overrideWithValue(SqliteClassRepository(db)),
        abilityRepositoryProvider.overrideWithValue(
          SqliteAbilityRepository(db),
        ),
        itemRepositoryProvider.overrideWithValue(SqliteItemRepository(db)),
        recipeRepositoryProvider.overrideWithValue(recipes),
        npcRepositoryProvider.overrideWithValue(SqliteNpcRepository(db)),
        lootTableRepositoryProvider.overrideWithValue(
          SqliteLootTableRepository(db),
        ),
        lifecycleRepositoryProvider.overrideWithValue(
          SqliteLifecycleRepository(db),
        ),
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);

    final target = (await recipes.list()).first;
    await recipes.softDelete(target.id);
    final lastId = (await history.recent()).first.id;
    expect(
      (await history.recent()).first.description,
      recordDeleted(SaveDomain.recipes, target.displayName),
    );

    // The app's minimum window, as the layout rule asks: at the test
    // default of 800 px the tables scroll sideways and the row actions sit
    // off screen, so a tap on them would miss.
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: anvilTheme(AnvilThemeSpec.dark),
          home: const Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: AnvilLayout.sidebarWidth),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(AnvilSpacing.lg),
                    child: RecycleBinPage(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The fixture's own trash (one ability, one item) plus the recipe.
    expect(headerText(tester, ShellDomain.abilities), 'Abilities  (1)');
    expect(headerText(tester, ShellDomain.items), 'Items  (1)');
    expect(headerText(tester, ShellDomain.recipes), 'Crafting Recipes  (1)');
    expect(find.text(target.displayName), findsOneWidget);

    final restore = find.descendant(
      of: find.byKey(TrashGroupTable.groupKey(ShellDomain.recipes)),
      matching: find.byKey(RecordTable.actionKey('Restore', target.id)),
    );
    // The fixture's rows are wider than the window, so the table scrolls
    // sideways to its actions, as the user would.
    await tester.ensureVisible(restore);
    await tester.pumpAndSettle();
    await tester.tap(restore);
    await tester.pumpAndSettle();
    expect(container.read(writeEpochProvider), 1);
    expect(headerText(tester, ShellDomain.recipes), isNull);
    expect((await recipes.list()).map((r) => r.id), contains(target.id));
    expect(
      (await container.read(lifecycleRepositoryProvider).countDeleted())
          .recipes,
      0,
    );

    await tester.tap(find.byKey(undoSnackBarActionKey));
    await tester.pumpAndSettle();
    expect(container.read(writeEpochProvider), 2);
    expect(headerText(tester, ShellDomain.recipes), 'Crafting Recipes  (1)');
    expect((await recipes.list()).map((r) => r.id), isNot(contains(target.id)));

    // 0.1.6's recycle bin went through `lifecycle:*`, whose history rows
    // name the domain but not the record.
    final added = [
      for (final e in await history.recent())
        if (e.id > lastId) e.description,
    ];
    expect(added.toSet(), {
      recordRestored(SaveDomain.recipes, ''),
      recordDeleted(SaveDomain.recipes, ''),
    });
    expect(added, hasLength(2));
    expect(recordRestored(SaveDomain.recipes, ''), 'Recipe restored');
  }, variant: linux);
}
