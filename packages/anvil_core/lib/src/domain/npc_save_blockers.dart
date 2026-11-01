import 'npc_types.dart';
import 'save_blocker.dart';

/// The rules that refuse an NPC save (design §8.6): an empty display name
/// or export key (after trimming), an empty NPC type (a `NOT NULL` foreign
/// key in `npcs`), a class assignment level below 1 (`CHECK (level > 0)`),
/// a class assigned twice and an ability assigned twice (the primary keys
/// of `npc_class_assignments` and `npc_ability_assignments`).
///
/// Assignment rules carry the paths `classAssignments[i].level`,
/// `classAssignments[i].classId` and `abilityIds[i]`; a duplicate is
/// reported on the second and later occurrences. 0.1.6's editor disabled
/// Save on none of these: its pickers left out assigned classes and
/// abilities and it clamped levels to 1..max level. A level above the
/// project's max level, a class, ability, type or loot table id that no
/// longer exists are not blockers.
List<SaveBlocker> npcSaveBlockers(NpcDraft draft) {
  final blockers = <SaveBlocker>[
    if (draft.displayName.trim().isEmpty)
      const SaveBlocker('displayName', 'Display name is required.'),
    if (draft.exportKey.trim().isEmpty)
      const SaveBlocker('exportKey', 'Export key is required.'),
    if (draft.npcTypeId.isEmpty)
      const SaveBlocker('npcTypeId', 'NPC type is required.'),
  ];
  final classIds = <String>{};
  for (final (i, assignment) in draft.classAssignments.indexed) {
    if (assignment.level < 1) {
      blockers.add(
        SaveBlocker(
          'classAssignments[$i].level',
          'Class assignment ${i + 1}: level must be at least 1.',
        ),
      );
    }
    if (!classIds.add(assignment.classId)) {
      blockers.add(
        SaveBlocker(
          'classAssignments[$i].classId',
          'This class is already assigned to the NPC.',
        ),
      );
    }
  }
  final abilityIds = <String>{};
  for (final (i, abilityId) in draft.abilityIds.indexed) {
    if (!abilityIds.add(abilityId)) {
      blockers.add(
        SaveBlocker(
          'abilityIds[$i]',
          'This ability is already assigned to the NPC.',
        ),
      );
    }
  }
  return blockers;
}
