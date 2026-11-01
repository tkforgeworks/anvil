import 'dart:io';

import 'package:anvil/app/dialogs/file_dialogs.dart';
import 'package:anvil/app/project/project_lifecycle.dart';
import 'package:anvil/app/providers.dart';
import 'package:anvil/app/welcome/create_project_dialog.dart';
import 'package:anvil/main.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../app_bootstrap_test.dart' show AppHarness;

/// The Electron 0.1.6 fixture (`Spike Fixture` / `Forge & Fable`, schema
/// 7), located from the repo root where `flutter test` runs.
const fixturePath = 'packages/anvil_core/test/fixtures/sample-0.1.6.anvil';

/// Copies the fixture into a fresh temporary folder as `{name}.anvil` and
/// returns its path; the folder is deleted at tear-down.
String copyFixture({String name = 'sample'}) {
  final dir = Directory.systemTemp.createTempSync('anvil-fixture');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  final target = '${dir.path}/$name.anvil';
  File(fixturePath).copySync(target);
  return target;
}

/// [FileDialogs] answering from fields and recording every request.
class FakeFileDialogs implements FileDialogs {
  String? directory;
  String? anvilFile;
  final requests = <String>[];

  @override
  Future<String?> pickDirectory({String? initialDirectory}) async {
    requests.add('directory from $initialDirectory');
    return directory;
  }

  @override
  Future<String?> pickAnvilFile({String? initialDirectory}) async {
    requests.add('anvil file from $initialDirectory');
    return anvilFile;
  }
}

/// A [ProjectService] over a real one on a temporary support directory,
/// with scripted results. Each override records its call in [calls]; an
/// unscripted call runs the real implementation.
class FakeProjectService extends ProjectService {
  FakeProjectService({required super.supportDirectory});

  final calls = <String>[];

  /// Thrown by [create] instead of creating.
  Object? createError;

  /// Returned (or thrown, for an exception) by [open] instead of opening.
  Object? openOutcome;

  /// Thrown by [upgradeCopy]; otherwise it opens [upgradeTarget].
  Object? upgradeError;
  String? upgradeTarget;

  /// Returned by [recentProjects] when set; remove and clear edit it.
  List<RecentProject>? recents;

  @override
  Future<CreateResult> create({
    required String projectName,
    required String gameTitle,
    required String parentFolder,
  }) async {
    calls.add('create $projectName | $gameTitle | $parentFolder');
    if (createError case final error?) throw error;
    return super.create(
      projectName: projectName,
      gameTitle: gameTitle,
      parentFolder: parentFolder,
    );
  }

  @override
  Future<OpenResult> open(String path) async {
    calls.add('open $path');
    return switch (openOutcome) {
      null => super.open(path),
      final OpenResult result => result,
      final Object error => throw error,
    };
  }

  @override
  Future<ProjectSession> upgradeCopy(String path) async {
    calls.add('upgradeCopy $path');
    if (upgradeError case final error?) throw error;
    final result = await super.open(upgradeTarget!);
    return (result as ProjectOpened).session;
  }

  @override
  void cancelUpgrade(String path) {
    calls.add('cancelUpgrade $path');
    super.cancelUpgrade(path);
  }

  @override
  Future<void> close(ProjectSession session) {
    calls.add('close ${session.metadata.projectName}');
    return super.close(session);
  }

  @override
  List<RecentProject> recentProjects() =>
      recents == null ? super.recentProjects() : List.of(recents!);

  @override
  void removeRecent(String path) {
    calls.add('removeRecent $path');
    final list = recents;
    if (list == null) return super.removeRecent(path);
    list.removeWhere((r) => r.filePath == path);
  }

  @override
  void clearRecents() {
    calls.add('clearRecents');
    final list = recents;
    if (list == null) return super.clearRecents();
    list.clear();
  }
}

/// A recent-list entry with the given fields.
RecentProject recentEntry({
  required String name,
  String gameTitle = 'A Game',
  String path = '/projects/x/database/x.anvil',
  bool exists = true,
  bool? isArchived,
  int fileSize = 2048,
  String lastModifiedAt = '2026-10-31T12:00:00.000Z',
  RecordCounts counts = RecordCounts.empty,
}) => RecentProject(
  project: ProjectMetadata(
    projectName: name,
    gameTitle: gameTitle,
    filePath: path,
    projectFolder: null,
    schemaVersion: 7,
    lastModifiedAt: lastModifiedAt,
    fileSize: fileSize,
    recordCounts: counts,
  ),
  exists: exists,
  isArchived: isArchived,
);

/// The app over an [AppHarness] with the fake service and dialogs.
class LifecycleHarness {
  LifecycleHarness._(this.app, this.service, this.dialogs);

  factory LifecycleHarness.create({String? settingsJson}) {
    final app = AppHarness.create(settingsJson: settingsJson);
    return LifecycleHarness._(
      app,
      FakeProjectService(supportDirectory: app.directory.path),
      FakeFileDialogs(),
    );
  }

  final AppHarness app;
  final FakeProjectService service;
  final FakeFileDialogs dialogs;

  List<Override> get overrides => [
    ...app.overrides,
    projectServiceProvider.overrideWithValue(service),
    fileDialogsProvider.overrideWithValue(dialogs),
    documentsDirectoryProvider.overrideWith((ref) async => documentsDirectory),
  ];

  /// What [documentsDirectoryProvider] answers (the real one asks the OS).
  static const documentsDirectory = '/home/test/Documents';

  /// A container for notifier tests; disposed (closing any open session)
  /// at tear-down.
  ProviderContainer container() {
    final container = ProviderContainer(
      overrides: overrides,
      retry: (_, _) => null,
    );
    addTearDown(() async {
      final session = container.read(projectSessionProvider);
      if (session != null && session.isOpen) {
        await ProjectService(supportDirectory: app.directory.path)
            .close(session);
      }
      container.dispose();
    });
    return container;
  }

  /// Pumps the app at the 0.1.6 window size.
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        retry: (_, _) => null,
        child: const AnvilApp(),
      ),
    );
    await tester.pumpAndSettle();
  }
}

/// The container behind the pumped app.
ProviderContainer appContainer(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AnvilApp)));

/// Lets real I/O (isolates, files) run until [done] holds, pumping frames
/// in between. Widget tests run in fake time, so `ProjectService.open`'s
/// background isolate only completes inside `runAsync`.
Future<void> pumpUntil(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 300 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(
    done(),
    isTrue,
    reason:
        'condition not reached; lifecycle: '
        '${appContainer(tester).read(projectLifecycleProvider)}',
  );
  await tester.pumpAndSettle();
}
