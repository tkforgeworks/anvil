import '../formula/formula_engine.dart' show validateFormula;
import 'class_types.dart';
import 'save_blocker.dart';

/// 0.1.6's metadata key rule (`DerivedStatsEditor.tsx`).
final RegExp _metadataKeyPattern = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');

/// The helper text 0.1.6 showed under an invalid metadata key.
const String _invalidMetadataKey =
    'Letters, digits, underscores only. Must start with a letter.';

/// The rules that keep a class draft from saving (design §8.6), in field
/// order: identity, ability assignments, stat growth, stat growth formulas,
/// derived stat overrides, metadata fields. Empty when the draft can be saved.
///
/// Broken references (an assigned ability or a stat that no longer exists)
/// are not blockers; they are validation issues. So are a stat growth
/// formula's unknown variables and its runtime errors, which depend on the
/// project's stats and max level rather than on the draft alone.
List<SaveBlocker> classSaveBlockers(ClassDraft draft) {
  final blockers = <SaveBlocker>[];
  if (draft.displayName.trim().isEmpty) {
    blockers.add(const SaveBlocker('displayName', 'Display name is required.'));
  }
  if (draft.exportKey.trim().isEmpty) {
    blockers.add(const SaveBlocker('exportKey', 'Export key is required.'));
  }

  // class_ability_assignments PRIMARY KEY (class_id, ability_id).
  final assigned = <String>{};
  for (var i = 0; i < draft.abilityIds.length; i++) {
    if (!assigned.add(draft.abilityIds[i])) {
      blockers.add(
        SaveBlocker(
          'abilityIds[$i]',
          'This ability is already assigned to the class.',
        ),
      );
    }
  }

  // class_stat_growth CHECK (level > 0).
  if (draft.statGrowth.keys.any((key) => key.level < 1)) {
    blockers.add(
      const SaveBlocker('statGrowth', 'Stat growth levels must be at least 1.'),
    );
  }

  // A stat is in formula mode while it has an entry here, and 0.1.6 let the
  // formula sit empty (switching a stat to formula mode starts with ''),
  // showing 'Formula is empty' but saving it anyway. 0.2.0 refuses both an
  // empty formula and a syntax error.
  for (final growth in draft.statGrowthFormulas.entries) {
    final field = 'statGrowthFormulas.${growth.key}';
    if (growth.value.trim().isEmpty) {
      blockers.add(SaveBlocker(field, 'Stat growth formula is required.'));
      continue;
    }
    final error = validateFormula(growth.value);
    if (error != null) blockers.add(SaveBlocker(field, error));
  }

  // 0.1.6 refused to save while an enabled override had a syntax error, and
  // showed the engine's message under the formula.
  for (final override in draft.derivedStatOverrides.entries) {
    final error = validateFormula(override.value);
    if (error != null) {
      blockers.add(SaveBlocker('derivedStatOverrides.${override.key}', error));
    }
  }

  // class_metadata_fields PRIMARY KEY (class_id, field_key).
  final keys = <String>{};
  for (var i = 0; i < draft.metadataFields.length; i++) {
    final key = draft.metadataFields[i].fieldKey;
    final field = 'metadataFields[$i].fieldKey';
    if (key.isEmpty) {
      blockers.add(SaveBlocker(field, 'Metadata field key is required.'));
    } else if (!_metadataKeyPattern.hasMatch(key)) {
      blockers.add(SaveBlocker(field, _invalidMetadataKey));
    } else if (!keys.add(key)) {
      blockers.add(
        SaveBlocker(field, 'Metadata field key "$key" is used more than once.'),
      );
    }
  }
  return blockers;
}
