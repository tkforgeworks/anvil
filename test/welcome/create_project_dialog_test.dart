import 'dart:io';

import 'package:anvil/app/shell/project_open_placeholder.dart';
import 'package:anvil/app/welcome/create_project_dialog.dart';
import 'package:anvil/app/welcome/welcome_page.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../dialogs/fakes.dart';

final linux = TargetPlatformVariant.only(TargetPlatform.linux);

void main() {
  final nameField = find.byKey(const ValueKey('create-project-name'));
  final titleField = find.byKey(const ValueKey('create-project-title'));
  final preview = find.byKey(const ValueKey('create-project-preview'));

  bool createEnabled(WidgetTester tester) =>
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Create'))
          .onPressed !=
      null;

  Future<LifecycleHarness> openDialog(
    WidgetTester tester, {
    String? settingsJson,
  }) async {
    final harness = LifecycleHarness.create(settingsJson: settingsJson);
    await harness.pump(tester);
    await tester.tap(find.text('New project'));
    await tester.pumpAndSettle();
    expect(find.byType(CreateProjectDialog), findsOneWidget);
    expect(find.text('Create New Project'), findsOneWidget);
    return harness;
  }

  testWidgets('Create needs a name, a title and a folder (trimmed)', (
    tester,
  ) async {
    final harness = await openDialog(tester);
    harness.dialogs.directory = '/games';
    expect(createEnabled(tester), isFalse);

    // Blank name.
    await tester.enterText(nameField, '   ');
    await tester.enterText(titleField, 'Saga');
    await tester.tap(find.text('Choose Folder…'));
    await tester.pumpAndSettle();
    expect(find.text('/games'), findsOneWidget);
    expect(createEnabled(tester), isFalse);

    // Blank title.
    await tester.enterText(nameField, 'World');
    await tester.enterText(titleField, ' ');
    await tester.pump();
    expect(createEnabled(tester), isFalse);

    await tester.enterText(titleField, 'Saga');
    await tester.pump();
    expect(createEnabled(tester), isTrue);
    expect(harness.service.calls, isEmpty);
  }, variant: linux);

  testWidgets('no folder keeps Create disabled and shows no preview', (
    tester,
  ) async {
    final harness = await openDialog(tester);
    await tester.enterText(nameField, 'World');
    await tester.enterText(titleField, 'Saga');
    await tester.pump();
    expect(find.text('No folder selected'), findsOneWidget);
    expect(preview, findsNothing);
    expect(createEnabled(tester), isFalse);

    // A cancelled picker leaves it that way.
    await tester.tap(find.text('Choose Folder…'));
    await tester.pumpAndSettle();
    expect(harness.dialogs.requests, hasLength(1));
    expect(createEnabled(tester), isFalse);
  }, variant: linux);

  testWidgets('the preview shows the file the core will create', (
    tester,
  ) async {
    final harness = await openDialog(tester);
    harness.dialogs.directory = '/games';
    await tester.enterText(nameField, '  My: Game ');
    await tester.enterText(titleField, 'Saga');
    await tester.tap(find.text('Choose Folder…'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(preview).data,
      '/games/My_ Game/database/My_ Game.anvil',
    );
    expect(projectFilePreview('/games/', 'x'), '/games/x/database/x.anvil');
    expect(projectFilePreview('/games', ':::'), isNull);
  }, variant: linux);

  testWidgets('the folder picker starts at the default save location', (
    tester,
  ) async {
    final harness = await openDialog(
      tester,
      settingsJson: '{"defaultSaveLocation":"/home/me/Anvil"}',
    );
    await tester.tap(find.text('Choose Folder…'));
    await tester.pumpAndSettle();
    expect(harness.dialogs.requests, ['directory from /home/me/Anvil']);
  }, variant: linux);

  testWidgets('without one it starts at the Documents folder', (tester) async {
    final harness = await openDialog(tester);
    await tester.tap(find.text('Choose Folder…'));
    await tester.pumpAndSettle();
    expect(harness.dialogs.requests, [
      'directory from ${LifecycleHarness.documentsDirectory}',
    ]);
  }, variant: linux);

  testWidgets('a failed create shows the core message and keeps the dialog', (
    tester,
  ) async {
    final harness = await openDialog(tester);
    harness.dialogs.directory = '/games';
    harness.service.createError = const ProjectCreateFailed(
      'Folder already exists: /games/World',
    );
    await tester.enterText(nameField, 'World');
    await tester.enterText(titleField, 'Saga');
    await tester.tap(find.text('Choose Folder…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(harness.service.calls, ['create World | Saga | /games']);
    expect(find.byType(CreateProjectDialog), findsOneWidget);
    expect(find.text('Folder already exists: /games/World'), findsWidgets);

    // Closing the dialog takes the failure with it.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(CreateProjectDialog), findsNothing);
    expect(find.text('Folder already exists: /games/World'), findsNothing);
  }, variant: linux);

  testWidgets('a successful create closes the dialog and opens the project', (
    tester,
  ) async {
    final harness = await openDialog(tester);
    final parent = harness.app.directory.path;
    harness.dialogs.directory = parent;
    await tester.enterText(nameField, ' New World ');
    await tester.enterText(titleField, ' Saga ');
    await tester.tap(find.text('Choose Folder…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(harness.service.calls, ['create New World | Saga | $parent']);
    expect(find.byType(CreateProjectDialog), findsNothing);
    expect(find.byType(ProjectOpenPlaceholder), findsOneWidget);
    expect(find.text('New World'), findsOneWidget);
    expect(find.text('Saga'), findsOneWidget);
    final file = '$parent/New World/database/New World.anvil';
    expect(find.text(file), findsOneWidget);
    expect(File(file).existsSync(), isTrue);

    await tester.tap(find.text('Close Project'));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomePage), findsOneWidget);
    // The page re-read the list: the new project is on it.
    expect(find.text('New World'), findsOneWidget);
    expect(File('$file.lock').existsSync(), isFalse);
  }, variant: linux);
}
