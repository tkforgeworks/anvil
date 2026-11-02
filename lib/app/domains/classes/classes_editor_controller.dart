/// The class editor's controller (design §8.4): one [ClassDraft] per open
/// class, over `ClassRepository`.
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../editor/editor_state.dart';
import '../../editor/record_editor_controller.dart';
import '../../shell/shell_providers.dart';

/// The editor of one class, keyed by its id.
final classEditorProvider = AsyncNotifierProvider.autoDispose
    .family<ClassEditorController, EditorState<ClassDraft>, String>(
      ClassEditorController.new,
    );

/// Edits one class's draft. Every intent method is one [edit]: the text
/// and number fields coalesce by field (each metadata row's key and value
/// by row), every structural intent (adding, removing or moving a
/// metadata row or an ability) is one undo step.
///
/// The ability assignments are draft state saved with the class in one
/// transaction, where 0.1.6 saved them through IPC on every change.
/// `statGrowth`, `statGrowthFormulas` and `derivedStatOverrides` are
/// carried through untouched until ANVL-196 edits them.
///
/// The repository is read at call time ([classRepositoryProvider]), never
/// watched, so nothing rebuilds the editor and drops its draft.
class ClassEditorController extends RecordEditorController<ClassDraft> {
  ClassEditorController(super.recordId);

  ClassRepository get _repository => ref.read(classRepositoryProvider);

  @override
  SaveDomain get domain => SaveDomain.classes;

  @override
  @protected
  Future<ClassDraft> loadDraft() => _repository.load(recordId);

  /// Saves the draft with its name, key and description trimmed, as
  /// 0.1.6's `handleSave` did; the read-back becomes the baseline and the
  /// draft the editor shows (metadata rows come back ordered by key).
  @override
  @protected
  Future<ClassDraft> saveDraft(ClassDraft draft) =>
      _repository.save(recordId, trimClassDraft(draft));

  @override
  @protected
  List<SaveBlocker> blockersFor(ClassDraft draft) => classSaveBlockers(draft);

  @override
  @protected
  String displayNameOf(ClassDraft draft) => draft.displayName;

  void setDisplayName(String value) =>
      edit((d) => d.copyWith(displayName: value), coalesceKey: 'displayName');

  void setExportKey(String value) =>
      edit((d) => d.copyWith(exportKey: value), coalesceKey: 'exportKey');

  void setDescription(String value) =>
      edit((d) => d.copyWith(description: value), coalesceKey: 'description');

  void setResourceMultiplier(double value) => edit(
    (d) => d.copyWith(resourceMultiplier: value),
    coalesceKey: 'resourceMultiplier',
  );

  /// Appends a metadata row with an empty key and 0, as 0.1.6's `Add
  /// Field` did; the empty key blocks Save until it is filled in.
  void addMetadataField() => edit(
    (d) => d.copyWith(
      metadataFields: [
        ...d.metadataFields,
        const ClassMetadataField(fieldKey: '', value: 0),
      ],
    ),
  );

  void removeMetadataField(int index) =>
      _editMetadata(index, (rows) => rows..removeAt(index));

  /// Typed into a field, so coalesced per row.
  void setMetadataKey(int index, String key) => _editMetadata(
    index,
    (rows) => rows..[index] = rows[index].copyWith(fieldKey: key),
    coalesceKey: 'metadataFields[$index].fieldKey',
  );

  /// Typed into a field, so coalesced per row.
  void setMetadataValue(int index, double value) => _editMetadata(
    index,
    (rows) => rows..[index] = rows[index].copyWith(value: value),
    coalesceKey: 'metadataFields[$index].value',
  );

  /// Appends ability [abilityId]; one already assigned changes nothing.
  void addAbility(String abilityId) {
    final ids = state.value?.draft.abilityIds ?? const <String>[];
    if (ids.contains(abilityId)) return;
    edit((d) => d.copyWith(abilityIds: [...d.abilityIds, abilityId]));
  }

  /// Removes ability [abilityId]; one not assigned changes nothing.
  void removeAbility(String abilityId) {
    final ids = state.value?.draft.abilityIds ?? const <String>[];
    if (!ids.contains(abilityId)) return;
    edit(
      (d) => d.copyWith(
        abilityIds: [
          for (final id in d.abilityIds)
            if (id != abilityId) id,
        ],
      ),
    );
  }

  /// Moves the assignment at [from] to [to] (both indexes in the current
  /// list), one undo step; out-of-range or equal indexes do nothing.
  void moveAbility(int from, int to) {
    final count = state.value?.draft.abilityIds.length ?? 0;
    if (from == to || from < 0 || to < 0 || from >= count || to >= count) {
      return;
    }
    edit((d) {
      final ids = [...d.abilityIds];
      ids.insert(to, ids.removeAt(from));
      return d.copyWith(abilityIds: ids);
    });
  }

  /// Copies the saved class (not the unsaved draft) as `<name> (Copy)` and
  /// returns the copy for the page to open. A write path, so it bumps the
  /// write epoch once after the repository returns.
  Future<ClassRecord> duplicate() async {
    final epoch = ref.read(writeEpochProvider.notifier);
    final copy = await _repository.duplicate(recordId);
    epoch.bump();
    return copy;
  }

  void _editMetadata(
    int index,
    List<ClassMetadataField> Function(List<ClassMetadataField> rows) change, {
    String? coalesceKey,
  }) {
    final count = state.value?.draft.metadataFields.length ?? 0;
    if (index < 0 || index >= count) return;
    edit(
      (d) => d.copyWith(metadataFields: change([...d.metadataFields])),
      coalesceKey: coalesceKey,
    );
  }
}

/// [draft] with the name, export key and description trimmed.
ClassDraft trimClassDraft(ClassDraft draft) => draft.copyWith(
  displayName: draft.displayName.trim(),
  exportKey: draft.exportKey.trim(),
  description: draft.description.trim(),
);
