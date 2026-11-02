import 'dart:io';

import 'package:anvil/app/dialogs/file_dialogs.dart';
import 'package:anvil/app/providers.dart';
import 'package:anvil/app/shell/app_shell.dart';
import 'package:anvil/app/welcome/welcome_page.dart';
import 'package:anvil/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_bootstrap_test.dart' show AppHarness;
import '../dialogs/fakes.dart';

import 'package:anvil/app/menu/menu_commands.dart';

import '../menu/menu_harness.dart' show openSection;

/// The real `ProjectService` (from the root providers) on a temporary
/// support directory, over a copy of the 0.1.6 fixture; only the native
/// dialog is faked.
void main() {
  testWidgets(
    'open the 0.1.6 fixture, see the placeholder, close back to welcome',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = AppHarness.create();
      final dialogs = FakeFileDialogs()..anvilFile = copyFixture();
      final path = dialogs.anvilFile!;

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
      expect(find.byType(WelcomePage), findsOneWidget);

      await tester.tap(find.text('Open file...'));
      await pumpUntil(
        tester,
        () => find.byType(AppShell).evaluate().isNotEmpty,
      );

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Spike Fixture'),
        ),
        findsOneWidget,
      );
      final metadata = appContainer(tester)
          .read(projectSessionProvider)!
          .metadata;
      expect(metadata.gameTitle, 'Forge & Fable');
      expect(metadata.filePath, path);
      expect(File('$path.lock').existsSync(), isTrue);

      await openSection(tester, 'File');
      await tester.tap(
        find.byKey(ValueKey('menu-${MenuCommand.closeProject.id}')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WelcomePage), findsOneWidget);
      expect(File('$path.lock').existsSync(), isFalse);
      // Back on the welcome page, the list is re-read and holds the fixture
      // with its active record counts (one item and one ability are
      // soft-deleted in the fixture).
      expect(find.text('Spike Fixture'), findsOneWidget);
      expect(
        find.text(
          '· 5 items · 2 abilities · 2 classes · 2 NPCs · 2 recipes · '
          '1 loot tables',
        ),
        findsOneWidget,
      );
      expect(find.text(path), findsOneWidget);
      expect(
        app.logLines.where((l) => l.endsWith('Project opened')),
        hasLength(1),
      );
      expect(
        app.logLines.where((l) => l.endsWith('Project closed')),
        hasLength(1),
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
}
