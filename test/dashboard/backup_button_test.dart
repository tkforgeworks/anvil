import 'dart:io';

import 'package:anvil/app/dashboard/backup_button.dart';
import 'package:anvil/app/dashboard/dashboard_page.dart';
import 'package:anvil/app/dialogs/file_dialogs.dart';
import 'package:anvil/app/providers.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_bootstrap_test.dart' show AppHarness;
import '../dialogs/fakes.dart';
import 'dashboard_fakes.dart';

/// Lets the real file work run until a snackbar shows.
Future<void> pumpUntilSnackBar(WidgetTester tester) async {
  final snackBar = find.byType(SnackBar);
  for (var i = 0; i < 300 && snackBar.evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(snackBar, findsOneWidget);
  await tester.pumpAndSettle();
}

void main() {
  group('pure rules', () {
    test('the default name is 0.1.6 backupProject\'s, dated in UTC', () {
      expect(
        defaultBackupName('Spike Fixture', DateTime.utc(2026, 11, 1, 23, 59)),
        'Spike_Fixture-backup-2026-11-01.anvil',
      );
      expect(
        defaultBackupName('Forge & Fable!', DateTime.utc(2026, 1, 2)),
        'Forge___Fable_-backup-2026-01-02.anvil',
      );
      final local = DateTime(2026, 3, 4, 12);
      expect(
        defaultBackupName('a-b_c', local),
        'a-b_c-backup-${local.toUtc().toIso8601String().substring(0, 10)}'
        '.anvil',
      );
    });

    test('the dialog starts in the folder root, else the file\'s folder', () {
      expect(backupFolderOf(sampleMetadata), '/projects/Spike Fixture');
      const loose = ProjectMetadata(
        projectName: 'Loose',
        gameTitle: 'G',
        filePath: '/files/loose.anvil',
        projectFolder: null,
        schemaVersion: 7,
        lastModifiedAt: '2026-10-30T12:00:00.000Z',
        fileSize: 1,
        recordCounts: RecordCounts(),
      );
      expect(backupFolderOf(loose), '/files');
    });
  });

  /// The dashboard with [dialogs] answering the save dialog and, when
  /// [withSession], the 0.1.6 fixture open as the session behind the
  /// lifecycle.
  Future<(PageHarness, ProjectSession?)> pumpDashboard(
    WidgetTester tester,
    FakeFileDialogs dialogs, {
    bool withSession = true,
  }) async {
    final app = AppHarness.create();
    final service = FakeProjectService(supportDirectory: app.directory.path);
    ProjectSession? session;
    if (withSession) {
      final opened = await tester.runAsync(() => service.open(copyFixture()));
      session = (opened! as ProjectOpened).session;
      final open = session;
      addTearDown(() async {
        if (open.isOpen) await service.close(open);
      });
    }
    final harness = PageHarness();
    await harness.pump(
      tester,
      const DashboardPage(),
      overrides: [
        appLoggerProvider.overrideWithValue(app.logger),
        projectServiceProvider.overrideWithValue(service),
        fileDialogsProvider.overrideWithValue(dialogs),
      ],
    );
    if (session != null) {
      harness.container.read(projectSessionProvider.notifier).set(session);
      await tester.pumpAndSettle();
    }
    return (harness, session);
  }

  const request =
      'save location from /projects/Spike Fixture as '
      'Spike_Fixture-backup-2026-11-01.anvil';

  testWidgets('the hero has Backup beside Quick add; cancel does nothing', (
    tester,
  ) async {
    final dialogs = FakeFileDialogs();
    final (harness, session) = await pumpDashboard(tester, dialogs);
    expect(
      find.descendant(
        of: find.byKey(DashboardPage.heroKey),
        matching: find.byKey(BackupButton.buttonKey),
      ),
      findsOneWidget,
    );
    expect(find.text('Backup'), findsOneWidget);

    await tester.tap(find.byKey(BackupButton.buttonKey));
    await tester.pumpAndSettle();

    expect(dialogs.requests, [request]);
    expect(find.byType(SnackBar), findsNothing);
    expect(harness.container.read(projectSessionProvider), same(session));
  }, variant: linux);

  testWidgets('a chosen path gets the backup and the session stays', (
    tester,
  ) async {
    final target = Directory.systemTemp.createTempSync('anvil-backup');
    addTearDown(() => target.deleteSync(recursive: true));
    final path = '${target.path}/copy.anvil';
    final dialogs = FakeFileDialogs()..saveLocation = path;
    final (harness, session) = await pumpDashboard(tester, dialogs);
    final original = session!.filePath;

    await tester.tap(find.byKey(BackupButton.buttonKey));
    await pumpUntilSnackBar(tester);

    expect(dialogs.requests, [request]);
    expect(find.text('Backup saved to $path'), findsOneWidget);
    expect(File(path).existsSync(), isTrue);
    expect(File(ProjectLock.pathFor(path)).existsSync(), isFalse);
    final current = harness.container.read(projectSessionProvider);
    expect(current, same(session));
    expect(current!.isOpen, isTrue);
    expect(current.filePath, original);
  }, variant: linux);

  testWidgets('a path without the extension gets .anvil added', (tester) async {
    final target = Directory.systemTemp.createTempSync('anvil-backup');
    addTearDown(() => target.deleteSync(recursive: true));
    final dialogs = FakeFileDialogs()..saveLocation = '${target.path}/copy';
    await pumpDashboard(tester, dialogs);

    await tester.tap(find.byKey(BackupButton.buttonKey));
    await pumpUntilSnackBar(tester);

    final written = '${target.path}/copy.anvil';
    expect(find.text('Backup saved to $written'), findsOneWidget);
    expect(File(written).existsSync(), isTrue);
    expect(File('${target.path}/copy').existsSync(), isFalse);
  }, variant: linux);

  testWidgets('a failure shows the lifecycle\'s message', (tester) async {
    final dialogs = FakeFileDialogs();
    final (harness, session) = await pumpDashboard(tester, dialogs);
    dialogs.saveLocation = session!.filePath;

    await tester.tap(find.byKey(BackupButton.buttonKey));
    await pumpUntilSnackBar(tester);

    expect(
      find.text('A backup cannot replace the open project file.'),
      findsOneWidget,
    );
    expect(harness.container.read(projectSessionProvider), same(session));
    expect(session.isOpen, isTrue);
  }, variant: linux);

  testWidgets('with no session behind the lifecycle nothing is claimed', (
    tester,
  ) async {
    final dialogs = FakeFileDialogs()..saveLocation = '/nowhere/x.anvil';
    await pumpDashboard(tester, dialogs, withSession: false);

    await tester.tap(find.byKey(BackupButton.buttonKey));
    await tester.pumpAndSettle();

    expect(dialogs.requests, [request]);
    expect(find.byType(SnackBar), findsNothing);
  }, variant: linux);
}
