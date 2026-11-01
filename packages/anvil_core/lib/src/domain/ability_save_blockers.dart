import 'ability_types.dart';
import 'save_blocker.dart';

/// The rules that keep an ability draft from saving (design §8.6): an empty
/// display name or export key. Empty when the draft can be saved.
///
/// 0.1.6's ability editor had no save-blocking rule of its own; stat
/// modifiers are free numbers keyed by stat, so they block nothing.
List<SaveBlocker> abilitySaveBlockers(AbilityDraft draft) => [
  if (draft.displayName.trim().isEmpty)
    const SaveBlocker('displayName', 'Display name is required.'),
  if (draft.exportKey.trim().isEmpty)
    const SaveBlocker('exportKey', 'Export key is required.'),
];
