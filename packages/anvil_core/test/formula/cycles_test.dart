import 'package:anvil_core/anvil_core.dart';
import 'package:test/test.dart';

DerivedStatFormula _stat(String id, String name, String key, String formula) =>
    DerivedStatFormula(
      id: id,
      displayName: name,
      exportKey: key,
      formula: formula,
    );

void main() {
  final attack = _stat('ds-a', 'Attack', 'attack', 'strength * 2');
  final defense = _stat('ds-d', 'Defense', 'defense', 'constitution + attack');
  final speed = _stat('ds-s', 'Speed', 'speed', 'agility / 2 + defense');

  test('no cycle', () {
    expect(findDerivedStatCycle([attack, defense, speed]), isNull);
  });

  test('a self-reference is a cycle of one', () {
    final cycle = findDerivedStatCycle([
      attack,
      _stat('ds-h', 'Health', 'health', 'health + 1'),
    ])!;
    expect(cycle.ids, ['ds-h']);
    expect(
      cycle.message,
      'Derived stat is part of a dependency cycle: Health → Health.',
    );
  });

  test('a three-stat cycle, in Electron findCycle order', () {
    // A → B → C → A, defined in that order: the DFS from A meets the
    // back-edge C → A and rebuilds [A, C, B], reversed to [B, C, A].
    final cycle = findDerivedStatCycle([
      _stat('a', 'Alpha', 'alpha', 'beta + 1'),
      _stat('b', 'Beta', 'beta', 'gamma * 2'),
      _stat('c', 'Gamma', 'gamma', 'max(1, alpha)'),
    ])!;
    expect(cycle.ids, ['b', 'c', 'a']);
    expect(cycle.names, ['Beta', 'Gamma', 'Alpha']);
    expect(
      cycle.message,
      'Derived stat is part of a dependency cycle: '
      'Beta → Gamma → Alpha → Beta.',
    );
  });

  test('edges follow export keys, not ids or display names', () {
    expect(
      findDerivedStatCycle([
        _stat('a', 'Alpha', 'alpha', 'b + Beta'),
        _stat('b', 'Beta', 'beta', 'a + Alpha'),
      ]),
      isNull,
    );
  });

  test('a cycle introduced only by a class override', () {
    final stats = [attack, defense, speed];
    expect(findDerivedStatCycle(stats), isNull);
    final cycle = findDerivedStatCycle(
      stats,
      overrides: {'ds-a': 'strength + speed'},
    )!;
    expect(cycle.ids.toSet(), {'ds-a', 'ds-d', 'ds-s'});
    expect(
      cycle.overrideMessage,
      startsWith('Override formulas create a dependency cycle: '),
    );
    expect(cycle.isSameCycleAs(findDerivedStatCycle(stats)), isFalse);
  });

  test('a cycle broken by a class override', () {
    final looped = [
      _stat('a', 'Alpha', 'alpha', 'beta + 1'),
      _stat('b', 'Beta', 'beta', 'alpha + 1'),
    ];
    final base = findDerivedStatCycle(looped)!;
    expect(base.names, ['Beta', 'Alpha']);
    expect(findDerivedStatCycle(looped, overrides: {'b': 'level * 3'}), isNull);
    // An override that keeps the same cycle is not a per-class cycle.
    final same = findDerivedStatCycle(looped, overrides: {'b': 'alpha * 2'})!;
    expect(same.isSameCycleAs(base), isTrue);
  });

  test('a formula with a syntax error is left out of the graph', () {
    expect(
      findDerivedStatCycle([
        _stat('a', 'Alpha', 'alpha', 'beta + 1'),
        _stat('b', 'Beta', 'beta', 'alpha +'),
      ]),
      isNull,
    );
  });
}
