import 'dart:async';

import 'package:anvil/app/editor/clock.dart';
import 'package:anvil/app/editor/dirty_editors.dart';
import 'package:anvil/app/editor/exit_prompt.dart';
import 'package:anvil/app/project/project_lifecycle.dart';
import 'package:anvil/app/providers.dart';
import 'package:anvil/app/shell/app_router.dart';
import 'package:anvil/app/shell/app_shell.dart';
import 'package:anvil/app/shell/editor_dialog.dart';
import 'package:anvil/app/shell/open_editor.dart';
import 'package:anvil/app/shell/placeholders.dart';
import 'package:anvil/app/shell/shell_domain.dart';
import 'package:anvil/app/shell/sidebar.dart';
import 'package:anvil/app/welcome/welcome_page.dart';
import 'package:anvil/main.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../app_bootstrap_test.dart' show AppHarness;
import '../dialogs/fakes.dart';
import '../editor/test_recipe_editor.dart';
import '../editor/test_recipe_editor_page.dart';

final linux = TargetPlatformVariant.only(TargetPlatform.linux);

/// The in-memory recipe editor with a Back button, as the recipes domain's
/// editor for these tests: the full-page route and the dialog body.
class _GuardedRecipePage extends StatelessWidget {
  const _GuardedRecipePage(this.id);

  final String id;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextButton(
        key: const Key('back'),
        onPressed: () => context.go(ShellDomain.recipes.location),
        child: const Text('Back to Recipes'),
      ),
      TestRecipeEditorPage(recordId: id),
    ],
  );
}

void main() {
  late FakeRecipeStore store;
  late ProviderContainer container;
  late Widget Function(String) originalRecipeEditor;

  setUp(() {
    store = FakeRecipeStore();
    originalRecipeEditor = editorBuilders[ShellDomain.recipes]!;
    editorBuilders[ShellDomain.recipes] = _GuardedRecipePage.new;
    addTearDown(
      () => editorBuilders[ShellDomain.recipes] = originalRecipeEditor,
    );
  });

  String location() => container
      .read(routerProvider)
      .routerDelegate
      .currentConfiguration
      .uri
      .toString();

  DirtyEditor? entryFor(String id) => findDirtyEditor(
    container.read(dirtyEditorsProvider),
    SaveDomain.recipes,
    id,
  );

  /// The app as `main()` mounts it, plus the in-memory recipe store, with
  /// the 0.1.6 fixture open through the lifecycle notifier.
  Future<void> pumpShell(WidgetTester tester, {String? settingsJson}) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = AppHarness.create(settingsJson: settingsJson);
    final path = copyFixture();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...app.overrides,
          fakeRecipeStoreProvider.overrideWithValue(store),
          clockProvider.overrideWithValue(() => DateTime(2026, 11, 1, 12)),
        ],
        retry: (_, _) => null,
        child: const AnvilApp(),
      ),
    );
    container = appContainer(tester);
    unawaited(container.read(projectLifecycleProvider.notifier).openPath(path));
    await pumpUntil(tester, () => find.byType(AppShell).evaluate().isNotEmpty);
    final session = container.read(projectSessionProvider)!;
    addTearDown(() async {
      if (session.isOpen) {
        await ProjectService(supportDirectory: app.directory.path)
            .close(session);
      }
    });
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  /// Types into the editor's display-name field, making the draft dirty.
  Future<void> typeName(WidgetTester tester, String name) async {
    await tester.enterText(find.byKey(const Key('field-displayName')), name);
    await tester.pump();
  }

  Finder leavePrompt() => find.byType(LeaveEditorDialog);

  group('full page', () {
    Future<void> openSword(WidgetTester tester) async {
      await pumpShell(tester, settingsJson: '{"editingMode":"full-page"}');
      container
          .read(routerProvider)
          .go(ShellDomain.recipes.editorLocation(swordRecipeId));
      await tester.pumpAndSettle();
      expect(location(), '/recipes/$swordRecipeId');
      expect(find.text('Forge Iron Sword'), findsWidgets);
    }

    testWidgets('a clean editor leaves without a prompt', (tester) async {
      await openSword(tester);
      await tapKey(tester, 'back');
      expect(leavePrompt(), findsNothing);
      expect(location(), '/recipes');
    }, variant: linux);

    testWidgets('Back on a dirty editor asks; Cancel stays, asking again '
        'works, Discard leaves', (tester) async {
      await openSword(tester);
      await typeName(tester, 'Steel Sword');

      await tapKey(tester, 'back');
      expect(leavePrompt(), findsOneWidget);
      expect(find.text('Steel Sword (recipe)'), findsOneWidget);
      await tapKey(tester, 'leave-editor-cancel');
      expect(location(), '/recipes/$swordRecipeId');
      expect(entryFor(swordRecipeId)!.displayName, 'Steel Sword');

      // A vetoed go does not leave go_router stuck on the target.
      await tapKey(tester, 'back');
      expect(leavePrompt(), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(leavePrompt(), findsNothing);
      expect(location(), '/recipes/$swordRecipeId');

      await tapKey(tester, 'back');
      await tapKey(tester, 'leave-editor-discard');
      expect(location(), '/recipes');
      expect(store.saves, isEmpty);
      expect(entryFor(swordRecipeId), isNull);
    }, variant: linux);

    testWidgets('another record of the same domain is a route change and '
        'asks; Save saves and moves on', (tester) async {
      await openSword(tester);
      await typeName(tester, 'Steel Sword');

      container
          .read(routerProvider)
          .go(ShellDomain.recipes.editorLocation(shieldRecipeId));
      await tester.pumpAndSettle();
      expect(leavePrompt(), findsOneWidget);
      expect(location(), '/recipes/$swordRecipeId');

      await tapKey(tester, 'leave-editor-save');
      expect(store.saves, [swordRecipeId]);
      expect(store.records[swordRecipeId]!.displayName, 'Steel Sword');
      expect(location(), '/recipes/$shieldRecipeId');
      expect(find.text('Forge Iron Shield'), findsWidgets);
      expect(container.read(dirtyEditorsProvider).isEmpty, isTrue);
    }, variant: linux);

    testWidgets('a sidebar link asks; a failed save stays with the error', (
      tester,
    ) async {
      await openSword(tester);
      await typeName(tester, 'Steel Sword');
      store.saveErrors[swordRecipeId] = const SaveFailed('disk full', 'test');

      await tester.tap(
        find.descendant(of: find.byType(Sidebar), matching: find.text('Items')),
      );
      await tester.pumpAndSettle();
      expect(leavePrompt(), findsOneWidget);

      await tapKey(tester, 'leave-editor-save');
      expect(leavePrompt(), findsOneWidget);
      expect(find.text('disk full'), findsOneWidget);
      expect(location(), '/recipes/$swordRecipeId');

      await tapKey(tester, 'leave-editor-cancel');
      expect(location(), '/recipes/$swordRecipeId');
      expect(entryFor(swordRecipeId)!.saveError, 'disk full');
    }, variant: linux);

    testWidgets('closing the project asks once through the project guard', (
      tester,
    ) async {
      await openSword(tester);
      await typeName(tester, 'Steel Sword');
      final lifecycle = container.read(projectLifecycleProvider.notifier);

      unawaited(lifecycle.closeProject());
      await tester.pumpAndSettle();
      expect(find.byType(LeaveAllDialog), findsOneWidget);
      await tapKey(tester, 'leave-all-cancel');
      expect(container.read(projectSessionProvider), isNotNull);
      expect(location(), '/recipes/$swordRecipeId');

      unawaited(lifecycle.closeProject());
      await tester.pumpAndSettle();
      await tapKey(tester, 'leave-all-discard');
      await pumpUntil(
        tester,
        () => find.byType(WelcomePage).evaluate().isNotEmpty,
      );
      // The editor route's own guard does not ask again on the redirect.
      expect(leavePrompt(), findsNothing);
      expect(container.read(projectSessionProvider), isNull);
      expect(location(), welcomeLocation);
      expect(store.saves, isEmpty);
    }, variant: linux);
  });

  group('editor dialog', () {
    Future<void> openSwordDialog(WidgetTester tester) async {
      final element = tester.element(find.byType(Sidebar));
      openEditor(
        element,
        element as WidgetRef,
        ShellDomain.recipes,
        swordRecipeId,
      );
      await tester.pumpAndSettle();
      expect(find.byType(EditorDialog), findsOneWidget);
    }

    Future<void> pumpModal(WidgetTester tester) async {
      await pumpShell(tester);
      expect(
        container.read(appSettingsProvider).editingMode,
        EditingMode.modal,
      );
      container.read(routerProvider).go(ShellDomain.recipes.location);
      await tester.pumpAndSettle();
    }

    testWidgets('a clean dialog closes from X with no prompt', (tester) async {
      await pumpModal(tester);
      await openSwordDialog(tester);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(leavePrompt(), findsNothing);
      expect(find.byType(EditorDialog), findsNothing);
    }, variant: linux);

    testWidgets('X, Escape and the barrier ask while dirty; Cancel keeps the '
        'dialog, Discard closes it', (tester) async {
      await pumpModal(tester);
      await openSwordDialog(tester);
      await typeName(tester, 'Steel Sword');

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(leavePrompt(), findsOneWidget);
      await tapKey(tester, 'leave-editor-cancel');
      expect(find.byType(EditorDialog), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(leavePrompt(), findsOneWidget);
      await tapKey(tester, 'leave-editor-cancel');
      expect(find.byType(EditorDialog), findsOneWidget);

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(leavePrompt(), findsOneWidget);
      await tapKey(tester, 'leave-editor-discard');
      expect(find.byType(EditorDialog), findsNothing);
      expect(location(), '/recipes');
      expect(store.saves, isEmpty);
      await tester.pump();
      expect(entryFor(swordRecipeId), isNull);
    }, variant: linux);

    testWidgets('Save in the prompt saves and closes the dialog; a failed '
        'save keeps it', (tester) async {
      await pumpModal(tester);
      await openSwordDialog(tester);
      await typeName(tester, 'Steel Sword');
      store.saveErrors[swordRecipeId] = const SaveFailed('disk full', 'test');

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'leave-editor-save');
      expect(find.text('disk full'), findsOneWidget);
      await tapKey(tester, 'leave-editor-cancel');
      expect(find.byType(EditorDialog), findsOneWidget);

      store.saveErrors.clear();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'leave-editor-save');
      expect(find.byType(EditorDialog), findsNothing);
      expect(store.saves, [swordRecipeId]);
      expect(store.records[swordRecipeId]!.displayName, 'Steel Sword');
    }, variant: linux);
  });
}
