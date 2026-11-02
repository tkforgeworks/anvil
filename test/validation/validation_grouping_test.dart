import 'package:anvil/app/settings/project/project_settings_dialog.dart';
import 'package:anvil/app/shell/shell_domain.dart';
import 'package:anvil/app/validation/last_checked.dart';
import 'package:anvil/app/validation/validation_grouping.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../dashboard/dashboard_fakes.dart' show issue;

void main() {
  const e = ValidationSeverity.error;
  const w = ValidationSeverity.warning;
  const i = ValidationSeverity.info;

  test('groups follow 0.1.6 DOMAIN_ORDER, skipping empty domains', () {
    final groups = groupIssuesByDomain([
      issue(ValidationDomain.derivedStats, 'd', 'Max HP', e, 'cycle'),
      issue(ValidationDomain.lootTables, 'l', 'Goblin Drops', w, 'w'),
      issue(ValidationDomain.items, 'x', 'Axe', w, 'w'),
      issue(ValidationDomain.classes, 'c', 'Warrior', w, 'w'),
      issue(ValidationDomain.npcs, 'n', 'Orc', e, 'e'),
    ]);
    expect(
      [for (final g in groups) g.label],
      ['Classes', 'Items', 'NPCs', 'Loot Tables', 'Derived Stats'],
    );
  });

  test('every domain label is the 0.1.6 one', () {
    expect(
      [for (final d in validationDomainOrder) validationDomainLabel(d)],
      [
        'Classes',
        'Abilities',
        'Items',
        'Recipes',
        'NPCs',
        'Loot Tables',
        'Derived Stats',
      ],
    );
    expect(validationDomainOrder, ValidationDomain.values);
  });

  test('errors come first in a group, then warnings, then info; the engine '
      'order is kept within a severity', () {
    final groups = groupIssuesByDomain([
      issue(ValidationDomain.items, '1', 'A', w, 'w1'),
      issue(ValidationDomain.items, '2', 'B', i, 'i1'),
      issue(ValidationDomain.items, '3', 'C', e, 'e1'),
      issue(ValidationDomain.items, '4', 'D', w, 'w2'),
      issue(ValidationDomain.items, '5', 'E', e, 'e2'),
    ]);
    expect(groups.single.issues.map((x) => x.message), [
      'e1',
      'e2',
      'w1',
      'w2',
      'i1',
    ]);
  });

  test('no issues, no groups', () {
    expect(groupIssuesByDomain(const []), isEmpty);
  });

  test('a record issue opens its editor; a derived stat issue opens Project '
      'Settings on Stats & Formulas', () {
    final cases = {
      ValidationDomain.classes: ShellDomain.classes,
      ValidationDomain.abilities: ShellDomain.abilities,
      ValidationDomain.items: ShellDomain.items,
      ValidationDomain.recipes: ShellDomain.recipes,
      ValidationDomain.npcs: ShellDomain.npcs,
      ValidationDomain.lootTables: ShellDomain.lootTables,
    };
    for (final MapEntry(key: domain, value: shell) in cases.entries) {
      expect(
        issueRoute(issue(domain, 'id-1', 'R', e, 'm')),
        RecordTarget(shell, 'id-1'),
        reason: domain.value,
      );
    }
    expect(
      issueRoute(
        issue(ValidationDomain.derivedStats, 'ds-1', 'Max HP', e, 'm'),
      ),
      const SettingsTarget(ProjectSettingsTab.statsAndFormulas),
    );
  });

  test('counts and their labels count errors and warnings only', () {
    final counts = countIssues([
      issue(ValidationDomain.items, '1', 'A', e, 'e'),
      issue(ValidationDomain.items, '2', 'B', w, 'w'),
      issue(ValidationDomain.items, '3', 'C', w, 'w'),
      issue(ValidationDomain.items, '4', 'D', i, 'i'),
    ]);
    expect(counts, (errors: 1, warnings: 2));
    expect(errorsLabel(1), '1 error');
    expect(errorsLabel(2), '2 errors');
    expect(warningsLabel(1), '1 warning');
    expect(warningsLabel(3), '3 warnings');
  });

  test('Last checked uses the en-US medium date and time', () {
    expect(
      formatLastChecked(DateTime(2026, 11, 1, 14, 5, 9)),
      'Nov 1, 2026, 2:05:09 PM',
    );
    expect(
      formatLastChecked(DateTime(2026, 1, 9, 0, 0, 3)),
      'Jan 9, 2026, 12:00:03 AM',
    );
    expect(
      formatLastChecked(DateTime(2026, 12, 31, 12, 30)),
      'Dec 31, 2026, 12:30:00 PM',
    );
  });
}
