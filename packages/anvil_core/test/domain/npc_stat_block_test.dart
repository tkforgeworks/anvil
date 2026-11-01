import 'package:anvil_core/anvil_core.dart';
import 'package:test/test.dart';

const _str = MetaStat(
  id: 'stat-strength',
  displayName: 'Strength',
  exportKey: 'str',
  sortOrder: 10,
);
const _con = MetaStat(
  id: 'stat-constitution',
  displayName: 'Constitution',
  exportKey: 'con',
  sortOrder: 20,
);
const _dex = MetaStat(
  id: 'stat-dexterity',
  displayName: 'Dexterity',
  exportKey: 'dex',
  sortOrder: 30,
);

final _growth = <String, Map<StatGrowthKey, double>>{
  'class-warrior': {
    const StatGrowthKey('stat-strength', 4): 14,
    const StatGrowthKey('stat-strength', 5): 16,
    const StatGrowthKey('stat-constitution', 5): 12.5,
  },
  'class-rogue': {
    const StatGrowthKey('stat-strength', 2): 3,
    const StatGrowthKey('stat-dexterity', 2): 9,
    // No constitution at level 2: the rogue adds nothing to it.
    const StatGrowthKey('stat-constitution', 3): 99,
  },
};

const _assignments = [
  NpcClassAssignment(classId: 'class-warrior', level: 5),
  NpcClassAssignment(classId: 'class-rogue', level: 2),
];

Map<String, NpcStatBlockRow> _byStat(List<NpcStatBlockRow> rows) => {
  for (final row in rows) row.statId: row,
};

void main() {
  test('sums each class at its own level', () {
    final rows = _byStat(
      computeNpcStatBlock(
        stats: const [_str, _con, _dex],
        classAssignments: _assignments,
        growthByClass: _growth,
        combatStats: const {},
      ),
    );
    expect(rows['stat-strength']!.inherited, 16 + 3);
    expect(rows['stat-dexterity']!.inherited, 9);
  });

  test('a missing level entry adds nothing', () {
    final rows = _byStat(
      computeNpcStatBlock(
        stats: const [_con],
        classAssignments: _assignments,
        growthByClass: _growth,
        combatStats: const {},
      ),
    );
    expect(rows['stat-constitution']!.inherited, 12.5);
  });

  test('a class with no growth loaded, or no assignments, gives 0', () {
    final unknown = computeNpcStatBlock(
      stats: const [_str],
      classAssignments: const [
        NpcClassAssignment(classId: 'class-missing', level: 1),
      ],
      growthByClass: _growth,
      combatStats: const {},
    );
    expect(unknown.single.inherited, 0);
    expect(unknown.single.effective, 0);

    final none = computeNpcStatBlock(
      stats: const [_str],
      classAssignments: const [],
      growthByClass: _growth,
      combatStats: const {},
    );
    expect(none.single.inherited, 0);
  });

  test('an override replaces the inherited value; null means none', () {
    final rows = _byStat(
      computeNpcStatBlock(
        stats: const [_str, _con, _dex],
        classAssignments: _assignments,
        growthByClass: _growth,
        combatStats: const {'stat-strength': 40, 'stat-dexterity': null},
      ),
    );
    final str = rows['stat-strength']!;
    expect(str.inherited, 19);
    expect(str.overrideValue, 40);
    expect(str.hasOverride, isTrue);
    expect(str.effective, 40);

    final dex = rows['stat-dexterity']!;
    expect(dex.overrideValue, isNull);
    expect(dex.hasOverride, isFalse);
    expect(dex.effective, 9);

    final con = rows['stat-constitution']!;
    expect(con.hasOverride, isFalse);
    expect(con.effective, 12.5);
  });

  test('an override of 0 still applies', () {
    final row = computeNpcStatBlock(
      stats: const [_str],
      classAssignments: _assignments,
      growthByClass: _growth,
      combatStats: const {'stat-strength': 0},
    ).single;
    expect(row.hasOverride, isTrue);
    expect(row.effective, 0);
  });

  test('rows follow sortOrder, ties keep their input order', () {
    const tieA = MetaStat(
      id: 'stat-a',
      displayName: 'A',
      exportKey: 'a',
      sortOrder: 20,
    );
    final rows = computeNpcStatBlock(
      stats: const [_dex, _con, tieA, _str],
      classAssignments: const [],
      growthByClass: const {},
      combatStats: const {},
    );
    expect(rows.map((r) => r.statId), [
      'stat-strength',
      'stat-constitution',
      'stat-a',
      'stat-dexterity',
    ]);
  });

  test('assignment order is the summation order', () {
    // 0.1 + 0.2 + 0.3 differs from 0.3 + 0.2 + 0.1 in IEEE doubles, as in
    // JavaScript; the sum follows the assignments' order.
    final growth = {
      'a': {const StatGrowthKey('s', 1): 0.1},
      'b': {const StatGrowthKey('s', 1): 0.2},
      'c': {const StatGrowthKey('s', 1): 0.3},
    };
    const stat = MetaStat(
      id: 's',
      displayName: 'S',
      exportKey: 's',
      sortOrder: 0,
    );
    double sumFor(List<String> order) => computeNpcStatBlock(
      stats: const [stat],
      classAssignments: [
        for (final id in order) NpcClassAssignment(classId: id, level: 1),
      ],
      growthByClass: growth,
      combatStats: const {},
    ).single.inherited;
    expect(sumFor(['a', 'b', 'c']), 0.1 + 0.2 + 0.3);
    expect(sumFor(['c', 'b', 'a']), 0.3 + 0.2 + 0.1);
  });
}
