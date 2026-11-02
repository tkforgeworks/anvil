/// The NPC editor's draft controller (design §8.4; 0.1.6
/// `NpcEditorPage.tsx`, `ClassAssignmentPanel.tsx`, `NpcStatBlockPanel.tsx`,
/// `AbilityAssignmentPanel.tsx`, `LootTableAssignmentPanel.tsx` and
/// `CustomFieldsPanel.tsx`).
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../editor/custom_field_scoping.dart';
import '../../editor/editor_state.dart';
import '../../editor/record_editor_controller.dart';
import '../../shell/shell_providers.dart';
import 'npcs_providers.dart';

/// One NPC draft per open NPC editor, keyed by NPC id.
final npcEditorProvider = AsyncNotifierProvider.autoDispose
    .family<NpcEditorController, EditorState<NpcDraft>, String>(
      NpcEditorController.new,
    );

/// The NPC editor: identity, type, description, loot table, class
/// assignments, combat stat overrides, ability assignments and the type's
/// custom field values in one draft, saved in one transaction. 0.1.6 saved
/// the class and ability assignments and the custom fields on their own,
/// at once; here they are draft fields, undone and saved with the rest.
///
/// The repositories are read at call time, never watched in `build()`.
/// Typing coalesces per field (the text fields, each class level, each
/// stat override); every structural intent is one undo step.
class NpcEditorController extends RecordEditorController<NpcDraft> {
  NpcEditorController(super.recordId);

  NpcRepository get _npcs => ref.read(npcRepositoryProvider);

  CustomFieldRepository get _customFields =>
      ref.read(customFieldRepositoryProvider);

  Future<List<CustomFieldDefinition>> _definitionsFor(String typeId) =>
      _customFields.listDefinitions(CustomFieldScope.npcType, typeId);

  /// The upper clamp of a class level: the project's max level, kept
  /// current by a listen on [npcMaxLevelProvider] (a listen, not a watch,
  /// so a settings change never reloads the draft).
  int _maxLevel = defaultNpcMaxLevel;

  /// The max level [setClassLevel] clamps to.
  int get maxLevel => _maxLevel;

  @override
  SaveDomain get domain => SaveDomain.npcs;

  /// The stored NPC with the defaults of its type's fields filled in where
  /// it has no value, as the item editor does. The baseline carries the
  /// defaults, so they are written with the next save and the freshly
  /// opened editor is clean.
  @override
  Future<NpcDraft> loadDraft() async {
    ref.listen(npcMaxLevelProvider, (_, next) {
      if (next.value case final level?) _maxLevel = level;
    });
    final draft = await _npcs.load(recordId);
    try {
      _maxLevel = await ref.read(npcMaxLevelProvider.future);
    } catch (_) {
      // 0.1.6's default stays the clamp.
    }
    if (draft.npcTypeId.isEmpty) return draft;
    final definitions = await _definitionsFor(draft.npcTypeId);
    return draft.copyWith(
      customFieldValues: scopeCustomFieldValues(
        draft.customFieldValues,
        definitions,
        keepOthers: true,
      ),
    );
  }

  /// Trims the name, key and description as 0.1.6's `handleSave` did.
  @override
  Future<NpcDraft> saveDraft(NpcDraft draft) => _npcs.save(
    recordId,
    draft.copyWith(
      displayName: draft.displayName.trim(),
      exportKey: draft.exportKey.trim(),
      description: draft.description.trim(),
    ),
  );

  @override
  List<SaveBlocker> blockersFor(NpcDraft draft) => npcSaveBlockers(draft);

  @override
  String displayNameOf(NpcDraft draft) => draft.displayName;

  /// Copies the stored NPC; a write path, so it bumps the epoch once.
  Future<NpcRecord> duplicate() async {
    final epoch = ref.read(writeEpochProvider.notifier);
    final copy = await _npcs.duplicate(recordId);
    epoch.bump();
    return copy;
  }

  void setDisplayName(String value) =>
      edit((d) => d.copyWith(displayName: value), coalesceKey: 'displayName');

  void setExportKey(String value) =>
      edit((d) => d.copyWith(exportKey: value), coalesceKey: 'exportKey');

  void setDescription(String value) =>
      edit((d) => d.copyWith(description: value), coalesceKey: 'description');

  /// Null clears it.
  void setLootTable(String? lootTableId) =>
      edit((d) => d.copyWith(lootTableId: lootTableId));

  /// Moves the NPC to type [typeId] as one undo step, re-scoping the
  /// custom field values as the item editor's `setCategory` does: values
  /// of fields the new type defines are kept, the others dropped, and the
  /// new type's defaults fill the fields that have no value. The
  /// repository drops the same values again on save, as 0.1.6's `update`
  /// did. 0.1.6 asked to confirm the change; here it is undoable.
  Future<void> setNpcType(String typeId) async {
    final current = state.value;
    if (current == null || current.draft.npcTypeId == typeId) return;
    var definitions = const <CustomFieldDefinition>[];
    try {
      definitions = await _definitionsFor(typeId);
    } catch (_) {
      // Without the definitions no value can be shown as kept; the change
      // still applies and drops them all, as the save would.
    }
    if (!ref.mounted) return;
    edit(
      (d) => d.copyWith(
        npcTypeId: typeId,
        customFieldValues: scopeCustomFieldValues(
          d.customFieldValues,
          definitions,
          keepOthers: false,
        ),
      ),
    );
  }

  /// Sets custom field [definitionId] to [value]; an empty text is stored
  /// as null, as 0.1.6 saved `value || null`. Pass [typing] for a text
  /// field, so a burst of keystrokes is one undo step.
  void setCustomFieldValue(
    String definitionId,
    String? value, {
    bool typing = false,
  }) {
    final stored = value == null || value.isEmpty ? null : value;
    // An emptied field the stored NPC had no row for is left without one,
    // so clearing what was typed returns to the baseline.
    final hadRow =
        state.value?.baseline.customFieldValues.containsKey(definitionId) ??
        false;
    edit((d) {
      final values = {...d.customFieldValues};
      if (stored == null && !hadRow) {
        values.remove(definitionId);
      } else {
        values[definitionId] = stored;
      }
      return d.copyWith(customFieldValues: values);
    }, coalesceKey: typing ? 'custom:$definitionId' : null);
  }

  /// Appends class [classId] at level 1, as 0.1.6's `handleAdd` did; a
  /// class already assigned is not added again (0.1.6's picker left it
  /// out).
  void addClassAssignment(String classId) {
    final draft = state.value?.draft;
    if (draft == null ||
        draft.classAssignments.any((a) => a.classId == classId)) {
      return;
    }
    edit(
      (d) => d.copyWith(
        classAssignments: [
          ...d.classAssignments,
          NpcClassAssignment(classId: classId, level: 1),
        ],
      ),
    );
  }

  void removeClassAssignment(int index) =>
      _editAssignments(index, (rows) => rows..removeAt(index));

  /// Sets the level of assignment [index], clamped to 1..[maxLevel] as
  /// 0.1.6's `handleLevelChange` did (`Math.max(1, Math.min(maxLevel,
  /// level))`); typed into a field, so coalesced per row.
  void setClassLevel(int index, int level) {
    final clamped = level < 1 ? 1 : (level > _maxLevel ? _maxLevel : level);
    _editAssignments(
      index,
      (rows) => rows..[index] = rows[index].copyWith(level: clamped),
      coalesceKey: 'classAssignments[$index].level',
    );
  }

  /// Moves assignment [from] to [to], one undo step; out-of-range or equal
  /// indexes do nothing. 0.1.6's panel had the same up / down buttons.
  void moveClassAssignment(int from, int to) {
    final count = state.value?.draft.classAssignments.length ?? 0;
    if (!_validMove(from, to, count)) return;
    edit((d) {
      final rows = [...d.classAssignments];
      rows.insert(to, rows.removeAt(from));
      return d.copyWith(classAssignments: rows);
    });
  }

  /// Appends ability [abilityId]; one already assigned is not added again.
  void addAbility(String abilityId) {
    final draft = state.value?.draft;
    if (draft == null || draft.abilityIds.contains(abilityId)) return;
    edit((d) => d.copyWith(abilityIds: [...d.abilityIds, abilityId]));
  }

  void removeAbility(int index) {
    final count = state.value?.draft.abilityIds.length ?? 0;
    if (index < 0 || index >= count) return;
    edit((d) => d.copyWith(abilityIds: [...d.abilityIds]..removeAt(index)));
  }

  /// Moves ability [from] to [to], one undo step.
  void moveAbility(int from, int to) {
    final count = state.value?.draft.abilityIds.length ?? 0;
    if (!_validMove(from, to, count)) return;
    edit((d) {
      final ids = [...d.abilityIds];
      ids.insert(to, ids.removeAt(from));
      return d.copyWith(abilityIds: ids);
    });
  }

  /// Sets the combat stat override of [statId]; typed into a field, so
  /// coalesced per stat. Null clears the override by removing the key, as
  /// 0.1.6's `handleOverrideChange` deleted it, unless the stored NPC had
  /// the key mapped to null, which is then restored so clearing returns
  /// to the baseline.
  void setStatOverride(String statId, double? value) =>
      _setOverride(statId, value, coalesceKey: 'combatStats.$statId');

  /// 0.1.6's `Revert to inherited`: clears the override as its own undo
  /// step.
  void revertStatOverride(String statId) => _setOverride(statId, null);

  void _setOverride(String statId, double? value, {String? coalesceKey}) {
    final baseline = state.value?.baseline.combatStats;
    final storedNull =
        baseline != null &&
        baseline.containsKey(statId) &&
        baseline[statId] == null;
    edit((d) {
      final next = {...d.combatStats};
      if (value != null) {
        next[statId] = value;
      } else if (storedNull) {
        next[statId] = null;
      } else {
        next.remove(statId);
      }
      return d.copyWith(combatStats: next);
    }, coalesceKey: coalesceKey);
  }

  static bool _validMove(int from, int to, int count) =>
      from != to && from >= 0 && to >= 0 && from < count && to < count;

  void _editAssignments(
    int index,
    List<NpcClassAssignment> Function(List<NpcClassAssignment> rows) change, {
    String? coalesceKey,
  }) {
    final count = state.value?.draft.classAssignments.length ?? 0;
    if (index < 0 || index >= count) return;
    edit(
      (d) => d.copyWith(classAssignments: change([...d.classAssignments])),
      coalesceKey: coalesceKey,
    );
  }
}
