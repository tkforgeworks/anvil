/// The registry of open editors with unsaved changes (design §8.5, §8.8):
/// what the leave guard (ANVL-161), the exit and project-switch prompts
/// (ANVL-187) and the app-bar save status (ANVL-163) consult.
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'editor_state.dart';

/// One open editor whose draft differs from its baseline.
final class DirtyEditor {
  const DirtyEditor({
    required this.domain,
    required this.recordId,
    required this.displayName,
    required this.save,
    this.saving = false,
    this.saveError,
  });

  final SaveDomain domain;
  final String recordId;

  /// The draft's display name, as the prompts list it.
  final String displayName;

  /// Saves this editor's draft (the controller's `save`).
  final Future<SaveOutcome> Function() save;

  /// A save of this editor is in flight.
  final bool saving;

  /// The message of this editor's last failed save, if it has not been
  /// cleared by an edit since.
  final String? saveError;

  @override
  bool operator ==(Object other) =>
      other is DirtyEditor &&
      other.domain == domain &&
      other.recordId == recordId &&
      other.displayName == displayName &&
      other.save == save &&
      other.saving == saving &&
      other.saveError == saveError;

  @override
  int get hashCode =>
      Object.hash(domain, recordId, displayName, save, saving, saveError);

  @override
  String toString() =>
      'DirtyEditor(${domain.name} $recordId $displayName'
      '${saving ? ', saving' : ''}'
      '${saveError == null ? '' : ', error: $saveError'})';
}

/// The registry's state: the dirty editors in the order they first became
/// dirty (an editor that turned clean and dirty again goes to the end).
final class DirtyEditors {
  DirtyEditors(List<DirtyEditor> entries)
    : entries = List.unmodifiable(entries);

  final List<DirtyEditor> entries;

  bool get isEmpty => entries.isEmpty;
  bool get isNotEmpty => entries.isNotEmpty;
  int get length => entries.length;
}

/// The dirty editors; see [DirtyEditorsNotifier].
final dirtyEditorsProvider =
    NotifierProvider<DirtyEditorsNotifier, DirtyEditors>(
      DirtyEditorsNotifier.new,
    );

/// Holds one [DirtyEditor] per dirty editor. `RecordEditorController` keeps
/// its own entry current: [put] whenever its state is dirty, [remove] when
/// it is clean again (typed back, undone, discarded or saved) and when it is
/// disposed. `build()` watches nothing.
class DirtyEditorsNotifier extends Notifier<DirtyEditors> {
  @override
  DirtyEditors build() => DirtyEditors(const []);

  /// Adds [entry], or replaces the entry for the same domain and record id
  /// in place.
  void put(DirtyEditor entry) {
    final entries = [...state.entries];
    final index = entries.indexWhere(
      (e) => e.domain == entry.domain && e.recordId == entry.recordId,
    );
    if (index < 0) {
      entries.add(entry);
    } else if (entries[index] == entry) {
      return;
    } else {
      entries[index] = entry;
    }
    state = DirtyEditors(entries);
  }

  /// Removes the entry for [domain] and [recordId], if any. A no-op once
  /// the registry itself is disposed (the container went away before an
  /// editor's scheduled removal ran).
  void remove(SaveDomain domain, String recordId) {
    if (!ref.mounted) return;
    final entries = state.entries;
    if (!entries.any((e) => e.domain == domain && e.recordId == recordId)) {
      return;
    }
    state = DirtyEditors([
      for (final e in entries)
        if (e.domain != domain || e.recordId != recordId) e,
    ]);
  }

  /// Saves every dirty editor in order and stops at the first outcome other
  /// than [SaveOutcome.saved]; true when all of them saved. The failing
  /// editor keeps its draft and shows its own error or blockers.
  Future<bool> saveAll() async {
    for (final entry in state.entries) {
      if (await entry.save() != SaveOutcome.saved) return false;
    }
    return true;
  }
}
