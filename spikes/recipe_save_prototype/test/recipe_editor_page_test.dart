import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_save_prototype/src/app/app.dart';
import 'package:recipe_save_prototype/src/app/editor_shortcuts.dart';
import 'package:recipe_save_prototype/src/app/providers.dart';

import 'support/fixture.dart';

/// Desktop key maps (DefaultTextEditingShortcuts) and desktop tap-outside
/// behaviour are platform-dependent; run as Linux.
final linux = TargetPlatformVariant.only(TargetPlatform.linux);

void main() {
  late FixtureCopy fixture;
  late DateTime now;

  setUp(() {
    fixture = FixtureCopy.open();
    now = DateTime(2026, 10, 31, 12);
  });
  tearDown(() => fixture.close());

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectDatabaseProvider.overrideWithValue(fixture.project),
          clockProvider.overrideWithValue(() => now),
        ],
        retry: (_, _) => null,
        child: PrototypeApp(workingCopyPath: fixture.project.path),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openForgeIronSword(WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('recipe-$forgeIronSwordId')));
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
  /// focusing leaves the original text off the field's undo stack.
  Future<void> type(WidgetTester tester, String fieldKey, String text) async {
    await tester.showKeyboard(find.byKey(Key(fieldKey)));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.enterText(find.byKey(Key(fieldKey)), text);
    await tester.pump(const Duration(milliseconds: 600));
    now = now.add(const Duration(seconds: 1));
  }

  String fieldText(WidgetTester tester, String fieldKey) => tester
      .widget<TextField>(
        find.descendant(
          of: find.byKey(Key(fieldKey)),
          matching: find.byType(TextField),
        ),
      )
      .controller!
      .text;

  String qty(WidgetTester tester, String prefix) =>
      tester.widget<Text>(find.byKey(Key('$prefix-qty'))).data!;

  final dirtyMarker = find.byKey(const Key('dirty-marker'));

  /// A click on a non-interactive part of the editor. On desktop the field's
  /// default tap-outside action unfocuses it, and focus falls back to the
  /// editor's FocusScope.
  Future<void> clickOutsideFields(WidgetTester tester) async {
    await tester.tap(find.text('Ingredients'));
    await tester.pumpAndSettle();
  }

  group('AC1', () {
    testWidgets('lists the copy and opens a recipe with its ingredients', (
      tester,
    ) async {
      await openForgeIronSword(tester);
      expect(fieldText(tester, 'field-displayName'), 'Forge Iron Sword');
      expect(find.byKey(const Key('ingredient-0')), findsOneWidget);
      expect(find.byKey(const Key('ingredient-1')), findsOneWidget);
      expect(find.byKey(const Key('ingredient-2')), findsNothing);
      expect(qty(tester, 'ingredient-0'), 'x2');
      expect(dirtyMarker, findsNothing);
    }, variant: linux);
  });

  group('AC2', () {
    testWidgets('dirty marker appears on edit and clears on undo to baseline', (
      tester,
    ) async {
      await openForgeIronSword(tester);
      await tester.tap(find.byKey(const Key('ingredient-1-inc')));
      await tester.pumpAndSettle();
      expect(dirtyMarker, findsOneWidget);
      await tester.tap(find.byKey(const Key('ingredient-1-dec')));
      await tester.pumpAndSettle();
      expect(dirtyMarker, findsNothing, reason: 'back to baseline by value');

      await type(tester, 'field-description', 'Changed.');
      expect(dirtyMarker, findsOneWidget);
      await tester.tap(find.byKey(const Key('undo-button')));
      await tester.pumpAndSettle();
      expect(dirtyMarker, findsNothing);
      expect(fieldText(tester, 'field-description'), 'Two ingots and a strip.');
    }, variant: linux);
  });

  group('AC3: Ctrl+Z routing', () {
    testWidgets('editor scope has focus on open, so shortcuts work at once', (
      tester,
    ) async {
      await openForgeIronSword(tester);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'editor');
      expect(textFieldHasFocus(), isFalse);
    }, variant: linux);

    testWidgets('inside a field Ctrl+Z is the field undo and never the draft', (
      tester,
    ) async {
      await openForgeIronSword(tester);
      // A non-text draft edit first.
      await tester.tap(find.byKey(const Key('ingredient-0-inc')));
      await tester.pumpAndSettle();
      expect(qty(tester, 'ingredient-0'), 'x3');

      await type(tester, 'field-displayName', 'Forge Iron Sword Mk2');
      expect(textFieldHasFocus(), isTrue);
      expect(find.text('Forge Iron Sword Mk2'), findsWidgets);

      await ctrl(tester, LogicalKeyboardKey.keyZ);
      expect(fieldText(tester, 'field-displayName'), 'Forge Iron Sword');
      // The draft followed the field (title shows the reverted name) ...
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Forge Iron Sword'),
        ),
        findsOneWidget,
      );
      // ... and the earlier ingredient edit was not touched.
      expect(qty(tester, 'ingredient-0'), 'x3');
      expect(dirtyMarker, findsOneWidget);

      // Field history exhausted: Ctrl+Z still does not fall through.
      await ctrl(tester, LogicalKeyboardKey.keyZ);
      expect(qty(tester, 'ingredient-0'), 'x3');

      // Field redo is the field's too.
      await ctrl(tester, LogicalKeyboardKey.keyZ, shift: true);
      expect(fieldText(tester, 'field-displayName'), 'Forge Iron Sword Mk2');
      await ctrl(tester, LogicalKeyboardKey.keyZ);

      await clickOutsideFields(tester);
      expect(textFieldHasFocus(), isFalse);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'editor');
      await ctrl(tester, LogicalKeyboardKey.keyZ);
      expect(qty(tester, 'ingredient-0'), 'x2');
      expect(dirtyMarker, findsNothing);
    }, variant: linux);

    testWidgets('field Ctrl+Z reverts the field even when a later draft step '
        'exists', (tester) async {
      await openForgeIronSword(tester);
      await type(tester, 'field-displayName', 'Forge Iron Sword Mk2');
      await clickOutsideFields(tester);
      await tester.tap(find.byKey(const Key('ingredient-0-inc'))); // later step
      await tester.pumpAndSettle();

      await tester.showKeyboard(find.byKey(const Key('field-displayName')));
      await tester.pump(const Duration(milliseconds: 600));
      await ctrl(tester, LogicalKeyboardKey.keyZ);

      // A draft undo would have reverted the quantity (the latest step).
      expect(fieldText(tester, 'field-displayName'), 'Forge Iron Sword');
      expect(qty(tester, 'ingredient-0'), 'x3');
    }, variant: linux);

    testWidgets(
      'typing within 500 ms of focusing: the field cannot undo to the '
      'original text, the draft can',
      (tester) async {
        await openForgeIronSword(tester);
        // No pause between focus and typing (Flutter UndoHistory throttle).
        await tester.enterText(
          find.byKey(const Key('field-displayName')),
          'Forge Iron Sword Mk2',
        );
        await tester.pump(const Duration(milliseconds: 600));
        await ctrl(tester, LogicalKeyboardKey.keyZ);
        expect(fieldText(tester, 'field-displayName'), 'Forge Iron Sword Mk2');

        await clickOutsideFields(tester);
        await ctrl(tester, LogicalKeyboardKey.keyZ);
        expect(fieldText(tester, 'field-displayName'), 'Forge Iron Sword');
        expect(dirtyMarker, findsNothing);
      },
      variant: linux,
    );

    testWidgets('outside a field Ctrl+Z steps the draft: ingredients, header', (
      tester,
    ) async {
      await openForgeIronSword(tester);
      await type(tester, 'field-displayName', 'Forge Steel Sword');
      await clickOutsideFields(tester);
      await tester.tap(find.byKey(const Key('ingredient-1-inc')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ingredient-down-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-ingredient')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ingredient-2')), findsOneWidget);
      expect(textFieldHasFocus(), isFalse);

      await ctrl(tester, LogicalKeyboardKey.keyZ); // add
      expect(find.byKey(const Key('ingredient-2')), findsNothing);
      await ctrl(tester, LogicalKeyboardKey.keyZ); // reorder
      expect(qty(tester, 'ingredient-1'), 'x2');
      await ctrl(tester, LogicalKeyboardKey.keyZ); // quantity
      expect(qty(tester, 'ingredient-1'), 'x1');
      expect(dirtyMarker, findsOneWidget);
      await ctrl(tester, LogicalKeyboardKey.keyZ); // header text
      expect(fieldText(tester, 'field-displayName'), 'Forge Iron Sword');
      expect(dirtyMarker, findsNothing);

      await ctrl(tester, LogicalKeyboardKey.keyZ, shift: true);
      expect(fieldText(tester, 'field-displayName'), 'Forge Steel Sword');
      await ctrl(tester, LogicalKeyboardKey.keyY);
      expect(qty(tester, 'ingredient-1'), 'x2');
      expect(dirtyMarker, findsOneWidget);
    }, variant: linux);
  });

  group('AC4: leave prompt', () {
    testWidgets('a clean editor leaves without asking', (tester) async {
      await openForgeIronSword(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Recipes'), findsOneWidget);
    }, variant: linux);

    testWidgets('Cancel stays with the draft intact', (tester) async {
      await openForgeIronSword(tester);
      await type(tester, 'field-displayName', 'Forge Steel Sword');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byKey(const Key('leave-save')), findsOneWidget);
      expect(find.byKey(const Key('leave-discard')), findsOneWidget);
      await tester.tap(find.byKey(const Key('leave-cancel')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(fieldText(tester, 'field-displayName'), 'Forge Steel Sword');
      expect(dirtyMarker, findsOneWidget);
    }, variant: linux);

    testWidgets('Discard leaves and writes nothing', (tester) async {
      await openForgeIronSword(tester);
      final before = fixture.snapshot(forgeIronSwordId);
      await type(tester, 'field-displayName', 'Forge Steel Sword');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('leave-discard')));
      await tester.pumpAndSettle();
      expect(find.text('Recipes'), findsOneWidget);
      expect(fixture.snapshot(forgeIronSwordId), before);
      // Reopening starts from the stored record, not the discarded draft.
      await tester.tap(find.byKey(const Key('recipe-$forgeIronSwordId')));
      await tester.pumpAndSettle();
      expect(fieldText(tester, 'field-displayName'), 'Forge Iron Sword');
      expect(dirtyMarker, findsNothing);
    }, variant: linux);

    testWidgets('Save writes, leaves, and the list shows the history row', (
      tester,
    ) async {
      await openForgeIronSword(tester);
      await type(tester, 'field-displayName', 'Forge Steel Sword');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('leave-save')));
      await tester.pumpAndSettle();
      expect(find.text('Recipes'), findsOneWidget);
      expect(find.text('Forge Steel Sword'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('history-0')),
          matching: find.text("Recipe 'Forge Steel Sword' changed"),
        ),
        findsOneWidget,
      );
    }, variant: linux);

    testWidgets('Save that fails keeps the user in the editor', (tester) async {
      await openForgeIronSword(tester);
      await tester.tap(find.byKey(const Key('force-failure-toggle')));
      await type(tester, 'field-displayName', 'Forge Steel Sword');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('leave-save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('save-error')), findsOneWidget);
      expect(dirtyMarker, findsOneWidget);
      expect(find.text('Recipes'), findsNothing);
    }, variant: linux);
  });

  group('AC5: Ctrl+S', () {
    testWidgets('saves while the cursor is in a text field', (tester) async {
      await openForgeIronSword(tester);
      final historyBefore = fixture.historyCount();
      await type(tester, 'field-displayName', 'Forge Steel Sword');
      expect(textFieldHasFocus(), isTrue);

      await ctrl(tester, LogicalKeyboardKey.keyS);

      expect(dirtyMarker, findsNothing);
      expect(find.byKey(const Key('save-status')), findsOneWidget);
      expect(
        (fixture.snapshot(forgeIronSwordId)['recipe'] as List).single,
        containsPair('display_name', 'Forge Steel Sword'),
      );
      expect(fixture.historyCount(), historyBefore + 1);
      // The field kept focus and its text.
      expect(textFieldHasFocus(), isTrue);
      expect(fieldText(tester, 'field-displayName'), 'Forge Steel Sword');
    }, variant: linux);
  });

  group('AC6: forced failure through the UI', () {
    testWidgets('Ctrl+S with the toggle on writes nothing and stays dirty', (
      tester,
    ) async {
      await openForgeIronSword(tester);
      final before = fixture.snapshot(forgeIronSwordId);
      await tester.tap(find.byKey(const Key('force-failure-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ingredient-0-inc')));
      await type(tester, 'field-displayName', 'Never Written');

      await ctrl(tester, LogicalKeyboardKey.keyS);

      expect(find.byKey(const Key('save-error')), findsOneWidget);
      expect(dirtyMarker, findsOneWidget);
      expect(fieldText(tester, 'field-displayName'), 'Never Written');
      expect(qty(tester, 'ingredient-0'), 'x3');
      expect(fixture.snapshot(forgeIronSwordId), before);

      // Toggle off and save again: the same draft now commits.
      await tester.tap(find.byKey(const Key('force-failure-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-button')));
      await tester.pumpAndSettle();
      expect(dirtyMarker, findsNothing);
      expect(fixture.historyCount(), (before['historyCount'] as int) + 1);
    }, variant: linux);
  });

  group('AC7: output used as ingredient', () {
    testWidgets('blocks Save with a visible message, Ctrl+S included', (
      tester,
    ) async {
      await openForgeIronSword(tester);
      final before = fixture.snapshot(forgeIronSwordId);
      await tester.tap(find.byKey(const Key('ingredient-item-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Iron Sword').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('blocker-message')), findsOneWidget);
      expect(
        find.textContaining("'Iron Sword' is also an ingredient"),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('save-button')))
            .onPressed,
        isNull,
      );

      await ctrl(tester, LogicalKeyboardKey.keyS); // editor focus
      await type(tester, 'field-description', 'Typed, then Ctrl+S.');
      await ctrl(tester, LogicalKeyboardKey.keyS); // field focus
      expect(fixture.snapshot(forgeIronSwordId), before);
      expect(find.text('Save is blocked (see above).'), findsOneWidget);

      // The leave dialog cannot save it either.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('leave-save')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('leave-cancel')));
      await tester.pumpAndSettle();

      // Fixing it clears the message and re-enables Save.
      await clickOutsideFields(tester);
      await ctrl(tester, LogicalKeyboardKey.keyZ); // description edit
      await ctrl(tester, LogicalKeyboardKey.keyZ); // ingredient item change
      expect(find.byKey(const Key('blocker-message')), findsNothing);
      expect(dirtyMarker, findsNothing);
    }, variant: linux);
  });
}
