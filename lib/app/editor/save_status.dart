/// The aggregate save status the app bar shows (design §8.5; the widget is
/// ANVL-163).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dirty_editors.dart';

/// All saved, the number of records with unsaved changes, a save in
/// flight, or the last save failure with its message.
sealed class SaveStatus {
  const SaveStatus();
}

/// No open editor has unsaved changes.
final class AllSaved extends SaveStatus {
  const AllSaved();

  @override
  bool operator ==(Object other) => other is AllSaved;

  @override
  int get hashCode => (AllSaved).hashCode;

  @override
  String toString() => 'AllSaved';
}

/// [count] open editors have unsaved changes and none is saving or failed.
final class Unsaved extends SaveStatus {
  const Unsaved(this.count);

  final int count;

  @override
  bool operator ==(Object other) => other is Unsaved && other.count == count;

  @override
  int get hashCode => Object.hash(Unsaved, count);

  @override
  String toString() => 'Unsaved($count)';
}

/// At least one editor is saving.
final class Saving extends SaveStatus {
  const Saving();

  @override
  bool operator ==(Object other) => other is Saving;

  @override
  int get hashCode => (Saving).hashCode;

  @override
  String toString() => 'Saving';
}

/// An editor's last save failed with [message] and it is still dirty.
final class SaveError extends SaveStatus {
  const SaveError(this.message);

  final String message;

  @override
  bool operator ==(Object other) =>
      other is SaveError && other.message == message;

  @override
  int get hashCode => Object.hash(SaveError, message);

  @override
  String toString() => 'SaveError($message)';
}

/// Derived from [dirtyEditorsProvider] alone, so it needs no knowledge of
/// the editor families. A save in flight wins over a failure, and a failure
/// over the unsaved count; with several failures the first registered
/// editor's message is shown.
final saveStatusProvider = Provider<SaveStatus>((ref) {
  final entries = ref.watch(dirtyEditorsProvider).entries;
  if (entries.isEmpty) return const AllSaved();
  if (entries.any((e) => e.saving)) return const Saving();
  for (final e in entries) {
    if (e.saveError case final message?) return SaveError(message);
  }
  return Unsaved(entries.length);
});
