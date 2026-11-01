/// Quiet WAL checkpoints while a project is open (design §8 "Checkpoint
/// quietly", §12.6).
///
/// 0.1.6 ran `wal_checkpoint(TRUNCATE)` on every save. 0.2.0 runs a
/// `PASSIVE` checkpoint once writes have stopped for
/// [quietCheckpointDelay]; the `TRUNCATE` checkpoint happens when the
/// project closes (`ProjectService.close`), including on app exit.
library;

import 'dart:async';

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../shell/shell_providers.dart';

/// How long after the last write the passive checkpoint runs.
const quietCheckpointDelay = Duration(seconds: 5);

/// Starts a one-shot timer; tests override [checkpointTimerFactoryProvider]
/// so they do not wait.
typedef CheckpointTimerFactory = Timer Function(
  Duration delay,
  void Function() callback,
);

final checkpointTimerFactoryProvider = Provider<CheckpointTimerFactory>(
  (ref) => Timer.new,
);

/// Alive while something watches it (the shell does while it is mounted).
final checkpointSchedulerProvider =
    NotifierProvider.autoDispose<CheckpointScheduler, void>(
      CheckpointScheduler.new,
    );

/// Listens to [writeEpochProvider]: every bump (re)starts a
/// [quietCheckpointDelay] timer, and when it fires with no further bump a
/// `PASSIVE` checkpoint runs on the open session's database. A change or
/// clear of the session cancels the pending timer. A failed checkpoint is
/// logged as a warning and never thrown; `PASSIVE` never waits for the
/// background readers (validation, export) and so never blocks the UI on
/// them.
class CheckpointScheduler extends Notifier<void> {
  Timer? _timer;

  @override
  void build() {
    ref.listen(writeEpochProvider, (_, _) => _schedule());
    ref.listen(projectSessionProvider, (previous, next) {
      if (!identical(previous, next)) _cancel();
    });
    ref.onDispose(_cancel);
  }

  /// Whether a checkpoint is pending.
  bool get isPending => _timer?.isActive ?? false;

  void _schedule() {
    _cancel();
    if (ref.read(projectSessionProvider) == null) return;
    _timer = ref.read(checkpointTimerFactoryProvider)(
      quietCheckpointDelay,
      _run,
    );
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void _run() {
    _timer = null;
    final session = ref.read(projectSessionProvider);
    if (session == null || !session.isOpen) return;
    try {
      session.database.checkpoint(CheckpointMode.passive);
    } catch (e) {
      ref.read(appLoggerProvider).warn('Quiet checkpoint failed: $e');
    }
  }
}
