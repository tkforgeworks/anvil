/// Rendering custom templates off the UI isolate, with a timeout (design
/// §11.4, defence in depth on top of [RenderLimits]).
library;

import 'dart:async';
import 'dart:isolate';

import 'render_limits.dart';
import 'template/anvil_template.dart';
import 'template/errors.dart';

/// The render did not finish within its timeout; the isolate was killed.
final class RenderTimeout implements Exception {
  RenderTimeout(this.timeout);
  final Duration timeout;

  @override
  String toString() =>
      'Template render timed out after ${timeout.inMilliseconds} ms';
}

/// Parses and renders [source] against [context] in a new isolate.
///
/// Fails with the template's [AnvilTemplateError] (syntax, unsupported,
/// render or limit), with [RenderTimeout] when [timeout] passes first, or
/// with a [RemoteError] for anything unexpected. On timeout the isolate is
/// killed at its next safepoint, so a runaway render stops using CPU. This
/// bounds time only: isolates in one group share a heap, and memory is
/// bounded by the [limits] string caps.
Future<String> renderTemplateIsolated(
  String source,
  Map<String, Object?> context, {
  RenderLimits limits = const RenderLimits(),
  Duration timeout = const Duration(seconds: 10),
}) async {
  final reply = ReceivePort();
  final exited = ReceivePort();
  final isolate = await Isolate.spawn(
    _render,
    (reply.sendPort, source, context, limits),
    onExit: exited.sendPort,
    debugName: 'anvil-template-render',
  );
  try {
    final result = await reply.first.timeout(timeout);
    return switch (result) {
      String output => output,
      final Object error => throw error,
      null => throw StateError('template render isolate returned nothing'),
    };
  } on TimeoutException {
    isolate.kill(priority: Isolate.immediate);
    await exited.first; // the isolate is gone once this fires
    throw RenderTimeout(timeout);
  } finally {
    reply.close();
    exited.close();
  }
}

void _render((SendPort, String, Map<String, Object?>, RenderLimits) message) {
  final (reply, source, context, limits) = message;
  Object result;
  try {
    result = AnvilTemplate.parse(
      source,
      limits: limits,
    ).render(context, limits: limits);
  } on AnvilTemplateError catch (e) {
    result = e;
  } catch (e, stack) {
    result = RemoteError('$e', '$stack');
  }
  reply.send(result);
}
