import 'package:anvil/app/editor/clock.dart';
import 'package:anvil/app/editor/dirty_editors.dart';
import 'package:anvil/app/editor/editor_state.dart';
import 'package:anvil/app/editor/widgets/draft_text_field.dart';
import 'package:anvil/app/theme/anvil_theme.dart';
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
  late DateTime now;

  final editor = testRecipeEditorProvider(swordRecipeId);
  EditorState<RecipeDraft> state() => container.read(editor).requireValue;
  RecipeEditorControllerForTest controller() => container.read(editor.notifier);

  setUp(() {
    store = FakeRecipeStore();
    now = DateTime(2026, 11, 1, 12);
    container = ProviderContainer.test(
      overrides: [
        fakeRecipeStoreProvider.overrideWithValue(store),
        clockProvider.overrideWithValue(() => now),
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
        const TestRecipeScaffoldPage(recordId: swordRecipeId),
      ),
    );
    await tester.pumpAndSettle();
  }

  final field = find.descendant(
    of: find.byKey(const Key('field-description')),
    matching: find.byType(EditableText),
  );
  TextEditingController text(WidgetTester tester) =>
      tester.widget<EditableText>(field).controller;

  testWidgets('a draft undo keeps the caret and selection', (tester) async {
    await open(tester);
    controller().setDescription('Heats iron');
    now = now.add(const Duration(seconds: 1));
    controller().setDescription('Heats iron bars');
    await tester.pump();
    expect(text(tester).text, 'Heats iron bars');

    text(tester).selection = const TextSelection(
      baseOffset: 2,
      extentOffset: 6,
    );
    controller().undo();
    await tester.pump();
    expect(state().draft.description, 'Heats iron');
    expect(text(tester).text, 'Heats iron');
    expect(
      text(tester).selection,
      const TextSelection(baseOffset: 2, extentOffset: 6),
    );

    // A selection past the new end is clamped to it.
    controller().redo();
    await tester.pump();
    text(tester).selection = const TextSelection(
      baseOffset: 4,
      extentOffset: 15,
    );
    controller().undo();
    await tester.pump();
    expect(text(tester).text, 'Heats iron');
    expect(
      text(tester).selection,
      const TextSelection(baseOffset: 4, extentOffset: 10),
    );
  }, variant: linux);

  testWidgets('typing goes into the draft as one coalesced step', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(field, 'H');
    await tester.enterText(field, 'Ho');
    await tester.enterText(field, 'Hot');
    await tester.pump();
    expect(state().draft.description, 'Hot');
    expect(state().isDirty, isTrue);

    controller().undo();
    await tester.pump();
    expect(state().draft.description, '');
    expect(text(tester).text, '');
  }, variant: linux);

  testWidgets('typing the saved value back clears dirty', (tester) async {
    await open(tester);
    await tester.enterText(field, 'Hot');
    await tester.pump();
    expect(state().isDirty, isTrue);
    expect(container.read(dirtyEditorsProvider).entries, hasLength(1));

    now = now.add(const Duration(seconds: 1));
    await tester.enterText(field, '');
    await tester.pump();
    expect(state().isDirty, isFalse);
    expect(container.read(dirtyEditorsProvider).isEmpty, isTrue);
    expect(find.byKey(const ValueKey('save-bar')), findsNothing);
  }, variant: linux);

  group('messages', () {
    Future<InputDecoration> decorationOf(
      WidgetTester tester,
      DraftTextField field,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: anvilTheme(AnvilThemeSpec.dark),
          home: Scaffold(body: field),
        ),
      );
      return tester.widget<TextField>(find.byType(TextField)).decoration!;
    }

    DraftTextField make({
      String? blocker,
      String? issue,
      ValidationSeverity severity = ValidationSeverity.error,
    }) => DraftTextField(
      label: 'Export key',
      value: 'k',
      onChanged: (_) {},
      blockerMessage: blocker,
      issueMessage: issue,
      issueSeverity: severity,
    );

    testWidgets('a blocker wins over an issue as the error text', (
      tester,
    ) async {
      final d = await decorationOf(
        tester,
        make(blocker: 'Export key is required.', issue: 'Broken'),
      );
      expect(d.errorText, 'Export key is required.');
      expect(d.helperText, isNull);
      expect(d.labelText, 'Export key');
    });

    testWidgets('an error issue is error text, a warning helper text', (
      tester,
    ) async {
      var d = await decorationOf(tester, make(issue: 'Broken reference'));
      expect(d.errorText, 'Broken reference');

      d = await decorationOf(
        tester,
        make(issue: 'Archived', severity: ValidationSeverity.warning),
      );
      expect(d.errorText, isNull);
      expect(d.helperText, 'Archived');
    });

    test('blockerText finds the first blocker on a field', () {
      const blockers = [
        SaveBlocker('displayName', 'Display name is required.'),
        SaveBlocker('exportKey', 'Export key is required.'),
        SaveBlocker('exportKey', 'Second'),
      ];
      expect(blockerText(blockers, 'exportKey'), 'Export key is required.');
      expect(blockerText(blockers, 'description'), isNull);
    });
  });
}
