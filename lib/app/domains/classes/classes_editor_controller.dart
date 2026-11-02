/// The class editor's controller (design §8.4): one [ClassDraft] per open
/// class, over `ClassRepository`.
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../editor/editor_state.dart';
import '../../editor/record_editor_controller.dart';
import '../../shell/shell_providers.dart';
import 'classes_growth_math.dart';
import 'classes_growth_providers.dart';

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
/// transaction, where 0.1.6 saved them through IPC on every change. So are
/// the stat growth grid, the growth formulas and the derived stat
/// overrides (ANVL-196), which 0.1.6's two tabs saved on their own.
///
/// The repository is read at call time ([classRepositoryProvider]), never
/// watched, so nothing rebuilds the editor and drops its draft. The same
/// goes for the max level ([classMaxLevelProvider]), which the stat growth
/// intents read when they run: a change in Project Settings reaches the
/// grid without touching the draft or its history.
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

  // ─── Stat growth ───────────────────────────────────────────────────────

  /// The max level the tabs show, or null before it has loaded.
  int? get _maxLevel => ref.read(classMaxLevelProvider).value;

  /// Sets the manual value of [statId] at [level]; null empties the cell
  /// (removes the entry), as 0.1.6 saved only non-empty cells. Typed into
  /// a cell, so coalesced per cell.
  void setStatGrowthValue(String statId, int level, double? value) {
    final key = StatGrowthKey(statId, level);
    final growth = state.value?.draft.statGrowth;
    if (growth == null || growth[key] == value) return;
    edit((d) {
      final next = {...d.statGrowth};
      if (value == null) {
        next.remove(key);
      } else {
        next[key] = value;
      }
      return d.copyWith(statGrowth: next);
    }, coalesceKey: 'statGrowth.$statId.$level');
  }

  /// Puts [statId] in formula mode with an empty formula, one undo step,
  /// as 0.1.6's `M` chip did; the empty formula blocks Save until it is
  /// typed in (ANVL-164). The stat's manual entries stay in the draft
  /// (shadowed) until the stat goes back to manual mode.
  void switchToFormula(String statId) {
    final formulas = state.value?.draft.statGrowthFormulas;
    if (formulas == null || formulas.containsKey(statId)) return;
    edit(
      (d) =>
          d.copyWith(statGrowthFormulas: {...d.statGrowthFormulas, statId: ''}),
    );
  }

  /// Sets the growth formula of [statId], a stat in formula mode. Typed
  /// into the formula field, so coalesced per stat.
  void setStatGrowthFormula(String statId, String formula) {
    final formulas = state.value?.draft.statGrowthFormulas;
    if (formulas == null || formulas[statId] == formula) return;
    edit(
      (d) => d.copyWith(
        statGrowthFormulas: {...d.statGrowthFormulas, statId: formula},
      ),
      coalesceKey: 'statGrowthFormulas.$statId',
    );
  }

  /// 0.1.6's Switch to Manual Mode dialog, one undo step: removes the
  /// formula of [statId]. With [keep] (Keep Values) the values the formula
  /// gives for levels 1 to max level replace the stat's manual entries
  /// ([bakedGrowthValues]), as 0.1.6 saved the grid it had filled in; when
  /// the formula fails at level 1 the values the grid shows ([onScreen],
  /// the preview's last values) are kept instead, and with none the manual
  /// entries stay as they are. Without [keep] (Clear Values) the stat's
  /// manual entries are removed, as 0.1.6 emptied its column.
  ///
  /// The page passes [onScreen] because the preview listens to this
  /// editor, so the editor cannot read the preview back.
  void switchToManual(
    String statId, {
    required bool keep,
    List<double>? onScreen,
  }) {
    final draft = state.value?.draft;
    final formula = draft?.statGrowthFormulas[statId];
    if (draft == null || formula == null) return;
    final maxLevel = _maxLevel;
    final baked = keep && maxLevel != null
        ? bakedGrowthValues(formula, maxLevel, onScreen: onScreen)
        : null;
    edit((d) {
      final growth = {...d.statGrowth};
      if (!keep || baked != null) {
        growth.removeWhere((key, _) => key.statId == statId);
      }
      if (baked != null) {
        for (var i = 0; i < baked.length; i++) {
          growth[StatGrowthKey(statId, i + 1)] = baked[i];
        }
      }
      return d.copyWith(
        statGrowth: growth,
        statGrowthFormulas: {...d.statGrowthFormulas}..remove(statId),
      );
    });
  }

  /// 0.1.6's `Fill column:` helper: [value] at every level from 1 to max
  /// level of [statId], one undo step. Does nothing for a stat in formula
  /// mode (0.1.6 offered only manual stats) or before the max level is
  /// known.
  void fillColumn(String statId, double value) {
    final maxLevel = _maxLevel;
    _editManualColumn(statId, {
      if (maxLevel != null)
        for (var level = 1; level <= maxLevel; level++) level: value,
    });
  }

  /// 0.1.6's `Interpolate:` helper ([interpolateLevels]): the straight line
  /// from [fromValue] at [fromLevel] to [toValue] at [toLevel] for
  /// [statId], one undo step, levels outside 1..max level skipped. Does
  /// nothing for a stat in formula mode or when `fromLevel >= toLevel`.
  void interpolate(
    String statId,
    int fromLevel,
    double fromValue,
    int toLevel,
    double toValue,
  ) {
    final maxLevel = _maxLevel;
    if (maxLevel == null) return;
    _editManualColumn(
      statId,
      interpolateLevels(
        fromLevel: fromLevel,
        fromValue: fromValue,
        toLevel: toLevel,
        toValue: toValue,
        maxLevel: maxLevel,
      ),
    );
  }

  /// The `Formula fill:` helper (ANVL-140): writes [values] (level →
  /// value, computed by the page with `computeFormulaFill`) into the
  /// manual entries of [statId], one undo step. Does nothing for a stat in
  /// formula mode or when [values] is empty.
  void formulaFill(String statId, Map<int, double> values) =>
      _editManualColumn(statId, values);

  void _editManualColumn(String statId, Map<int, double> values) {
    final draft = state.value?.draft;
    if (draft == null ||
        values.isEmpty ||
        draft.statGrowthFormulas.containsKey(statId)) {
      return;
    }
    edit(
      (d) => d.copyWith(
        statGrowth: {
          ...d.statGrowth,
          for (final MapEntry(key: level, value: v) in values.entries)
            StatGrowthKey(statId, level): v,
        },
      ),
    );
  }

  // ─── Derived stat overrides ────────────────────────────────────────────

  /// Sets the class override of derived stat [derivedId]; null removes it
  /// (the project formula applies again). An empty formula is kept and
  /// blocks Save with the engine's `Formula is empty`, as 0.1.6 refused to
  /// save an enabled override with a syntax error, so clearing the field
  /// while typing does not switch the override off under the cursor.
  ///
  /// [typing] (the formula field) coalesces per definition; the override
  /// switch passes false so turning it on or off is one undo step.
  void setDerivedOverride(
    String derivedId,
    String? formula, {
    bool typing = true,
  }) {
    final overrides = state.value?.draft.derivedStatOverrides;
    if (overrides == null || overrides[derivedId] == formula) return;
    if (formula == null && !overrides.containsKey(derivedId)) return;
    edit((d) {
      final next = {...d.derivedStatOverrides};
      if (formula == null) {
        next.remove(derivedId);
      } else {
        next[derivedId] = formula;
      }
      return d.copyWith(derivedStatOverrides: next);
    }, coalesceKey: typing ? 'derivedStatOverrides.$derivedId' : null);
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
