import 'package:anvil/app/editor/clock.dart';
import 'package:anvil/app/editor/dirty_editors.dart';
import 'package:anvil/app/editor/editor_state.dart';
import 'package:anvil/app/editor/exit_prompt.dart';
import 'package:anvil/app/shell/app_router.dart';
import 'package:anvil/app/theme/anvil_theme.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_recipe_editor.dart';

final linux = TargetPlatformVariant.only(TargetPlatform.linux);

void main() {
  late FakeRecipeStore store;
  late ProviderContainer container;
  late BuildContext context;

  final sword = testRecipeEditorProvider(swordRecipeId);
  EditorState<RecipeDraft> swordState() => container.read(sword).requireValue;
  RecipeEditorControllerForTest swordEditor() => container.read(sword.notifier);
  DirtyEditor? swordEntry() => findDirtyEditor(
    container.read(dirtyEditorsProvider),
    SaveDomain.recipes,
    swordRecipeId,
  );

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

  /// Mounts an app on the root navigator key whose page keeps the sword
  /// editor alive and hands out its context.
  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: container.read(rootNavigatorKeyProvider),
          theme: anvilTheme(AnvilThemeSpec.dark),
          home: Scaffold(
            body: Consumer(
              builder: (c, r, _) {
                context = c;
                r.watch(sword);
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> mountDirty(WidgetTester tester) async {
    await mount(tester);
    swordEditor().setDisplayName('Steel Sword');
    await tester.pump();
    expect(swordEntry(), isNotNull);
  }

  /// Opens the single-editor prompt for the sword editor; the caller pumps.
  Future<bool> prompt() => confirmLeaveEditor(context, swordEntry());

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  FilledButton saveButton(WidgetTester tester) => tester.widget<FilledButton>(
    find.byKey(const ValueKey('leave-editor-save')),
  );

  group('confirmLeaveEditor', () {
    testWidgets('a clean editor leaves at once with no prompt', (tester) async {
      await mount(tester);
      expect(swordEntry(), isNull);
      final result = prompt();
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing);
      expect(await result, isTrue);
    }, variant: linux);

    testWidgets('Save saves the draft and leaves', (tester) async {
      await mountDirty(tester);
      final result = prompt();
      await tester.pumpAndSettle();

      expect(find.text('Unsaved changes'), findsOneWidget);
      expect(find.text('This record has unsaved changes:'), findsOneWidget);
      expect(find.text('Steel Sword (recipe)'), findsOneWidget);

      await tap(tester, 'leave-editor-save');
      expect(await result, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
      expect(store.saves, [swordRecipeId]);
      expect(store.records[swordRecipeId]!.displayName, 'Steel Sword');
      expect(swordState().isDirty, isFalse);
      expect(swordEntry(), isNull);
    }, variant: linux);

    testWidgets('a failed save stays open with the error, then Cancel stays', (
      tester,
    ) async {
      await mountDirty(tester);
      store.saveErrors[swordRecipeId] = const SaveFailed('disk full', 'test');
      var settled = false;
      final result = prompt()..then((_) => settled = true);
      await tester.pumpAndSettle();

      await tap(tester, 'leave-editor-save');
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('disk full'), findsOneWidget);
      expect(settled, isFalse);
      expect(store.saves, isEmpty);

      await tap(tester, 'leave-editor-cancel');
      expect(await result, isFalse);
      expect(swordState().draft.displayName, 'Steel Sword');
      expect(swordState().saveError, 'disk full');
    }, variant: linux);

    testWidgets('Save is disabled while the draft is blocked', (tester) async {
      await mountDirty(tester);
      swordEditor().setDisplayName('');
      await tester.pump();
      final result = prompt();
      await tester.pumpAndSettle();

      expect(saveButton(tester).onPressed, isNull);
      expect(find.text('Display name is required.'), findsOneWidget);

      await tap(tester, 'leave-editor-cancel');
      expect(await result, isFalse);
      expect(store.saves, isEmpty);
    }, variant: linux);

    testWidgets('Discard throws the draft away and leaves', (tester) async {
      await mountDirty(tester);
      final result = prompt();
      await tester.pumpAndSettle();

      await tap(tester, 'leave-editor-discard');
      expect(await result, isTrue);
      expect(store.saves, isEmpty);
      expect(swordState().draft, swordRecipe());
      expect(swordState().isDirty, isFalse);
      expect(swordEntry(), isNull);
    }, variant: linux);

    testWidgets('Cancel, Escape and the barrier stay with the draft', (
      tester,
    ) async {
      await mountDirty(tester);

      var result = prompt();
      await tester.pumpAndSettle();
      await tap(tester, 'leave-editor-cancel');
      expect(await result, isFalse);

      result = prompt();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(await result, isFalse);

      result = prompt();
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(await result, isFalse);

      expect(store.saves, isEmpty);
      expect(swordState().draft.displayName, 'Steel Sword');
      expect(swordEntry(), isNotNull);
    }, variant: linux);
  });

  group('leaveGuardProvider', () {
    testWidgets('answers true with no navigator mounted', (tester) async {
      expect(await container.read(leaveGuardProvider)(), isTrue);
    }, variant: linux);

    testWidgets('answers true at once with nothing dirty', (tester) async {
      await mount(tester);
      final result = container.read(leaveGuardProvider)();
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing);
      expect(await result, isTrue);
    }, variant: linux);

    testWidgets('shows the Save all prompt on the root navigator', (
      tester,
    ) async {
      await mountDirty(tester);
      final result = container.read(leaveGuardProvider)();
      await tester.pumpAndSettle();

      expect(find.byType(LeaveAllDialog), findsOneWidget);
      expect(find.text('Steel Sword (recipe)'), findsOneWidget);
      await tap(tester, 'leave-all-cancel');
      expect(await result, isFalse);

      final again = container.read(leaveGuardProvider)();
      await tester.pumpAndSettle();
      await tap(tester, 'leave-all-discard');
      expect(await again, isTrue);
      expect(swordEntry(), isNull);
    }, variant: linux);
  });
}
