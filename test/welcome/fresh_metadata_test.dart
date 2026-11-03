import 'package:anvil/app/dashboard/dashboard_providers.dart';
import 'package:anvil/app/dialogs/file_dialogs.dart';
import 'package:anvil/app/menu/menu_commands.dart';
import 'package:anvil/app/providers.dart';
import 'package:anvil/app/shell/app_shell.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil/app/welcome/welcome_page.dart';
import 'package:anvil/main.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_bootstrap_test.dart' show AppHarness;
import '../dialogs/fakes.dart';
import '../menu/menu_harness.dart' show openSection;

/// ANVL-204: the session's metadata follows writes while the project is
/// open, and closing it writes the current title and counts to the recent
/// list the Welcome page shows. Real `ProjectService` over a copy of the
/// 0.1.6 fixture; only the native dialog is faked.
void main() {
  testWidgets(
    'a new game title and an added item show on the Welcome page after '
    'close',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = AppHarness.create();
      final dialogs = FakeFileDialogs()..anvilFile = copyFixture();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...app.overrides,
            fileDialogsProvider.overrideWithValue(dialogs),
          ],
          retry: (_, _) => null,
          child: const AnvilApp(),
        ),
      );
      await tester.tap(find.text('Open file...'));
      await pumpUntil(
        tester,
        () => find.byType(AppShell).evaluate().isNotEmpty,
      );

      final container = appContainer(tester);
      final session = container.read(projectSessionProvider)!;
      expect(
        container.read(dashboardProjectProvider)!.gameTitle,
        'Forge & Fable',
      );
      expect(container.read(dashboardProjectProvider)!.recordCounts.items, 5);

      await tester.runAsync(() async {
        final draft = await session.meta.loadProjectSettings();
        await session.meta.saveProjectSettings(
          draft.copyWith(gameTitle: 'Ashes of Forge'),
        );
        await session.items.create(
          const CreateItemInput(
            displayName: 'Stick',
            exportKey: 'stick',
            itemCategoryId: 'item-category-weapon',
            rarityId: 'rarity-common',
          ),
        );
      });
      container.read(writeEpochProvider.notifier).bump();
      await tester.pump(const Duration(milliseconds: 1));

      final refreshed = container.read(dashboardProjectProvider)!;
      expect(refreshed.gameTitle, 'Ashes of Forge');
      expect(refreshed.recordCounts.items, 6);
      expect(session.metadata, same(refreshed));

      await openSection(tester, 'File');
      await tester.tap(
        find.byKey(ValueKey('menu-${MenuCommand.closeProject.id}')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WelcomePage), findsOneWidget);
      expect(find.text('Ashes of Forge'), findsOneWidget);
      expect(find.text('Forge & Fable'), findsNothing);
      expect(
        find.text(
          '· 6 items · 2 abilities · 2 classes · 2 NPCs · 2 recipes · '
          '1 loot tables',
        ),
        findsOneWidget,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
}
