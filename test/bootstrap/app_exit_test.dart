import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:anvil/app/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../shell/shell_harness.dart';

void main() {
  testWidgets('exiting with a project open checkpoints, closes and unlocks '
      'it before the shutdown line', (tester) async {
    final harness = await ShellHarness.pump(tester);
    await harness.openProject(tester);
    final session = harness.container.read(projectSessionProvider)!;
    final path = harness.path;
    session.database.saveTransaction('Exit save - Test changed', (_) {});
    expect(File('$path-wal').lengthSync(), greaterThan(0));
    expect(File('$path.lock').existsSync(), isTrue);

    final response = await tester.binding.handleRequestAppExit();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
    await tester.pump();

    expect(response, AppExitResponse.exit);
    expect(harness.container.read(projectSessionProvider), isNull);
    expect(session.isOpen, isFalse);
    expect(File('$path.lock').existsSync(), isFalse);
    // TRUNCATE: nothing left in the -wal file.
    final wal = File('$path-wal');
    expect(!wal.existsSync() || wal.lengthSync() == 0, isTrue);

    final lines = harness.app.logLines;
    final closed = lines.indexWhere((l) => l.endsWith('Project closed'));
    final shutdown = lines.indexWhere((l) => l.endsWith('Anvil shutting down'));
    expect(closed, isNot(-1));
    expect(shutdown, greaterThan(closed));
    expect(lines.where((l) => l.endsWith('Anvil shutting down')), hasLength(1));
  }, variant: linux);
}
