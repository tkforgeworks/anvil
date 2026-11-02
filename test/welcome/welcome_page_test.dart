import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show AppBar;
import 'package:anvil/app/project/project_lifecycle.dart';
import 'package:anvil/app/providers.dart';
import 'package:anvil/app/shell/app_shell.dart';
import 'package:anvil/app/welcome/recent_projects_list.dart';
import 'package:anvil/app/welcome/upgrade_project_dialog.dart';
import 'package:anvil/app/welcome/welcome_page.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../dialogs/fakes.dart';

import 'package:anvil/app/menu/menu_commands.dart';

import '../menu/menu_harness.dart' show openSection;

final linux = TargetPlatformVariant.only(TargetPlatform.linux);

void main() {
  testWidgets('no recents shows the hero, both tiles and the empty state', (
    tester,
  ) async {
    final harness = LifecycleHarness.create();
    await harness.pump(tester);

    expect(find.byType(WelcomePage), findsOneWidget);
    expect(find.text('Pick a project, or start a new world.'), findsOneWidget);
    expect(find.text('New project'), findsOneWidget);
    expect(find.text('Open file...'), findsOneWidget);
    expect(find.text(RecentProjectsList.emptyMessage), findsOneWidget);
    expect(find.text('Clear Recents'), findsNothing);
  }, variant: linux);

  testWidgets('recent entries show size, counts, path and their markers', (
    tester,
  ) async {
    final harness = LifecycleHarness.create();
    harness.service.recents = [
      recentEntry(
        name: 'Spike Fixture',
        gameTitle: 'Forge & Fable',
        path: '/games/spike/database/spike.anvil',
        fileSize: 131072,
        counts: const RecordCounts(items: 6, abilities: 3, classes: 2),
      ),
      recentEntry(
        name: 'Lost World',
        path: '/games/lost/database/lost.anvil',
        exists: false,
      ),
      recentEntry(
        name: 'Old Saga',
        path: '/games/old/database/old.anvil',
        isArchived: true,
      ),
    ];
    await harness.pump(tester);

    expect(find.text('Spike Fixture'), findsOneWidget);
    expect(find.text('Forge & Fable'), findsOneWidget);
    expect(find.text('/games/spike/database/spike.anvil'), findsOneWidget);
    expect(find.text('128.0 KB'), findsOneWidget);
    expect(find.text('· 6 items · 3 abilities · 2 classes'), findsOneWidget);
    expect(find.text('· empty project'), findsNWidgets(2));
    expect(find.textContaining('Last saved '), findsNWidgets(3));

    // Missing: marked and faded, and a tap does not open it.
    expect(find.text('· File missing'), findsOneWidget);
    await tester.tap(find.text('Lost World'));
    await tester.pumpAndSettle();
    expect(harness.service.calls, isEmpty);

    // Archived: the 0.1.6 chip, uppercased by the capsule.
    expect(find.text('ARCHIVED'), findsOneWidget);

    // Remove one, then clear the rest.
    await tester.tap(find.text('Remove').at(1));
    await tester.pumpAndSettle();
    expect(harness.service.calls, [
      'removeRecent /games/lost/database/lost.anvil',
    ]);
    expect(find.text('Lost World'), findsNothing);
    expect(find.text('Old Saga'), findsOneWidget);

    await tester.tap(find.text('Clear Recents'));
    await tester.pumpAndSettle();
    expect(harness.service.calls.last, 'clearRecents');
    expect(find.text(RecentProjectsList.emptyMessage), findsOneWidget);
  }, variant: linux);

  testWidgets('a lock conflict shows the exact 0.1.6 message until dismissed', (
    tester,
  ) async {
    final harness = LifecycleHarness.create();
    harness.service.recents = [recentEntry(name: 'Busy', path: '/b.anvil')];
    harness.service.openOutcome = const ProjectLocked('/b.anvil');
    await harness.pump(tester);

    await tester.tap(find.text('Busy'));
    await tester.pumpAndSettle();

    expect(harness.service.calls, ['open /b.anvil']);
    expect(
      find.text('This project is already open in another Anvil window.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(
      find.text('This project is already open in another Anvil window.'),
      findsNothing,
    );
  }, variant: linux);

  testWidgets('an old schema asks before upgrading; Cancel releases the lock', (
    tester,
  ) async {
    final harness = LifecycleHarness.create();
    harness.dialogs.anvilFile = '/p/old.anvil';
    harness.service.openOutcome = const ProjectNeedsUpgrade('/p/old.anvil', 6);
    await harness.pump(tester);

    await tester.tap(find.text('Open file...'));
    await tester.pumpAndSettle();

    expect(find.text('Upgrade Project Schema'), findsOneWidget);
    expect(find.text(UpgradeProjectDialog.message), findsOneWidget);
    expect(
      find.text(
        'Anvil will create an upgraded backup copy and leave the original '
        'project file unchanged.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(UpgradeProjectDialog), findsNothing);
    expect(harness.service.calls.last, 'cancelUpgrade /p/old.anvil');
    expect(
      appContainer(tester).read(projectLifecycleProvider),
      const ProjectLifecycleState.idle(),
    );
  }, variant: linux);

  testWidgets('Escape on the upgrade prompt cancels too', (tester) async {
    final harness = LifecycleHarness.create();
    harness.dialogs.anvilFile = '/p/old.anvil';
    harness.service.openOutcome = const ProjectNeedsUpgrade('/p/old.anvil', 3);
    await harness.pump(tester);

    await tester.tap(find.text('Open file...'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(UpgradeProjectDialog), findsNothing);
    expect(harness.service.calls.last, 'cancelUpgrade /p/old.anvil');
  }, variant: linux);

  testWidgets('Upgrade Copy opens the upgraded copy', (tester) async {
    final harness = LifecycleHarness.create();
    harness.dialogs.anvilFile = '/p/old.anvil';
    harness.service.openOutcome = const ProjectNeedsUpgrade('/p/old.anvil', 6);
    harness.service.upgradeTarget = copyFixture(name: 'old_backup');
    await harness.pump(tester);

    await tester.tap(find.text('Open file...'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upgrade Copy'));
    await pumpUntil(tester, () => find.byType(AppShell).evaluate().isNotEmpty);

    expect(harness.service.calls, contains('upgradeCopy /p/old.anvil'));
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Spike Fixture'),
      ),
      findsOneWidget,
    );
    expect(
      appContainer(tester).read(projectSessionProvider)!.filePath,
      harness.service.upgradeTarget,
    );

    await openSection(tester, 'File');
    await tester.tap(
      find.byKey(ValueKey('menu-${MenuCommand.closeProject.id}')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(WelcomePage), findsOneWidget);
  }, variant: linux);

  testWidgets('recovery mode replaces the welcome content until Back', (
    tester,
  ) async {
    final harness = LifecycleHarness.create();
    harness.dialogs.anvilFile = '/p/broken.anvil';
    harness.service.openOutcome = const ProjectRecovery(
      '/p/broken.anvil',
      'broken.anvil',
      'SQLite integrity check failed: *** in database main ***',
    );
    await harness.pump(tester);

    await tester.tap(find.text('Open file...'));
    await tester.pumpAndSettle();

    expect(find.byType(RecoveryView), findsOneWidget);
    expect(find.text('Recovery mode is active.'), findsOneWidget);
    expect(find.text('broken.anvil'), findsOneWidget);
    expect(
      find.text('SQLite integrity check failed: *** in database main ***'),
      findsOneWidget,
    );
    expect(find.text('New project'), findsNothing);

    await tester.tap(find.text('Back to Welcome'));
    await tester.pumpAndSettle();
    expect(find.byType(RecoveryView), findsNothing);
    expect(find.text('New project'), findsOneWidget);
  }, variant: linux);
}
