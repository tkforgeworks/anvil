/// The Undo snackbar behind the instant list actions (design §8.8): soft
/// delete, restore and duplicate apply at once and offer their inverse for
/// a few seconds. The recycle bin shows the same snackbar.
library;

import 'dart:async';

import 'package:flutter/material.dart';

/// How long the Undo snackbar stays before it closes by itself.
const undoSnackBarDuration = Duration(seconds: 5);

/// The snackbar itself.
const undoSnackBarKey = ValueKey('undo-snackbar');

/// Its `Undo` action.
const undoSnackBarActionKey = ValueKey('undo-snackbar-action');

/// Shows [message] with an `Undo` action that runs [undo], for [duration].
///
/// Only the latest action is undoable: the snackbar currently shown (and any
/// queued behind it) is cleared first, and the earlier action stays applied.
/// The snackbar closes by itself after [duration] even though it has an
/// action (Flutter keeps a snackbar with an action until dismissed unless
/// told otherwise). Does nothing when [context] has no `ScaffoldMessenger`;
/// returns the snackbar's controller otherwise, so the caller can tell when
/// it closed.
///
/// [undo] reports its own failure (the list's error line); the snackbar is
/// gone by the time it completes.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showUndoSnackBar(
  BuildContext context, {
  required String message,
  required Future<void> Function() undo,
  Duration duration = undoSnackBarDuration,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return null;
  messenger.clearSnackBars();
  return messenger.showSnackBar(
    SnackBar(
      key: undoSnackBarKey,
      content: Text(message),
      duration: duration,
      persist: false,
      action: SnackBarAction(
        key: undoSnackBarActionKey,
        label: 'Undo',
        onPressed: () => unawaited(undo()),
      ),
    ),
  );
}
