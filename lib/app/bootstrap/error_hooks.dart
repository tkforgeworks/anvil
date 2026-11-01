import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/foundation.dart';

/// Routes unhandled errors to the file logger (design §14.2), replacing
/// 0.1.6's `uncaughtException` and `unhandledRejection` handlers. Each
/// unhandled error writes exactly one `ERROR` entry (its stack follows on
/// the next lines of the same entry).
///
/// [FlutterError.onError] covers errors the framework catches (build,
/// layout, paint, gestures); in debug builds they are also shown as usual.
/// [PlatformDispatcher.onError] covers errors that reach the root isolate's
/// dispatcher; returning true marks them handled.
void installErrorHooks(AppLogger logger) {
  FlutterError.onError = (details) {
    logger.error(
      'Unhandled Flutter error: ${details.exceptionAsString()}',
      null,
      details.stack,
    );
    if (kDebugMode) FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    logger.error('Unhandled platform error', error, stack);
    return true;
  };
}

/// The `runZonedGuarded` handler: errors no other hook caught, such as an
/// unawaited future that fails inside the app zone.
void Function(Object, StackTrace) zoneErrorHandler(AppLogger logger) =>
    (error, stack) => logger.error('Unhandled zone error', error, stack);
