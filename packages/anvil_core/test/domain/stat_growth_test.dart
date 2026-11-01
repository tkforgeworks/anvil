import 'package:anvil_core/anvil_core.dart';
import 'package:test/test.dart';

void main() {
  const str1 = StatGrowthKey('stat-strength', 1);
  const str2 = StatGrowthKey('stat-strength', 2);
  const con1 = StatGrowthKey('stat-constitution', 1);
  const con9 = StatGrowthKey('stat-constitution', 9);

  test('keeps manual entries when there are no formulas', () {
    final resolved = resolveStatGrowth(
      manual: {str1: 12, str2: 14},
      formulas: const {},
      maxLevel: 20,
    );
    expect(resolved, {str1: 12.0, str2: 14.0});
  });

  test('drops manual entries for a stat that has a formula', () {
    final resolved = resolveStatGrowth(
      manual: {str1: 12, con1: 99, con9: 99},
      formulas: const {'stat-constitution': '12 + level * 3'},
      maxLevel: 3,
    );
    expect(resolved, {
      str1: 12.0,
      con1: 15.0,
      const StatGrowthKey('stat-constitution', 2): 18.0,
      const StatGrowthKey('stat-constitution', 3): 21.0,
    });
  });

  test('evaluates every level from 1 to maxLevel with max_level bound', () {
    final resolved = resolveStatGrowth(
      manual: const {},
      formulas: const {'stat-wisdom': 'max_level - level'},
      maxLevel: 4,
    );
    expect(resolved.keys.map((k) => k.level), [1, 2, 3, 4]);
    expect(resolved.values, [3.0, 2.0, 1.0, 0.0]);
  });

  test('orders manual entries first, then formulas level by level', () {
    final resolved = resolveStatGrowth(
      manual: {str2: 1, str1: 2},
      formulas: const {'b': '1', 'a': '2'},
      maxLevel: 2,
    );
    expect(resolved.keys.toList(), [
      str2,
      str1,
      const StatGrowthKey('b', 1),
      const StatGrowthKey('b', 2),
      const StatGrowthKey('a', 1),
      const StatGrowthKey('a', 2),
    ]);
  });

  test('a level whose evaluation fails resolves to 0', () {
    // Unknown variable: a runtime error at every level.
    expect(
      resolveStatGrowth(
        manual: const {},
        formulas: const {'s': 'level * missing'},
        maxLevel: 2,
      ),
      {const StatGrowthKey('s', 1): 0.0, const StatGrowthKey('s', 2): 0.0},
    );
    // Division by zero fails only at the level where the divisor is 0.
    expect(
      resolveStatGrowth(
        manual: const {},
        formulas: const {'s': '6 / (level - 2)'},
        maxLevel: 3,
      ),
      {
        const StatGrowthKey('s', 1): -6.0,
        const StatGrowthKey('s', 2): 0.0,
        const StatGrowthKey('s', 3): 6.0,
      },
    );
  });

  test('a syntax error or an empty formula resolves to 0 at every level', () {
    expect(
      resolveStatGrowth(
        manual: const {},
        formulas: const {'s': '1 +', 't': ''},
        maxLevel: 1,
      ),
      {const StatGrowthKey('s', 1): 0.0, const StatGrowthKey('t', 1): 0.0},
    );
  });

  test('maxLevel 0 leaves only the manual entries of manual stats', () {
    expect(
      resolveStatGrowth(
        manual: {str1: 5, con1: 7},
        formulas: const {'stat-constitution': 'level'},
        maxLevel: 0,
      ),
      {str1: 5.0},
    );
  });
}
