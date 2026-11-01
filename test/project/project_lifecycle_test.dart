import 'dart:io';

import 'package:anvil/app/project/project_lifecycle.dart';
import 'package:anvil/app/providers.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../dialogs/fakes.dart';

void main() {
  // The default leave guard looks up the root navigator's GlobalKey, which
  // needs a binding; with none mounted it answers true at once.
  TestWidgetsFlutterBinding.ensureInitialized();

  late LifecycleHarness harness;
  late ProviderContainer container;

  setUp(() {
    harness = LifecycleHarness.create();
    container = harness.container();
  });

  ProjectLifecycleState state() => container.read(projectLifecycleProvider);
  ProjectLifecycleNotifier lifecycle() =>
      container.read(projectLifecycleProvider.notifier);
  ProjectSession? session() => container.read(projectSessionProvider);

  test('starts idle with no session', () {
    expect(state(), const ProjectLifecycleState.idle());
    expect(session(), isNull);
  });

  test('opening a file sets the session and logs the 0.1.6 line', () async {
    final path = copyFixture();
    await lifecycle().openPath(path);

    expect(state(), const ProjectLifecycleState.idle());
    expect(session()!.metadata.projectName, 'Spike Fixture');
    expect(
      harness.app.logLines.where((l) => l.endsWith('Project opened')),
      hasLength(1),
    );
  });

  test('openWithDialog opens the picked file; a cancel does nothing', () async {
    await lifecycle().openWithDialog();
    expect(harness.service.calls, isEmpty);
    expect(harness.dialogs.requests, ['anvil file from null']);

    final path = copyFixture();
    harness.dialogs.anvilFile = path;
    await lifecycle().openWithDialog();
    expect(harness.service.calls, ['open $path']);
    expect(session()!.filePath, path);
  });

  test('a lock conflict is a failure with the exact 0.1.6 message', () async {
    harness.service.openOutcome = const ProjectLocked('/x.anvil');
    await lifecycle().openPath('/x.anvil');

    expect(
      state(),
      const ProjectLifecycleState.failed(
        'This project is already open in another Anvil window.',
      ),
    );
    expect(session(), isNull);
    expect(
      harness.app.logLines.where((l) => l.contains('Project lock conflict')),
      hasLength(1),
    );

    lifecycle().dismiss();
    expect(state(), const ProjectLifecycleState.idle());
  });

  test('a recovery result enters recovery mode', () async {
    harness.service.openOutcome = const ProjectRecovery(
      '/p/broken.anvil',
      'broken.anvil',
      'SQLite integrity check failed: x',
    );
    await lifecycle().openPath('/p/broken.anvil');

    expect(
      state(),
      const ProjectLifecycleState.recovery(
        'broken.anvil',
        'SQLite integrity check failed: x',
      ),
    );
    expect(
      harness.app.logLines.where(
        (l) => l.contains('Project open failed, entering recovery mode'),
      ),
      hasLength(1),
    );
    lifecycle().dismiss();
    expect(state(), const ProjectLifecycleState.idle());
  });

  test('the real service puts a missing file into recovery mode', () async {
    final missing = '${harness.app.directory.path}/gone.anvil';
    await lifecycle().openPath(missing);
    expect(
      state(),
      const ProjectLifecycleState.recovery(
        'gone.anvil',
        ProjectService.missingFileMessage,
      ),
    );
  });

  group('needs upgrade', () {
    setUp(() {
      harness.service.openOutcome = const ProjectNeedsUpgrade(
        '/p/old.anvil',
        6,
      );
    });

    test('Cancel releases the lock through the service', () async {
      await lifecycle().openPath('/p/old.anvil');
      expect(
        state(),
        const ProjectLifecycleState.needsUpgrade('/p/old.anvil', 6),
      );

      lifecycle().cancelUpgrade();
      expect(harness.service.calls.last, 'cancelUpgrade /p/old.anvil');
      expect(state(), const ProjectLifecycleState.idle());
      expect(session(), isNull);
    });

    test('dismiss also cancels, so the lock is never left behind', () async {
      await lifecycle().openPath('/p/old.anvil');
      lifecycle().dismiss();
      expect(harness.service.calls.last, 'cancelUpgrade /p/old.anvil');
    });

    test('Upgrade Copy opens the copy', () async {
      harness.service.upgradeTarget = copyFixture(name: 'old_backup');
      await lifecycle().openPath('/p/old.anvil');
      await lifecycle().upgradeCopy();

      expect(harness.service.calls.last, 'upgradeCopy /p/old.anvil');
      expect(state(), const ProjectLifecycleState.idle());
      expect(session()!.filePath, harness.service.upgradeTarget);
    });

    test('a failed upgrade enters recovery mode', () async {
      harness.service.upgradeError = const ProjectUpgradeFailed(
        'old.anvil',
        'Migration failed: 007_save_history',
      );
      await lifecycle().openPath('/p/old.anvil');
      await lifecycle().upgradeCopy();

      expect(
        state(),
        const ProjectLifecycleState.recovery(
          'old.anvil',
          'Migration failed: 007_save_history',
        ),
      );
    });
  });

  test('create makes the new project current', () async {
    final parent = harness.app.directory.path;
    final ok = await lifecycle().create(' New World ', 'Saga', parent);

    expect(ok, isTrue);
    expect(session()!.metadata.projectName, 'New World');
    expect(session()!.filePath, '$parent/New World/database/New World.anvil');
    expect(
      harness.app.logLines.where((l) => l.endsWith('Project created')),
      hasLength(1),
    );
  });

  test('a failed create reports the core message', () async {
    final parent = harness.app.directory.path;
    Directory('$parent/Taken').createSync();
    final ok = await lifecycle().create('Taken', 'T', parent);

    expect(ok, isFalse);
    expect(
      state(),
      ProjectLifecycleState.failed('Folder already exists: $parent/Taken'),
    );
    expect(session(), isNull);
  });

  test('opening while a project is open closes it first', () async {
    final first = copyFixture(name: 'first');
    final second = copyFixture(name: 'second');
    await lifecycle().openPath(first);
    final firstSession = session()!;

    await lifecycle().openPath(second);
    expect(firstSession.isOpen, isFalse);
    expect(File('$first.lock').existsSync(), isFalse);
    expect(session()!.filePath, second);
  });

  test('closeProject closes the session and clears it', () async {
    await lifecycle().openPath(copyFixture());
    final open = session()!;

    await lifecycle().closeProject();
    expect(open.isOpen, isFalse);
    expect(session(), isNull);
    expect(harness.service.calls.last, 'close Spike Fixture');
    expect(
      harness.app.logLines.where((l) => l.endsWith('Project closed')),
      hasLength(1),
    );
  });

  test('remove and clear go through the service and re-read the list', () {
    harness.service.recents = [
      recentEntry(name: 'A', path: '/a.anvil'),
      recentEntry(name: 'B', path: '/b.anvil'),
    ];
    final sub = container.listen(recentProjectsProvider, (_, _) {});
    addTearDown(sub.close);
    expect(sub.read(), hasLength(2));

    lifecycle().removeRecent('/a.anvil');
    expect(harness.service.calls, ['removeRecent /a.anvil']);
    expect(sub.read().map((r) => r.project.projectName), ['B']);

    lifecycle().clearRecents();
    expect(harness.service.calls.last, 'clearRecents');
    expect(sub.read(), isEmpty);
  });
}
