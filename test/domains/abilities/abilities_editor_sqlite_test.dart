import 'dart:io';

import 'package:anvil/app/domains/abilities/abilities_editor_page.dart';
import 'package:anvil/app/domains/abilities/abilities_pages.dart';
import 'package:anvil/app/providers.dart';
import 'package:anvil/app/theme/anvil_theme.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../dialogs/fakes.dart' show copyFixture;
import 'fakes.dart' show linux;

/// The editor over the real repositories on a copy of the 0.1.6 fixture:
/// load, edit, save through the header and the record validation pass.
void main() {
  testWidgets('edits and saves a fixture ability with one history row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final path = copyFixture();
    final support = Directory.systemTemp.createTempSync('anvil-support');
    addTearDown(() => support.deleteSync(recursive: true));
    final service = ProjectService(supportDirectory: support.path);
    final session = (await tester.runAsync(() async {
      return switch (await service.open(path)) {
        ProjectOpened(:final session) => session,
        final other => throw StateError('fixture did not open: $other'),
      };
    }))!;
    addTearDown(() async {
      if (session.isOpen) await service.close(session);
    });
    final container = ProviderContainer(
      overrides: [
        appLoggerProvider.overrideWithValue(
          AppLogger(
            directory: '${support.path}/logs',
            minimumLevel: LogLevel.debug,
          ),
        ),
        initialAppSettingsProvider.overrideWithValue(const AppSettings()),
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    container.read(projectSessionProvider.notifier).set(session);
    final slash = (await session.abilities.list()).firstWhere(
      (a) => a.exportKey == 'slash',
    );
    final historyBefore = (await session.saveHistory.recent()).length;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: anvilTheme(AnvilThemeSpec.dark),
          home: Scaffold(body: abilityEditor(slash.id)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Slash'), findsWidgets);

    await tester.tap(find.widgetWithText(Tab, 'Details'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(AbilityEditorPage.fieldKey('resourceType')),
        matching: find.byType(EditableText),
      ),
      'stamina ',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    final stored = await session.abilities.load(slash.id);
    expect(stored.resourceType, 'stamina');
    final history = await session.saveHistory.recent();
    expect(history.length, historyBefore + 1);
    expect(
      history.where((e) => e.description == 'Slash - Ability changed'),
      hasLength(1),
    );
    expect(find.byKey(const ValueKey('save-bar')), findsNothing);
    expect(find.byKey(const ValueKey('validation-banner')), findsNothing);
  }, variant: linux);
}
