import 'package:anvil/app/editor/save_status.dart';
import 'package:anvil/app/shell/app_shell.dart';
import 'package:anvil/app/shell/save_status_indicator.dart';
import 'package:anvil/app/theme/anvil_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge_ui/forge_ui.dart';

import 'shell_harness.dart';

void main() {
  Future<BuildContext> pump(WidgetTester tester, SaveStatus status) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveStatusProvider.overrideWithValue(status)],
        child: MaterialApp(
          theme: anvilTheme(AnvilThemeSpec.dark),
          home: const Scaffold(body: SaveStatusIndicator()),
        ),
      ),
    );
    return tester.element(find.byType(SaveStatusIndicator));
  }

  Color dotColor(WidgetTester tester) {
    final dot = tester.widget<Container>(
      find.descendant(
        of: find.byType(SaveStatusIndicator),
        matching: find.byType(Container),
      ),
    );
    return (dot.decoration! as BoxDecoration).color!;
  }

  testWidgets('all saved shows the saved label in the success tone and no '
      'tooltip', (tester) async {
    final context = await pump(tester, const AllSaved());
    expect(find.text('All changes saved'), findsOneWidget);
    expect(find.byType(Tooltip), findsNothing);
    expect(dotColor(tester), context.forge.success);
  });

  testWidgets('unsaved shows 0.1.6\'s label with the count in a tooltip', (
    tester,
  ) async {
    final context = await pump(tester, const Unsaved(3));
    expect(find.text('Unsaved Changes'), findsOneWidget);
    expect(find.byTooltip('3 records with unsaved changes'), findsOneWidget);
    expect(dotColor(tester), context.forge.warning);
  });

  testWidgets('one unsaved record is singular', (tester) async {
    await pump(tester, const Unsaved(1));
    expect(find.byTooltip('1 record with unsaved changes'), findsOneWidget);
  });

  testWidgets('saving shows Saving... in the info tone', (tester) async {
    final context = await pump(tester, const Saving());
    expect(find.text('Saving...'), findsOneWidget);
    expect(find.byType(Tooltip), findsNothing);
    expect(dotColor(tester), context.forge.info);
  });

  testWidgets('a failure shows Save Error with the message in a tooltip', (
    tester,
  ) async {
    final context = await pump(
      tester,
      const SaveError('Another item already uses the export key "sword".'),
    );
    expect(find.text('Save Error'), findsOneWidget);
    expect(
      find.byTooltip('Another item already uses the export key "sword".'),
      findsOneWidget,
    );
    expect(dotColor(tester), context.colors.error);
  });

  testWidgets('the shell shows the indicator in its save status slot', (
    tester,
  ) async {
    final harness = await ShellHarness.pump(tester);
    await harness.openProject(tester);
    final slot = find.byKey(AppShell.saveStatusSlotKey);
    expect(tester.widget(slot), isA<SaveStatusIndicator>());
    expect(
      find.descendant(of: slot, matching: find.text('All changes saved')),
      findsOneWidget,
    );
  }, variant: linux);
}
