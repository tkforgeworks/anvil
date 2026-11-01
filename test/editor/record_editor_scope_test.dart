import 'dart:async';

import 'package:anvil/app/editor/clock.dart';
import 'package:anvil/app/editor/editor_shortcuts.dart';
import 'package:anvil/app/editor/editor_state.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_recipe_editor.dart';
import 'test_recipe_editor_page.dart';

/// Desktop key maps (DefaultTextEditingShortcuts) and desktop tap-outside
/// behaviour are platform-dependent; run as Linux.
final linux = TargetPlatformVariant.only(TargetPlatform.linux);

void main() {
  late FakeRecipeStore store;
  late ProviderContainer container;
  late DateTime now;
  late List<SaveOutcome> outcomes;

  final editor = testRecipeEditorProvider(swordRecipeId);
  EditorState<RecipeDraft> state() => container.read(editor).requireValue;

  setUp(() {
    store = FakeRecipeStore();
    now = DateTime(2026, 11, 1, 12);
    outcomes = [];
    container = ProviderContainer.test(
      overrides: [
        fakeRecipeStoreProvider.overrideWithValue(store),
        clockProvider.overrideWithValue(() => now),
      ],
      retry: (_, _) => null,
    );
  });

  /// Pumps the editor for the sword recipe, with [beside] (if any) above
  /// it on the same route but outside its [RecordEditorScope].
  Future<void> openEditor(WidgetTester tester, {Widget? beside}) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ?beside,
                Expanded(
                  child: TestRecipeEditorPage(
                    recordId: swordRecipeId,
                    onSaveOutcome: outcomes.add,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> ctrl(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool shift = false,
  }) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  /// Focuses a field, types into it, and lets the field's own undo history
  /// (500 ms trailing throttle) and the draft's coalescing window close.
  ///
  /// The pause after focusing matters: the field's pre-typing value only
  /// becomes recordable when focus gives it a valid selection, and the
  /// throttle keeps just the latest value, so typing within 500 ms of
  /// focusing leaves the original text off the field's undo stack
  /// (ANVL-158 gotcha 1).
  Future<void> type(WidgetTester tester, Finder field, String text) async {
    await tester.showKeyboard(field);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.enterText(field, text);
    await tester.pump(const Duration(milliseconds: 600));
    now = now.add(const Duration(seconds: 1));
  }

  final nameField = find.descendant(
    of: find.byKey(const Key('field-displayName')),
    matching: find.byType(TextField),
  );
  final dirtyMarker = find.byKey(const Key('dirty-marker'));

  String fieldText(WidgetTester tester, Finder field) =>
      tester.widget<TextField>(field).controller!.text;

  String title(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('title'))).data!;

  String ingredientCount(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('ingredient-count'))).data!;

  Future<void> addIngredient(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('add-ingredient')));
    await tester.pumpAndSettle();
    now = now.add(const Duration(seconds: 1));
  }

  /// A click on a non-interactive part of the editor. On desktop the
  /// field's default tap-outside action unfocuses it, and focus falls back
  /// to the editor's FocusScope.
  Future<void> clickOutsideFields(WidgetTester tester) async {
    await tester.tap(find.text('Ingredients'));
    await tester.pumpAndSettle();
  }

  group('Ctrl+Z routing', () {
    testWidgets('the editor scope has focus on open, so shortcuts work at '
        'once', (tester) async {
      await openEditor(tester);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'editor');
      expect(textFieldHasFocus(), isFalse);
    }, variant: linux);

    testWidgets('inside a field Ctrl+Z is the field undo and never the draft', (
      tester,
    ) async {
      await openEditor(tester);
      // A structural draft edit first.
      await addIngredient(tester);
      expect(ingredientCount(tester), '3');

      await type(tester, nameField, 'Forge Iron Sword Mk2');
      expect(textFieldHasFocus(), isTrue);
      expect(title(tester), 'Forge Iron Sword Mk2');

      await ctrl(tester, LogicalKeyboardKey.keyZ);
      expect(fieldText(tester, nameField), 'Forge Iron Sword');
      // The draft followed the field through its onChanged ...
      expect(title(tester), 'Forge Iron Sword');
      // ... and the earlier structural edit was not stepped back.
      expect(ingredientCount(tester), '3');
      expect(state().history.past, hasLength(1));
      expect(dirtyMarker, findsOneWidget);

      // Field history exhausted: Ctrl+Z still does not fall through.
      await ctrl(tester, LogicalKeyboardKey.keyZ);
      expect(ingredientCount(tester), '3');

      // The field's redo is the field's too.
      await ctrl(tester, LogicalKeyboardKey.keyZ, shift: true);
      expect(fieldText(tester, nameField), 'Forge Iron Sword Mk2');
      expect(ingredientCount(tester), '3');
      await ctrl(tester, LogicalKeyboardKey.keyZ);
      expect(fieldText(tester, nameField), 'Forge Iron Sword');

      await clickOutsideFields(tester);
      expect(textFieldHasFocus(), isFalse);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'editor');
      await ctrl(tester, LogicalKeyboardKey.keyZ);
      expect(ingredientCount(tester), '2');
      expect(dirtyMarker, findsNothing);
    }, variant: linux);

    testWidgets('field Ctrl+Z reverts the field even when a later draft step '
        'exists', (tester) async {
      await openEditor(tester);
      await type(tester, nameField, 'Forge Iron Sword Mk2');
      await clickOutsideFields(tester);
      await addIngredient(tester); // the later step

      await tester.showKeyboard(nameField);
      await tester.pump(const Duration(milliseconds: 600));
      await ctrl(tester, LogicalKeyboardKey.keyZ);

      // A draft undo would have removed the ingredient (the latest step).
      expect(fieldText(tester, nameField), 'Forge Iron Sword');
      expect(title(tester), 'Forge Iron Sword');
      expect(ingredientCount(tester), '3');
    }, variant: linux);

    testWidgets('outside a field Ctrl+Z steps the draft: structural, then '
        'header text; Ctrl+Shift+Z and Ctrl+Y redo', (tester) async {
      await openEditor(tester);
      await type(tester, nameField, 'Forge Steel Sword');
      await clickOutsideFields(tester);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'editor');
      await addIngredient(tester);
      expect(ingredientCount(tester), '3');
      expect(textFieldHasFocus(), isFalse);

      await ctrl(tester, LogicalKeyboardKey.keyZ); // add
      expect(ingredientCount(tester), '2');
      expect(fieldText(tester, nameField), 'Forge Steel Sword');
      expect(dirtyMarker, findsOneWidget);
      await ctrl(tester, LogicalKeyboardKey.keyZ); // header text
      expect(fieldText(tester, nameField), 'Forge Iron Sword');
      expect(dirtyMarker, findsNothing);

      await ctrl(tester, LogicalKeyboardKey.keyZ, shift: true);
      expect(fieldText(tester, nameField), 'Forge Steel Sword');
      expect(ingredientCount(tester), '2');
      await ctrl(tester, LogicalKeyboardKey.keyY);
      expect(ingredientCount(tester), '3');
      expect(dirtyMarker, findsOneWidget);
      expect(state().canRedo, isFalse);
    }, variant: linux);

    testWidgets('a text field outside any editor scope keeps its own Ctrl+Z '
        'while an editor is mounted', (tester) async {
      final outside = find.byKey(const Key('outside-field'));
      await openEditor(
        tester,
        beside: TextField(
          key: const Key('outside-field'),
          controller: TextEditingController(text: 'Search'),
        ),
      );

      await type(tester, outside, 'Search fireball');
      expect(fieldText(tester, outside), 'Search fireball');
      await ctrl(tester, LogicalKeyboardKey.keyZ);

      expect(fieldText(tester, outside), 'Search');
      expect(state().isDirty, isFalse);
      expect(state().history.past, isEmpty);
    }, variant: linux);
  });

  group('Ctrl+S', () {
    testWidgets('saves while the cursor is in a text field', (tester) async {
      await openEditor(tester);
      await type(tester, nameField, 'Forge Steel Sword');
      expect(textFieldHasFocus(), isTrue);
      expect(dirtyMarker, findsOneWidget);

      await ctrl(tester, LogicalKeyboardKey.keyS);

      expect(outcomes, [SaveOutcome.saved]);
      expect(store.saves, [swordRecipeId]);
      expect(store.records[swordRecipeId]!.displayName, 'Forge Steel Sword');
      expect(dirtyMarker, findsNothing);
      expect(state().isDirty, isFalse);
      // The field kept focus and its text.
      expect(textFieldHasFocus(), isTrue);
      expect(fieldText(tester, nameField), 'Forge Steel Sword');
    }, variant: linux);

    testWidgets('saves from the editor scope outside a field', (tester) async {
      await openEditor(tester);
      await addIngredient(tester);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'editor');

      await ctrl(tester, LogicalKeyboardKey.keyS);

      expect(outcomes, [SaveOutcome.saved]);
      expect(store.records[swordRecipeId]!.ingredients, hasLength(3));
      expect(dirtyMarker, findsNothing);
    }, variant: linux);

    testWidgets('on a clean draft does nothing visible', (tester) async {
      await openEditor(tester);

      await ctrl(tester, LogicalKeyboardKey.keyS);

      expect(outcomes, [SaveOutcome.nothingToSave]);
      expect(store.saves, isEmpty);
      expect(dirtyMarker, findsNothing);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'editor');
    }, variant: linux);

    testWidgets('on a blocked draft returns blocked and writes nothing', (
      tester,
    ) async {
      await openEditor(tester);
      // The output item among the ingredients blocks the save.
      container.read(editor.notifier).setIngredientItem(0, 'item-sword');
      await tester.pumpAndSettle();
      expect(state().blockers, isNotEmpty);
      expect(dirtyMarker, findsOneWidget);

      await ctrl(tester, LogicalKeyboardKey.keyS); // editor focus
      await type(tester, nameField, 'Never Written');
      await ctrl(tester, LogicalKeyboardKey.keyS); // field focus

      expect(outcomes, [SaveOutcome.blocked, SaveOutcome.blocked]);
      expect(store.saves, isEmpty);
      expect(store.records[swordRecipeId], swordRecipe());
      expect(dirtyMarker, findsOneWidget);
      expect(fieldText(tester, nameField), 'Never Written');
    }, variant: linux);

    testWidgets('reports no outcome once the editor is gone', (tester) async {
      await openEditor(tester);
      // Keep the editor alive past the page so the save can finish.
      final keepAlive = container.listen(editor, (_, _) {});
      addTearDown(keepAlive.close);
      await addIngredient(tester);
      store.gate = Completer<void>();

      await ctrl(tester, LogicalKeyboardKey.keyS);
      await tester.pumpWidget(const SizedBox());
      store.gate!.complete();
      await tester.pumpAndSettle();

      expect(store.saves, [swordRecipeId]);
      expect(outcomes, isEmpty);
    }, variant: linux);
  });
}
