import 'dart:async';
import 'dart:io';

import 'package:anvil/app/project/checkpoint_scheduler.dart';
import 'package:anvil/app/providers.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_bootstrap_test.dart' show AppHarness;
import '../dialogs/fakes.dart' show copyFixture;

/// A timer the test fires by hand.
class FakeTimer implements Timer {
  FakeTimer(this.delay, this._callback);

  final Duration delay;
  final void Function() _callback;
  var _active = true;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;

  @override
  void cancel() => _active = false;

  void fire() {
    if (!_active) return;
    _active = false;
    _callback();
  }
}

void main() {
  late AppHarness app;
  late ProjectService service;
  late ProviderContainer container;
  late ProjectSession session;
  late String path;
  final timers = <FakeTimer>[];

  setUp(() async {
    timers.clear();
    app = AppHarness.create();
    service = ProjectService(supportDirectory: app.directory.path);
    path = copyFixture();
    session = ((await service.open(path)) as ProjectOpened).session;
    addTearDown(() async {
      if (session.isOpen) await service.close(session);
    });
    container = ProviderContainer(
      overrides: [
        ...app.overrides,
        checkpointTimerFactoryProvider.overrideWithValue((delay, callback) {
          final timer = FakeTimer(delay, callback);
          timers.add(timer);
          return timer;
        }),
      ],
    );
    addTearDown(container.dispose);
    container.read(projectSessionProvider.notifier).set(session);
    // Keep the auto-dispose scheduler alive, as the mounted shell does.
    container.listen(checkpointSchedulerProvider, (_, _) {});
  });

  List<FakeTimer> active() => timers.where((t) => t.isActive).toList();

  /// Commits a save, which lands in the -wal file only, and bumps the
  /// epoch as every write path does. Returns the main file's bytes.
  List<int> write(String description) {
    final before = File(path).readAsBytesSync();
    session.database.saveTransaction(description, (_) {});
    expect(File(path).readAsBytesSync(), before);
    container.read(writeEpochProvider.notifier).bump();
    return before;
  }

  test('a bump runs one PASSIVE checkpoint after the quiet delay', () {
    final before = write('first');
    expect(active(), hasLength(1));
    expect(active().single.delay, quietCheckpointDelay);
    expect(quietCheckpointDelay, const Duration(seconds: 5));
    expect(File(path).readAsBytesSync(), before);

    active().single.fire();
    // The checkpoint copied the WAL pages into the main file.
    expect(File(path).readAsBytesSync(), isNot(before));
    expect(File('$path-wal').lengthSync(), greaterThan(0)); // PASSIVE keeps it
    expect(active(), isEmpty);
    expect(timers, hasLength(1));
  });

  test('a second bump within the delay restarts the timer: one checkpoint', () {
    final before = write('first');
    write('second');
    expect(timers, hasLength(2));
    expect(timers.first.isActive, isFalse);
    expect(active(), hasLength(1));

    active().single.fire();
    expect(File(path).readAsBytesSync(), isNot(before));
    expect(timers.where((t) => t.isActive), isEmpty);
  });

  test('clearing the session cancels the pending checkpoint', () {
    final before = write('first');
    expect(active(), hasLength(1));

    container.read(projectSessionProvider.notifier).clear();
    expect(active(), isEmpty);
    expect(File(path).readAsBytesSync(), before);

    // A bump with no session schedules nothing.
    container.read(writeEpochProvider.notifier).bump();
    expect(active(), isEmpty);
  });

  test('a session closed before the timer fires is left alone', () async {
    write('first');
    final timer = active().single;
    await service.close(session);
    expect(timer.fire, returnsNormally);
    expect(app.logLines.where((l) => l.contains('checkpoint')), isEmpty);
  });
}
