import 'package:anvil/app/dashboard/count_tile.dart';
import 'package:anvil/app/dashboard/dashboard_page.dart';
import 'package:anvil/app/domains/classes/classes_editor_page.dart';
import 'package:anvil/app/shell/app_shell.dart';
import 'package:anvil/app/shell/shell_domain.dart';
import 'package:anvil/app/validation/validation_page.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../shell/shell_harness.dart';

/// The two pages over the real 0.1.6 fixture in the real shell: its one
/// validation issue is a class warning (`validation-issues-fixture.json`).
void main() {
  testWidgets(
    'the fixture opens on the dashboard with its counts, and its class '
    'warning opens the class editor from the Validation page',
    (tester) async {
      final harness = await ShellHarness.pump(
        tester,
        settingsJson: '{"editingMode": "full-page"}',
      );
      await harness.openProject(tester);
      await tester.pumpAndSettle();

      expect(harness.location, '/');
      final dashboard = find.descendant(
        of: find.byType(AppShell),
        matching: find.byType(DashboardPage),
      );
      expect(dashboard, findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(CountTile.keyOf(ShellDomain.items)),
          matching: find.text('5'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dashboard, matching: find.text('1 issue')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dashboard, matching: find.text('1 warning')),
        findsOneWidget,
      );

      await tester.tap(find.text('1 issue'));
      await tester.pumpAndSettle();
      expect(harness.location, '/validation');
      expect(find.byType(ValidationPage), findsOneWidget);
      expect(find.textContaining('Last checked: '), findsOneWidget);
      final row = find.byKey(
        ValidationPage.rowKey(ValidationDomain.classes, 0),
      );
      expect(
        find.descendant(of: row, matching: find.text('Warrior')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('derivedStat:Max HP')),
        findsOneWidget,
      );

      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(
        harness.location,
        ShellDomain.classes.editorLocation(
          '8cb0cf2e-a3f2-47ad-ad82-158dc9eb3d8a',
        ),
      );
      expect(find.byType(ClassEditorPage), findsOneWidget);
    },
    variant: linux,
  );
}
