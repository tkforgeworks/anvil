import 'dart:ui' show AppExitResponse;

import 'package:anvil/app/editor/clock.dart';
import 'package:anvil/app/editor/dirty_editors.dart';
import 'package:anvil/app/editor/editor_state.dart';
import 'package:anvil/app/editor/exit_prompt.dart';
import 'package:anvil/app/theme/anvil_theme.dart';
import 'package:anvil/main.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_bootstrap_test.dart' show AppHarness;
import '../dialogs/fakes.dart' show appContainer;
import 'test_recipe_editor.dart';

final linux = TargetPlatformVariant.only(TargetPlatform.linux);

void main() {
  group('confirmLeaveAll', () {
    late FakeRecipeStore store;
    late ProviderContainer container;
    late BuildContext context;
    late WidgetRef ref;

    final sword = testRecipeEditorProvider(swordRecipeId);
    final shield = testRecipeEditorProvider(shieldRecipeId);
    EditorState<RecipeDraft> stateOf(
      AsyncNotifierProvider<
        RecipeEditorControllerForTest,
        EditorState<RecipeDraft>
      >
      p,
    ) => container.read(p).requireValue;

    setUp(() {
      store = FakeRecipeStore();
      container = ProviderContainer.test(
        overrides: [
          fakeRecipeStoreProvider.overrideWithValue(store),
          clockProvider.overrideWithValue(() => DateTime(2026, 11, 1, 12)),
        ],
        retry: (_, _) => null,
      );
    });

    /// Mounts an app whose page keeps both editors alive and hands out its
    /// context and ref, and makes both drafts dirty.
    Future<(RecipeEditorControllerForTest, RecipeEditorControllerForTest)>
    openTwoDirty(WidgetTester tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: anvilTheme(AnvilThemeSpec.dark),
            home: Scaffold(
              body: Consumer(
                builder: (c, r, _) {
                  context = c;
                  ref = r;
                  r.watch(sword);
                  r.watch(shield);
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final a = container.read(sword.notifier)..setDisplayName('Steel Sword');
      final b = container.read(shield.notifier)..addIngredient('item-strap');
      await tester.pump();
      expect(container.read(dirtyEditorsProvider).entries, hasLength(2));
      return (a, b);
    }

    /// Opens the prompt; the caller pumps it in.
    Future<bool> prompt(WidgetTester tester) => confirmLeaveAll(context, ref);

    Future<void> tap(WidgetTester tester, String key) async {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
    }

    testWidgets('returns true at once with nothing dirty', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Consumer(
              builder: (c, r, _) {
                context = c;
                ref = r;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      final result = confirmLeaveAll(context, ref);
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing);
      expect(await result, isTrue);
    }, variant: linux);

    testWidgets('lists the dirty editors; Save all saves both', (tester) async {
      await openTwoDirty(tester);
      final result = prompt(tester);
      await tester.pumpAndSettle();

      expect(find.text('Unsaved changes'), findsOneWidget);
      expect(find.text('These records have unsaved changes:'), findsOneWidget);
      expect(find.text('Steel Sword (recipe)'), findsOneWidget);
      expect(find.text('Forge Iron Shield (recipe)'), findsOneWidget);

      await tap(tester, 'leave-all-save');
      expect(await result, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
      expect(store.saves, [swordRecipeId, shieldRecipeId]);
      expect(container.read(dirtyEditorsProvider).isEmpty, isTrue);
    }, variant: linux);

    testWidgets('a blocked editor keeps the dialog open with its message', (
      tester,
    ) async {
      final (a, _) = await openTwoDirty(tester);
      a.setDisplayName('');
      await tester.pump();
      final result = prompt(tester);
      await tester.pumpAndSettle();

      await tap(tester, 'leave-all-save');
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Display name is required.'), findsOneWidget);
      // Save all stops at the first editor that does not save.
      expect(store.saves, isEmpty);

      await tap(tester, 'leave-all-cancel');
      expect(await result, isFalse);
      expect(container.read(dirtyEditorsProvider).entries, hasLength(2));
    }, variant: linux);

    testWidgets('a failed save keeps the dialog open with its error', (
      tester,
    ) async {
      await openTwoDirty(tester);
      store.saveErrors[shieldRecipeId] = const SaveFailed('disk full', 'test');
      final result = prompt(tester);
      await tester.pumpAndSettle();

      await tap(tester, 'leave-all-save');
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('disk full'), findsOneWidget);
      // The editor before the failing one is saved and leaves the list.
      expect(store.saves, [swordRecipeId]);
      expect(find.text('Steel Sword (recipe)'), findsNothing);
      expect(find.text('This record has unsaved changes:'), findsOneWidget);

      await tap(tester, 'leave-all-cancel');
      expect(await result, isFalse);
    }, variant: linux);

    testWidgets('Discard all discards both drafts', (tester) async {
      await openTwoDirty(tester);
      final result = prompt(tester);
      await tester.pumpAndSettle();

      await tap(tester, 'leave-all-discard');
      expect(await result, isTrue);
      expect(store.saves, isEmpty);
      expect(container.read(dirtyEditorsProvider).isEmpty, isTrue);
      expect(stateOf(sword).draft, swordRecipe());
      expect(stateOf(shield).draft, shieldRecipe());
    }, variant: linux);

    testWidgets('Cancel and Escape return false and keep the drafts', (
      tester,
    ) async {
      await openTwoDirty(tester);
      var result = prompt(tester);
      await tester.pumpAndSettle();
      await tap(tester, 'leave-all-cancel');
      expect(await result, isFalse);

      result = prompt(tester);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(await result, isFalse);

      expect(store.saves, isEmpty);
      expect(stateOf(sword).draft.displayName, 'Steel Sword');
      expect(container.read(dirtyEditorsProvider).entries, hasLength(2));
    }, variant: linux);
  });

  // Driven through the binding's exit request, as the runners' window
  // close is: `handleRequestAppExit` calls every `AppLifecycleListener`'s
  // `onExitRequested`. The real app is mounted; a registry entry with
  // recording callbacks stands in for a dirty editor.
  group('AppExitHandler', () {
    late AppHarness harness;
    late List<String> calls;

    Future<ProviderContainer> pumpApp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      harness = AppHarness.create();
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      return appContainer(tester);
    }

    void putDirty(ProviderContainer container) {
      calls = [];
      container
          .read(dirtyEditorsProvider.notifier)
          .put(
            DirtyEditor(
              domain: SaveDomain.items,
              recordId: 'item-1',
              displayName: 'Iron Sword',
              save: () async {
                calls.add('save');
                return SaveOutcome.saved;
              },
              discard: () => calls.add('discard'),
            ),
          );
    }

    Iterable<String> shutdownLines() =>
        harness.logLines.where((l) => l.endsWith('Anvil shutting down'));

    testWidgets('Cancel in the prompt cancels the exit', (tester) async {
      putDirty(await pumpApp(tester));

      final response = tester.binding.handleRequestAppExit();
      await tester.pumpAndSettle();
      expect(find.text('Iron Sword (item)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('leave-all-cancel')));
      await tester.pumpAndSettle();

      expect(await response, AppExitResponse.cancel);
      expect(calls, isEmpty);
      expect(shutdownLines(), isEmpty);
    }, variant: linux);

    testWidgets('Discard all lets the exit go ahead and logs it once', (
      tester,
    ) async {
      putDirty(await pumpApp(tester));

      final response = tester.binding.handleRequestAppExit();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('leave-all-discard')));
      await tester.pumpAndSettle();

      expect(await response, AppExitResponse.exit);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
      expect(calls, ['discard']);
      expect(shutdownLines(), hasLength(1));
    }, variant: linux);

    testWidgets('Save all saves before the exit', (tester) async {
      putDirty(await pumpApp(tester));

      final response = tester.binding.handleRequestAppExit();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('leave-all-save')));
      await tester.pumpAndSettle();

      expect(await response, AppExitResponse.exit);
      expect(calls, ['save']);
    }, variant: linux);

    testWidgets('no prompt with nothing dirty', (tester) async {
      await pumpApp(tester);
      final response = await tester.binding.handleRequestAppExit();
      expect(response, AppExitResponse.exit);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(AnvilApp), findsOneWidget);
    }, variant: linux);
  });
}
