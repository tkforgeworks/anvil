/// The ability editor's controller (design §8.4): one [AbilityDraft] per
/// open ability, over `AbilityRepository`.
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../editor/editor_state.dart';
import '../../editor/record_editor_controller.dart';
import '../../shell/shell_providers.dart';

/// The editor of one ability, keyed by its id.
final abilitiesEditorProvider = AsyncNotifierProvider.autoDispose
    .family<AbilityEditorController, EditorState<AbilityDraft>, String>(
      AbilityEditorController.new,
    );

/// Edits one ability's draft. Every intent method is one [edit]; the text
/// fields (the numeric ones included, since they are typed) coalesce by
/// field name, so a burst of typing is one undo step.
///
/// The repository is read at call time ([abilityRepositoryProvider]),
/// never watched, so nothing rebuilds the editor and drops its draft.
class AbilityEditorController extends RecordEditorController<AbilityDraft> {
  AbilityEditorController(super.recordId);

  AbilityRepository get _repository => ref.read(abilityRepositoryProvider);

  @override
  SaveDomain get domain => SaveDomain.abilities;

  @override
  @protected
  Future<AbilityDraft> loadDraft() => _repository.load(recordId);

  /// Saves the draft with its text fields trimmed, as 0.1.6's
  /// `handleSave` did (`displayName.trim()` and the rest); the read-back,
  /// trimmed, becomes the baseline and the draft the editor shows.
  @override
  @protected
  Future<AbilityDraft> saveDraft(AbilityDraft draft) =>
      _repository.save(recordId, trimAbilityDraft(draft));

  @override
  @protected
  List<SaveBlocker> blockersFor(AbilityDraft draft) =>
      abilitySaveBlockers(draft);

  @override
  @protected
  String displayNameOf(AbilityDraft draft) => draft.displayName;

  void setDisplayName(String value) =>
      edit((d) => d.copyWith(displayName: value), coalesceKey: 'displayName');

  void setExportKey(String value) =>
      edit((d) => d.copyWith(exportKey: value), coalesceKey: 'exportKey');

  void setDescription(String value) =>
      edit((d) => d.copyWith(description: value), coalesceKey: 'description');

  void setAbilityType(String value) =>
      edit((d) => d.copyWith(abilityType: value), coalesceKey: 'abilityType');

  void setResourceType(String value) =>
      edit((d) => d.copyWith(resourceType: value), coalesceKey: 'resourceType');

  void setResourceCost(double value) =>
      edit((d) => d.copyWith(resourceCost: value), coalesceKey: 'resourceCost');

  void setCooldown(double value) =>
      edit((d) => d.copyWith(cooldown: value), coalesceKey: 'cooldown');

  /// Copies the saved ability (not the unsaved draft) as `<name> (Copy)`
  /// and returns the copy for the page to open. A write path, so it bumps
  /// the write epoch once after the repository returns.
  Future<AbilityRecord> duplicate() async {
    final epoch = ref.read(writeEpochProvider.notifier);
    final copy = await _repository.duplicate(recordId);
    epoch.bump();
    return copy;
  }

  /// Sets the modifier of stat [statId]; null or zero removes it from the
  /// map, as 0.1.6 saved only non-zero modifiers (`Zero values are not
  /// exported.`).
  void setStatModifier(String statId, double? value) => edit((d) {
    final next = {...d.statModifiers};
    if (value == null || value == 0) {
      next.remove(statId);
    } else {
      next[statId] = value;
    }
    return d.copyWith(statModifiers: next);
  }, coalesceKey: 'statModifiers.$statId');
}

/// [draft] with the five text fields trimmed.
AbilityDraft trimAbilityDraft(AbilityDraft draft) => draft.copyWith(
  displayName: draft.displayName.trim(),
  exportKey: draft.exportKey.trim(),
  description: draft.description.trim(),
  abilityType: draft.abilityType.trim(),
  resourceType: draft.resourceType.trim(),
);
