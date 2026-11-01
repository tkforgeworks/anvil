import 'package:anvil_core/anvil_core.dart';
import 'package:test/test.dart';

import 'support/draft_laws.dart';

AbilityDraft _build({bool otherOrder = false}) {
  final modifiers = [('stat-strength', 2.0), ('stat-wisdom', -1.5)];
  return AbilityDraft(
    displayName: 'Slash',
    exportKey: 'slash',
    description: 'A cut',
    abilityType: 'active',
    resourceType: 'stamina',
    resourceCost: 10,
    cooldown: 2.5,
    statModifiers: {
      for (final (k, v) in otherOrder ? modifiers.reversed : modifiers) k: v,
    },
  );
}

void main() {
  draftLaws<AbilityDraft>(
    build: _build,
    buildInOtherOrder: () => _build(otherOrder: true),
    copyWithNoArgs: (d) => d.copyWith(),
    changes: {
      'displayName': (d) => d.copyWith(displayName: 'Cleave'),
      'exportKey': (d) => d.copyWith(exportKey: 'cleave'),
      'description': (d) => d.copyWith(description: ''),
      'abilityType': (d) => d.copyWith(abilityType: 'passive'),
      'resourceType': (d) => d.copyWith(resourceType: 'mana'),
      'resourceCost': (d) => d.copyWith(resourceCost: 11),
      'cooldown': (d) => d.copyWith(cooldown: 3),
      'statModifiers value': (d) =>
          d.copyWith(statModifiers: {...d.statModifiers, 'stat-strength': 3}),
      'statModifiers key removed': (d) =>
          d.copyWith(statModifiers: {'stat-strength': 2}),
    },
    reorders: const {},
    mutations: {'statModifiers': (d) => d.statModifiers['stat-x'] = 1},
  );

  test('defaults match 0.1.6 create defaults', () {
    final input = CreateAbilityInput(displayName: 'S', exportKey: 's');
    final draft = AbilityDraft(displayName: 'S', exportKey: 's');
    for (final (description, type, resource, cost, cooldown, mods) in [
      (
        input.description,
        input.abilityType,
        input.resourceType,
        input.resourceCost,
        input.cooldown,
        input.statModifiers,
      ),
      (
        draft.description,
        draft.abilityType,
        draft.resourceType,
        draft.resourceCost,
        draft.cooldown,
        draft.statModifiers,
      ),
    ]) {
      expect(description, '');
      expect(type, '');
      expect(resource, '');
      expect(cost, 0);
      expect(cooldown, 0);
      expect(mods, isEmpty);
    }
  });
}
