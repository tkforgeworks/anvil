import 'package:anvil/app/domains/recipes/recipes_editor_controller.dart';
import 'package:anvil/app/domains/recipes/recipes_pages.dart';
import 'package:anvil/app/editor/widgets/dirty_dot.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

Finder byKey(String key) => find.byKey(ValueKey(key));

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(byKey('recipe-tab-${label.toLowerCase()}'));
  await tester.pumpAndSettle();
}

Future<void> pick(WidgetTester tester, String picker, String option) async {
  await tester.tap(byKey(picker));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

bool dotVisible(WidgetTester tester, String tab) =>
    tester.widget<DirtyDot>(byKey('recipe-dot-$tab')).visible;

bool saveEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(byKey('editor-save')).onPressed != null;

/// The ingredient item ids in the order the draft holds them.
List<String> ingredientOrder(RecipeTestHarness h, [String id = swordId]) => [
  for (final i
      in h.container
          .read(recipeEditorProvider(id))
          .requireValue
          .draft
          .ingredients)
    i.itemId,
];

void main() {
  testWidgets('shows the header and the 0.1.6 tabs, Overview first', (
    tester,
  ) async {
    final h = RecipeTestHarness();
    await h.pump(tester, recipeEditor(swordId));

    expect(find.text('Crafting Recipes'), findsOneWidget);
    expect(byKey('editor-export-key'), findsOneWidget);
    for (final tab in ['Overview', 'Details', 'Ingredients']) {
      expect(find.text(tab), findsWidgets);
    }
    expect(
      tester.widget<Text>(byKey('recipe-overview-name')).data,
      'Forge Iron Sword',
    );
    expect(find.text('No description provided.'), findsOneWidget);
    expect(byKey('save-bar'), findsNothing);
    expect(saveEnabled(tester), isFalse);
  }, variant: linux);

  testWidgets('Details shows the pickers and marks only its tab dirty', (
    tester,
  ) async {
    final h = RecipeTestHarness();
    await h.pump(tester, recipeEditor(swordId));
    await openTab(tester, 'Details');

    expect(find.text('Iron Sword'), findsOneWidget);
    expect(find.text('Forge'), findsOneWidget);
    expect(find.text('Blacksmithing'), findsOneWidget);

    await tester.enterText(byKey('recipe-description'), 'Hot work.');
    await tester.pump();
    expect(dotVisible(tester, 'Details'), isTrue);
    expect(dotVisible(tester, 'Ingredients'), isFalse);
    expect(byKey('save-bar'), findsOneWidget);
    expect(saveEnabled(tester), isTrue);

    await pick(tester, 'recipe-station', 'None');
    await pick(tester, 'recipe-output-item', 'Healing Potion');
    final draft = h.container
        .read(recipeEditorProvider(swordId))
        .requireValue
        .draft;
    expect(draft.craftingStationId, isNull);
    expect(draft.outputItemId, potionItemId);
    expect(draft.description, 'Hot work.');
  }, variant: linux);

  testWidgets('an output quantity of 0 blocks Save with the core message', (
    tester,
  ) async {
    final h = RecipeTestHarness();
    await h.pump(tester, recipeEditor(swordId));
    await openTab(tester, 'Details');

    await tester.enterText(byKey('recipe-output-quantity'), '');
    await tester.pump();
    expect(find.text('Output quantity must be at least 1.'), findsNWidgets(2));
    expect(saveEnabled(tester), isFalse);
    expect(
      tester.widget<FilledButton>(byKey('save-bar-save')).onPressed,
      isNull,
    );

    await tester.enterText(byKey('recipe-output-quantity'), '4');
    await tester.pump();
    expect(find.text('Output quantity must be at least 1.'), findsNothing);
    expect(saveEnabled(tester), isTrue);
  }, variant: linux);

  testWidgets('the output as an ingredient blocks Save with the core message '
      'on the row and in the save bar', (tester) async {
    final h = RecipeTestHarness();
    await h.pump(tester, recipeEditor(swordId));
    await openTab(tester, 'Ingredients');

    await pick(tester, 'recipe-ingredient-0-item', 'Iron Sword');
    expect(find.text(outputIsIngredientMessage), findsNWidgets(2));
    expect(dotVisible(tester, 'Ingredients'), isTrue);
    expect(dotVisible(tester, 'Details'), isFalse);
    expect(saveEnabled(tester), isFalse);

    // Ctrl+S refuses too.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(h.recipes.calls, isNot(contains('save $swordId')));
  }, variant: linux);

  testWidgets('a reorder is one undo step, from the button and Ctrl+Z', (
    tester,
  ) async {
    final h = RecipeTestHarness();
    await h.pump(tester, recipeEditor(swordId));
    await openTab(tester, 'Ingredients');

    expect(
      tester.widget<IconButton>(byKey('recipe-ingredient-0-up')).onPressed,
      isNull,
    );
    expect(
      tester.widget<IconButton>(byKey('recipe-ingredient-1-down')).onPressed,
      isNull,
    );

    await tester.tap(byKey('recipe-ingredient-0-down'));
    await tester.pumpAndSettle();
    expect(ingredientOrder(h), [stripId, ingotId]);
    await tester.tap(byKey('editor-undo'));
    await tester.pumpAndSettle();
    expect(ingredientOrder(h), [ingotId, stripId]);
    expect(dotVisible(tester, 'Ingredients'), isFalse);

    await tester.tap(byKey('recipe-ingredient-1-up'));
    await tester.pumpAndSettle();
    expect(ingredientOrder(h), [stripId, ingotId]);
    // No field has focus after a button tap, so Ctrl+Z steps the draft.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(ingredientOrder(h), [ingotId, stripId]);
  }, variant: linux);

  testWidgets('adds the first unused active item, edits and removes rows', (
    tester,
  ) async {
    final h = RecipeTestHarness();
    await h.pump(tester, recipeEditor(swordId));
    await openTab(tester, 'Ingredients');

    await tester.tap(byKey('recipe-add-ingredient'));
    await tester.pumpAndSettle();
    expect(ingredientOrder(h), [ingotId, stripId, potionItemId]);

    await tester.enterText(byKey('recipe-ingredient-2-quantity'), '5');
    await tester.pump();
    expect(
      h.container
          .read(recipeEditorProvider(swordId))
          .requireValue
          .draft
          .ingredients
          .last
          .quantity,
      5,
    );

    await tester.tap(byKey('recipe-ingredient-0-remove'));
    await tester.pumpAndSettle();
    expect(ingredientOrder(h), [stripId, potionItemId]);

    await tester.tap(byKey('recipe-ingredient-0-remove'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('recipe-ingredient-0-remove'));
    await tester.pumpAndSettle();
    expect(find.text('No ingredients yet.'), findsOneWidget);
  }, variant: linux);

  testWidgets('without active items, Add Ingredient is disabled with 0.1.6 '
      'notice', (tester) async {
    final h = RecipeTestHarness(items: const []);
    await h.pump(tester, recipeEditor(swordId));
    await openTab(tester, 'Ingredients');

    expect(
      tester.widget<OutlinedButton>(byKey('recipe-add-ingredient')).onPressed,
      isNull,
    );
    expect(
      find.text('Create an active item before adding ingredients.'),
      findsOneWidget,
    );
  }, variant: linux);

  testWidgets('a soft-deleted ingredient shows the warning and its name', (
    tester,
  ) async {
    final h = RecipeTestHarness();
    h.recipes.drafts[swordId] = swordDraft().copyWith(
      ingredients: const [RecipeIngredient(itemId: cursedId, quantity: 1)],
    );
    await h.pump(tester, recipeEditor(swordId));

    expect(byKey('recipe-deleted-reference-warning'), findsOneWidget);
    await openTab(tester, 'Ingredients');
    expect(find.text('Cursed Dagger (deleted)'), findsOneWidget);
    expect(find.text('Soft-deleted item reference'), findsOneWidget);
  }, variant: linux);

  testWidgets('Save writes through the repository, cleans the draft and '
      'shows the record validation', (tester) async {
    final h = RecipeTestHarness();
    h.script.issues = [
      ValidationIssue(
        id: 'v1',
        severity: ValidationSeverity.warning,
        domain: ValidationDomain.recipes,
        recordId: swordId,
        recordDisplayName: 'Forge Iron Sword',
        field: 'craftingStationId',
        message: 'References a deleted crafting station.',
      ),
    ];
    await h.pump(tester, recipeEditor(swordId));
    await openTab(tester, 'Details');

    await tester.enterText(byKey('recipe-description'), '  Hot work. ');
    await tester.pump();
    final before = h.epoch;
    await tester.tap(byKey('save-bar-save'));
    await tester.pumpAndSettle();

    expect(h.recipes.calls.where((c) => c == 'save $swordId'), hasLength(1));
    expect(h.recipes.drafts[swordId]!.description, 'Hot work.');
    expect(h.epoch, before + 1);
    expect(byKey('save-bar'), findsNothing);
    expect(h.script.refreshes, 1);
    expect(byKey('validation-banner'), findsOneWidget);
    expect(find.text('Validation: 1 warning'), findsOneWidget);
    expect(
      find.text('craftingStationId: References a deleted crafting station.'),
      findsOneWidget,
    );
    // The warning also shows under the station picker.
    expect(find.text('References a deleted crafting station.'), findsOneWidget);
  }, variant: linux);

  testWidgets('Ctrl+S saves from inside a field', (tester) async {
    final h = RecipeTestHarness();
    await h.pump(tester, recipeEditor(swordId));
    await openTab(tester, 'Details');

    await tester.enterText(byKey('recipe-export-key'), 'forge-sword');
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(h.recipes.drafts[swordId]!.exportKey, 'forge-sword');
    expect(h.script.refreshes, 1);
  }, variant: linux);

  testWidgets('an unknown id shows Recipe not found', (tester) async {
    final h = RecipeTestHarness();
    await h.pump(tester, recipeEditor('nope'));
    expect(find.text('Recipe not found.'), findsOneWidget);
    expect(find.text('Back to Recipes'), findsOneWidget);
  }, variant: linux);

  testWidgets('lays out with an unbounded height, as in the editor dialog', (
    tester,
  ) async {
    final h = RecipeTestHarness();
    await h.pump(tester, SingleChildScrollView(child: recipeEditor(swordId)));
    await openTab(tester, 'Ingredients');
    await tester.tap(byKey('recipe-ingredient-0-down'));
    await tester.pumpAndSettle();
    expect(byKey('save-bar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: linux);
}
