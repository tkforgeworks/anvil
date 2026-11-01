import 'dart:async';
import 'dart:ui';

import 'package:anvil/app/bootstrap/error_hooks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_bootstrap_test.dart' show AppHarness;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppHarness harness;
  late FlutterExceptionHandler? savedFlutterOnError;
  late ErrorCallback? savedPlatformOnError;
  late FlutterExceptionHandler savedPresentError;

  List<String> errorLines() =>
      harness.logLines.where((l) => l.contains('[ERROR]')).toList();

  setUp(() {
    harness = AppHarness.create();
    savedFlutterOnError = FlutterError.onError;
    savedPlatformOnError = PlatformDispatcher.instance.onError;
    savedPresentError = FlutterError.presentError;
    // Keep debug-mode presentation out of the test output.
    FlutterError.presentError = (_) {};
    installErrorHooks(harness.logger);
  });

  tearDown(() {
    FlutterError.onError = savedFlutterOnError;
    PlatformDispatcher.instance.onError = savedPlatformOnError;
    FlutterError.presentError = savedPresentError;
  });

  test('a reported Flutter error writes one ERROR line', () {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: StateError('layout broke'),
        stack: StackTrace.current,
      ),
    );

    final lines = errorLines();
    expect(lines, hasLength(1));
    expect(lines.single, contains('Bad state: layout broke'));
  });

  test('a platform dispatcher error writes one ERROR line and is handled', () {
    final handled = PlatformDispatcher.instance.onError!(
      ArgumentError('lost future'),
      StackTrace.current,
    );

    expect(handled, isTrue);
    final lines = errorLines();
    expect(lines, hasLength(1));
    expect(lines.single, contains('lost future'));
  });

  test('a zone error writes one ERROR line', () async {
    final caught = Completer<void>();
    final log = zoneErrorHandler(harness.logger);
    runZonedGuarded(
      () {
        // An unawaited failing future, as a fire-and-forget call would leave.
        unawaited(Future<void>(() => throw const FormatException('bad zone')));
      },
      (error, stack) {
        log(error, stack);
        caught.complete();
      },
    );
    await caught.future;

    final lines = errorLines();
    expect(lines, hasLength(1));
    expect(lines.single, contains('bad zone'));
  });
}
