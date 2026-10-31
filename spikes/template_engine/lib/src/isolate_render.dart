/// Defence in depth: render in a separate isolate and kill it on timeout.
/// A busy isolate is interrupted at its next safepoint by
/// `kill(priority: Isolate.immediate)`. This bounds time only: isolates in
/// one group share a heap, so it does not bound memory.
library;

import 'dart:async';
import 'dart:isolate';

import 'jinja_renderer.dart';
import 'subset/anvil_template.dart';

enum Engine { jinja, subset }

final class RenderTimeout implements Exception {
  RenderTimeout(this.timeout);
  final Duration timeout;

  @override
  String toString() => 'render timed out after ${timeout.inMilliseconds}ms';
}

final class IsolatedRenderError implements Exception {
  IsolatedRenderError(this.message);
  final String message;

  @override
  String toString() => message;
}

Future<String> renderIsolated(
  Engine engine,
  String source,
  Map<String, Object?> context, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final reply = ReceivePort();
  final exited = ReceivePort();
  final isolate = await Isolate.spawn(_entry, (
    reply.sendPort,
    engine,
    source,
    context,
  ), onExit: exited.sendPort);
  try {
    final (ok, text) = await reply.first.timeout(timeout) as (bool, String);
    if (ok) return text;
    throw IsolatedRenderError(text);
  } on TimeoutException {
    isolate.kill(priority: Isolate.immediate);
    await exited.first; // the isolate is gone once this fires
    throw RenderTimeout(timeout);
  } finally {
    reply.close();
    exited.close();
  }
}

void _entry((SendPort, Engine, String, Map<String, Object?>) message) {
  final (reply, engine, source, context) = message;
  try {
    final out = switch (engine) {
      Engine.jinja => JinjaRenderer().render(source, context),
      Engine.subset => AnvilTemplate.parse(source).render(context),
    };
    reply.send((true, out));
  } catch (e) {
    reply.send((false, '$e'));
  }
}
