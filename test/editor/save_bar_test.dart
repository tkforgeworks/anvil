import 'dart:async';

import 'package:anvil/app/editor/clock.dart';
import 'package:anvil/app/editor/dirty_editors.dart';
import 'package:anvil/app/editor/editor_state.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_recipe_editor.dart';
import 'test_recipe_editor_page.dart';

final linux = TargetPlatformVariant.only(TargetPlatform.linux);

void main() {
  late FakeRecipeStore store;
  late ProviderContainer container;
  late List<SaveOutcome> outcomes;

  final editor = testRecipeEditorProvider(swordRecipeId);
  EditorState<RecipeDraft> state() => container.read(editor).requireValue;
  RecipeEditorControllerForTest controller() => container.read(editor.notifier);

  setUp(() {
    store = FakeRecipeStore();
    outcomes = [];
    container = ProviderContainer.test(
      overrides: [
        fakeRecipeStoreProvider.overrideWithValue(store),
        clockProvider.overrideWithValue(() => DateTime(2026, 11, 1, 12)),
      ],
      retry: (_, _) => null,
    );
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      scaffoldTestApp(
        container,
        TestRecipeScaffoldPage(
          recordId: swordRecipeId,
          onSaveOutcome: outcomes.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final bar = find.byKey(const ValueKey('save-bar'));
  bool enabled(WidgetTester tester, String key) =>
      tester.widget<ButtonStyleButton>(find.byKey(ValueKey(key))).enabled;

  testWidgets('appears on a dirty draft and disappears after Save', (
    tester,
  ) async {
    await open(tester);
    expect(bar, findsNothing);

    await tester.tap(find.byKey(const Key('add-ingredient')));
    await tester.pump();
    expect(bar, findsOneWidget);
    expect(find.text('You have unsaved changes'), findsOneWidget);
    expect(enabled(tester, 'save-bar-save'), isTrue);
    expect(enabled(tester, 'save-bar-discard'), isTrue);
    expect(find.byKey(const ValueKey('save-bar-blocker')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('save-bar-save')));
    await tester.pumpAndSettle();
    expect(outcomes, [SaveOutcome.saved]);
    expect(store.saves, [swordRecipeId]);
    expect(store.records[swordRecipeId]!.ingredients, hasLength(3));
    expect(bar, findsNothing);
    expect(container.read(dirtyEditorsProvider).isEmpty, isTrue);
  }, variant: linux);

  testWidgets('Discard puts the draft back and hides the bar', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('add-ingredient')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('save-bar-discard')));
    await tester.pump();
    expect(bar, findsNothing);
    expect(state().draft, swordRecipe());
    expect(state().canUndo, isFalse);
    expect(store.saves, isEmpty);
  }, variant: linux);

  testWidgets('a blocked draft disables Save and shows the first blocker', (
    tester,
  ) async {
    await open(tester);
    // The output item as an ingredient: the recipe consumes what it makes.
    controller().setIngredientItem(0, 'item-sword');
    await tester.pump();

    expect(bar, findsOneWidget);
    expect(enabled(tester, 'save-bar-save'), isFalse);
    expect(enabled(tester, 'save-bar-discard'), isTrue);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('save-bar-blocker'))).data,
      state().blockers.first.message,
    );

    controller().undo();
    await tester.pump();
    expect(bar, findsNothing);
  }, variant: linux);

  testWidgets('both buttons are disabled while the save is in flight', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('add-ingredient')));
    await tester.pump();
    final gate = store.gate = Completer<void>();

    await tester.tap(find.byKey(const ValueKey('save-bar-save')));
    await tester.pump();
    expect(state().saving, isTrue);
    expect(enabled(tester, 'save-bar-save'), isFalse);
    expect(enabled(tester, 'save-bar-discard'), isFalse);

    gate.complete();
    await tester.pumpAndSettle();
    expect(bar, findsNothing);
    expect(outcomes, [SaveOutcome.saved]);
  }, variant: linux);
}
