import 'dart:async';
import 'dart:io';

import 'package:anvil/app/editor/exit_prompt.dart';
import 'package:anvil/app/project/project_lifecycle.dart';
import 'package:anvil/app/providers.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../dialogs/fakes.dart';

/// The project-level leave guard as the lifecycle notifier sees it: each
/// call is counted and answered from [answer], or held on [pending].
class FakeLeaveGuard {
  var calls = 0;
  var answer = true;
  Completer<bool>? pending;

  Future<bool> call() {
    calls++;
    return pending?.future ?? Future.value(answer);
  }
}

void main() {
  late LifecycleHarness harness;
  late FakeLeaveGuard guard;
  late ProviderContainer container;

  setUp(() {
    harness = LifecycleHarness.create();
    guard = FakeLeaveGuard();
    container = ProviderContainer(
      overrides: [
        ...harness.overrides,
        leaveGuardProvider.overrideWithValue(guard.call),
      ],
      retry: (_, _) => null,
    );
    addTearDown(() async {
      final session = container.read(projectSessionProvider);
      if (session != null && session.isOpen) {
        await ProjectService(supportDirectory: harness.app.directory.path)
            .close(session);
      }
      container.dispose();
    });
  });

  ProjectLifecycleState state() => container.read(projectLifecycleProvider);
  ProjectLifecycleNotifier lifecycle() =>
      container.read(projectLifecycleProvider.notifier);
  ProjectSession? session() => container.read(projectSessionProvider);

  /// Opens a fixture copy (no guard: nothing is open yet) and clears the
  /// service's call log.
  Future<ProjectSession> openFirst() async {
    await lifecycle().openPath(copyFixture(name: 'first'));
    expect(guard.calls, 0, reason: 'nothing open, nothing to guard');
    harness.service.calls.clear();
    return session()!;
  }

  /// [open] is still the current, open session and nothing ran.
  void expectUntouched(ProjectSession open) {
    expect(session(), same(open));
    expect(open.isOpen, isTrue);
    expect(state(), const ProjectLifecycleState.idle());
    expect(harness.service.calls, isEmpty);
  }

  group('the guard answers to stay', () {
    setUp(() => guard.answer = false);

    test('closeProject leaves the session open', () async {
      final open = await openFirst();
      await lifecycle().closeProject();
      expect(guard.calls, 1);
      expectUntouched(open);
    });

    test('openPath neither closes nor opens', () async {
      final open = await openFirst();
      await lifecycle().openPath(copyFixture(name: 'second'));
      expect(guard.calls, 1);
      expectUntouched(open);
    });

    test(
      'openWithDialog asks for the file first, then the guard once',
      () async {
        final open = await openFirst();
        harness.dialogs.anvilFile = copyFixture(name: 'second');
        await lifecycle().openWithDialog();
        expect(harness.dialogs.requests, ['anvil file from null']);
        expect(guard.calls, 1);
        expectUntouched(open);
      },
    );

    test('create returns false and creates nothing', () async {
      final open = await openFirst();
      final parent = harness.app.directory.path;
      expect(await lifecycle().create('New World', 'Saga', parent), isFalse);
      expect(guard.calls, 1);
      expectUntouched(open);
      expect(Directory('$parent/New World').existsSync(), isFalse);
    });

    test('saveAs returns null and writes nothing', () async {
      final open = await openFirst();
      final target = '${harness.app.directory.path}/copy.anvil';
      expect(await lifecycle().saveAs(target), isNull);
      expect(guard.calls, 1);
      expectUntouched(open);
      expect(File(target).existsSync(), isFalse);
    });
  });

  group('the guard answers to leave', () {
    test('closeProject closes', () async {
      final open = await openFirst();
      await lifecycle().closeProject();
      expect(guard.calls, 1);
      expect(open.isOpen, isFalse);
      expect(session(), isNull);
      expect(harness.service.calls, ['close Spike Fixture']);
    });

    test('openPath closes the current project and opens the next', () async {
      final open = await openFirst();
      final second = copyFixture(name: 'second');
      await lifecycle().openPath(second);
      expect(guard.calls, 1);
      expect(open.isOpen, isFalse);
      expect(session()!.filePath, second);
    });

    test('create closes the current project and creates', () async {
      final open = await openFirst();
      final parent = harness.app.directory.path;
      expect(await lifecycle().create('New World', 'Saga', parent), isTrue);
      expect(guard.calls, 1);
      expect(open.isOpen, isFalse);
      expect(session()!.metadata.projectName, 'New World');
    });

    test('saveAs makes the copy the open project', () async {
      final open = await openFirst();
      final target = '${harness.app.directory.path}/copy.anvil';
      expect(await lifecycle().saveAs(target), isNull);
      expect(guard.calls, 1);
      expect(open.isOpen, isFalse);
      expect(session()!.filePath, target);
    });
  });

  test('the guard runs before the notifier goes busy', () async {
    final open = await openFirst();
    guard.pending = Completer<bool>();
    final closing = lifecycle().closeProject();
    await Future<void>.delayed(Duration.zero);
    expect(guard.calls, 1);
    expect(state(), const ProjectLifecycleState.idle());
    expect(session(), same(open));

    guard.pending!.complete(true);
    await closing;
    expect(session(), isNull);
  });
}
