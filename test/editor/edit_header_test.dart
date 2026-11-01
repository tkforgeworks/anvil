import 'package:anvil/app/editor/clock.dart';
import 'package:anvil/app/editor/editor_state.dart';
import 'package:anvil/app/editor/widgets/dirty_dot.dart';
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
  late List<SaveOutcome> outcomes;
  late int backs;

  final editor = testRecipeEditorProvider(swordRecipeId);
  EditorState<RecipeDraft> state() => container.read(editor).requireValue;

  setUp(() {
    store = FakeRecipeStore();
    now = DateTime(2026, 11, 1, 12);
    outcomes = [];
    backs = 0;
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
        TestRecipeScaffoldPage(
          recordId: swordRecipeId,
          onBack: () => backs++,
          onSaveOutcome: outcomes.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  IconButton iconButton(WidgetTester tester, String key) =>
      tester.widget<IconButton>(find.byKey(ValueKey(key)));
  bool saveEnabled(WidgetTester tester) => tester
      .widget<ButtonStyleButton>(find.byKey(const ValueKey('editor-save')))
      .enabled;
  final nameField = find.descendant(
    of: find.byKey(const ValueKey('editor-display-name')),
    matching: find.byType(EditableText),
  );

  testWidgets('shows the name, the read-only key and a clean state', (
    tester,
  ) async {
    await open(tester);

    expect(
      tester.widget<EditableText>(nameField).controller.text,
      'Forge Iron Sword',
    );
    expect(find.text('forge_iron_sword'), findsOneWidget);
    expect(find.text('KEY'), findsOneWidget);
    expect(find.text('· used in exported files'), findsOneWidget);
    expect(find.byTooltip('Back to Recipes'), findsOneWidget);
    expect(iconButton(tester, 'editor-undo').onPressed, isNull);
    expect(iconButton(tester, 'editor-redo').onPressed, isNull);
    expect(saveEnabled(tester), isFalse);
    expect(find.byKey(const ValueKey('editor-save-error')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('editor-back')));
    expect(backs, 1);
  }, variant: linux);

  testWidgets('undo, redo and Save follow the editor state', (tester) async {
    await open(tester);

    await tester.enterText(nameField, 'Forge Steel Sword');
    await tester.pump();
    expect(state().draft.displayName, 'Forge Steel Sword');
    expect(iconButton(tester, 'editor-undo').onPressed, isNotNull);
    expect(iconButton(tester, 'editor-redo').onPressed, isNull);
    expect(saveEnabled(tester), isTrue);

    await tester.tap(find.byKey(const ValueKey('editor-undo')));
    await tester.pump();
    expect(state().draft.displayName, 'Forge Iron Sword');
    expect(
      tester.widget<EditableText>(nameField).controller.text,
      'Forge Iron Sword',
    );
    expect(iconButton(tester, 'editor-redo').onPressed, isNotNull);
    expect(saveEnabled(tester), isFalse);

    await tester.tap(find.byKey(const ValueKey('editor-redo')));
    await tester.pump();
    expect(state().draft.displayName, 'Forge Steel Sword');

    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();
    expect(outcomes, [SaveOutcome.saved]);
    expect(store.saves, [swordRecipeId]);
    expect(state().isDirty, isFalse);
    expect(saveEnabled(tester), isFalse);
    // The history survives the save, so undo stays available.
    expect(iconButton(tester, 'editor-undo').onPressed, isNotNull);
  }, variant: linux);

  testWidgets('a blocked name disables Save and shows the blocker', (
    tester,
  ) async {
    await open(tester);

    await tester.enterText(nameField, '');
    await tester.pump();
    expect(state().isDirty, isTrue);
    expect(saveEnabled(tester), isFalse);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('editor-display-name')),
        matching: find.text('Display name is required.'),
      ),
      findsOneWidget,
    );
  }, variant: linux);

  testWidgets('a failed save shows its error until the next edit', (
    tester,
  ) async {
    store.saveErrors[swordRecipeId] = const SaveFailed('disk full', 'test');
    await open(tester);

    await tester.enterText(nameField, 'Forge Steel Sword');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();
    expect(outcomes, [SaveOutcome.failed]);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('editor-save-error'))).data,
      'disk full',
    );

    await tester.enterText(nameField, 'Forge Steel Sword II');
    await tester.pump();
    expect(find.byKey(const ValueKey('editor-save-error')), findsNothing);
  }, variant: linux);

  testWidgets('the tab dots follow each tab\'s fields', (tester) async {
    await open(tester);
    bool dot(String tab) =>
        tester.widget<DirtyDot>(find.byKey(Key('dot-$tab'))).visible;

    expect(dot('details'), isFalse);
    expect(dot('ingredients'), isFalse);

    await tester.tap(find.byKey(const Key('add-ingredient')));
    await tester.pump();
    expect(dot('details'), isFalse);
    expect(dot('ingredients'), isTrue);

    await tester.enterText(find.byKey(const Key('field-description')), 'Hot');
    await tester.pump();
    expect(dot('details'), isTrue);

    await tester.tap(find.byKey(const ValueKey('save-bar-discard')));
    await tester.pump();
    expect(dot('details'), isFalse);
    expect(dot('ingredients'), isFalse);
  }, variant: linux);

  test('dirtyTabs lists the tabs whose fields differ', () {
    final base = swordRecipe();
    final draft = base.copyWith(description: 'Hot');
    final tabs = <String, bool Function(RecipeDraft, RecipeDraft)>{
      'details': (a, b) => a.description == b.description,
      'output': (a, b) => a.outputItemId == b.outputItemId,
    };
    expect(dirtyTabs(base, base, tabs), isEmpty);
    expect(dirtyTabs(base, draft, tabs), {'details'});
  });
}
