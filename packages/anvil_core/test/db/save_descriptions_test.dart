import 'package:anvil_core/anvil_core.dart';
import 'package:test/test.dart';

void main() {
  test('record descriptions use the 0.1.6 vocabulary', () {
    expect(
      recordChanged(SaveDomain.abilities, 'Fireball'),
      'Fireball - Ability changed',
    );
    expect(
      recordCreated(SaveDomain.classes, 'Warrior'),
      'Warrior - Class created',
    );
    expect(
      recordDeleted(SaveDomain.items, 'Iron Sword'),
      'Iron Sword - Item deleted',
    );
    expect(
      recordRestored(SaveDomain.recipes, 'Bread'),
      'Bread - Recipe restored',
    );
    expect(
      recordDuplicated(SaveDomain.npcs, 'Guard'),
      'Guard - NPC duplicated',
    );
    expect(
      recordHardDeleted(SaveDomain.lootTables, 'Boss Drops'),
      'Boss Drops - Loot Table permanently deleted',
    );
  });

  test('an empty name leaves just the domain', () {
    expect(recordCreated(SaveDomain.items, ''), 'Item created');
  });

  test('bulk descriptions use the plural labels', () {
    expect(
      bulkChanged(SaveDomain.items, 3, SaveAction.deleted),
      '3 items deleted',
    );
    expect(
      bulkChanged(SaveDomain.npcs, 2, SaveAction.restored),
      '2 NPCs restored',
    );
    expect(
      bulkChanged(SaveDomain.lootTables, 4, SaveAction.hardDeleted),
      '4 loot tables permanently deleted',
    );
    expect(
      bulkChanged(SaveDomain.abilities, 5, SaveAction.changed),
      '5 abilities changed',
    );
  });

  test('fixed strings', () {
    expect(projectSettingsChanged, 'Project settings changed');
    expect(customFieldDefinitionsChanged, 'Custom field definitions changed');
    expect(templateChanged('Quest Export'), 'Quest Export - Template changed');
  });
}
