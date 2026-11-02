import 'package:anvil/app/domains/items/items_editor_page.dart';
import 'package:anvil/app/providers.dart';
import 'package:anvil/app/shell/editor_dialog.dart';
import 'package:anvil/app/shell/open_editor.dart';
import 'package:anvil/app/shell/shell_domain.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil/app/shell/sidebar.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'shell_harness.dart';

void main() {
  /// Opens the fixture, goes to `/items` and returns the first item's id.
  Future<String> atItems(WidgetTester tester, ShellHarness harness) async {
    await harness.openProject(tester);
    tester.element(find.byType(Sidebar)).go('/items');
    await tester.pumpAndSettle();
    final items = harness.container.read(itemRepositoryProvider);
    return (await tester.runAsync(items.list))!.first.id;
  }

  /// A context inside the shell and its widget ref (a consumer's element is
  /// both).
  (BuildContext, WidgetRef) shellContext(WidgetTester tester) {
    final element = tester.element(find.byType(Sidebar));
    return (element, element as WidgetRef);
  }

  testWidgets('full page navigates to the editor route', (tester) async {
    final harness = await ShellHarness.pump(
      tester,
      settingsJson: '{"editingMode":"full-page"}',
    );
    final id = await atItems(tester, harness);

    final (context, ref) = shellContext(tester);
    openEditor(context, ref, ShellDomain.items, id);
    await tester.pumpAndSettle();

    expect(harness.location, '/items/$id');
    expect(find.byType(EditorDialog), findsNothing);
    // The registry builds the real item editor since ANVL-192.
    final editor = tester.widget<ItemEditorPage>(find.byType(ItemEditorPage));
    expect(editor.id, id);
  }, variant: linux);

  testWidgets(
    'modal shows the same editor in the dialog and keeps the location; the '
    'setting is read at call time',
    (tester) async {
      final harness = await ShellHarness.pump(tester);
      expect(
        harness.container.read(appSettingsProvider).editingMode,
        EditingMode.modal,
      );
      final id = await atItems(tester, harness);

      final (context, ref) = shellContext(tester);
      openEditor(context, ref, ShellDomain.items, id);
      await tester.pumpAndSettle();

      expect(harness.location, '/items');
      expect(find.byType(EditorDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(EditorDialog),
          matching: find.text('Edit Item'),
        ),
        findsOneWidget,
      );
      final editor = tester.widget<ItemEditorPage>(
        find.descendant(
          of: find.byType(EditorDialog),
          matching: find.byType(ItemEditorPage),
        ),
      );
      expect(editor.id, id);
      // MUI `lg` (1200) wide and 85 % of the 1000 px window high.
      final paper = find
          .descendant(of: find.byType(Dialog), matching: find.byType(Material))
          .first;
      expect(tester.getSize(paper), const Size(1200, 850));

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(EditorDialog), findsNothing);
      expect(harness.location, '/items');

      // Escape closes it too, as MUI's onClose did.
      openEditor(context, ref, ShellDomain.items, id);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(EditorDialog), findsNothing);

      // The mode changes without rebuilding anything that opens editors.
      harness.container
          .read(appSettingsProvider.notifier)
          .setEditingMode(EditingMode.fullPage);
      openEditor(context, ref, ShellDomain.items, id);
      await tester.pumpAndSettle();
      expect(harness.location, '/items/$id');
      expect(find.byType(EditorDialog), findsNothing);
    },
    variant: linux,
  );
}
