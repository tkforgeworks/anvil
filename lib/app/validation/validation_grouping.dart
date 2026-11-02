/// The Validation page's pure rules, ported from 0.1.6's `ValidationPage.tsx`:
/// the domain order and labels, the grouping with errors first, and where a
/// click on an issue leads.
library;

import 'package:anvil_core/anvil_core.dart';

import '../settings/project/project_settings_dialog.dart'
    show ProjectSettingsTab;
import '../shell/shell_domain.dart';

/// 0.1.6's `DOMAIN_ORDER`; also the order of [ValidationDomain.values].
const validationDomainOrder = [
  ValidationDomain.classes,
  ValidationDomain.abilities,
  ValidationDomain.items,
  ValidationDomain.recipes,
  ValidationDomain.npcs,
  ValidationDomain.lootTables,
  ValidationDomain.derivedStats,
];

/// 0.1.6's `DOMAIN_LABELS`: the heading of each group.
String validationDomainLabel(ValidationDomain domain) => switch (domain) {
  ValidationDomain.classes => 'Classes',
  ValidationDomain.abilities => 'Abilities',
  ValidationDomain.items => 'Items',
  ValidationDomain.recipes => 'Recipes',
  ValidationDomain.npcs => 'NPCs',
  ValidationDomain.lootTables => 'Loot Tables',
  ValidationDomain.derivedStats => 'Derived Stats',
};

/// 0.1.6's `SEVERITY_ORDER`.
int _severityRank(ValidationSeverity s) => switch (s) {
  ValidationSeverity.error => 0,
  ValidationSeverity.warning => 1,
  ValidationSeverity.info => 2,
};

/// One domain's issues under its heading.
final class IssueGroup {
  const IssueGroup(this.domain, this.issues);

  final ValidationDomain domain;
  final List<ValidationIssue> issues;

  String get label => validationDomainLabel(domain);
}

/// `groupByDomain` in `ValidationPage.tsx`: one group per domain that has
/// issues, in [validationDomainOrder], each sorted errors, then warnings,
/// then info. The sort is stable, so within a severity the engine's order
/// is kept, as JavaScript's `Array.prototype.sort` keeps it.
List<IssueGroup> groupIssuesByDomain(Iterable<ValidationIssue> issues) {
  final all = issues.toList();
  return [
    for (final domain in validationDomainOrder)
      if (_stableSorted(all.where((i) => i.domain == domain).toList())
          case final group when group.isNotEmpty)
        IssueGroup(domain, group),
  ];
}

List<ValidationIssue> _stableSorted(List<ValidationIssue> issues) {
  final indexed = issues.indexed.toList()
    ..sort((a, b) {
      final bySeverity = _severityRank(a.$2.severity)
          .compareTo(_severityRank(b.$2.severity));
      return bySeverity != 0 ? bySeverity : a.$1.compareTo(b.$1);
    });
  return [for (final (_, issue) in indexed) issue];
}

/// The error count and the warning count, as the page's chips and the
/// dashboard's tile count them (info is not counted, as in 0.1.6).
({int errors, int warnings}) countIssues(Iterable<ValidationIssue> issues) {
  var errors = 0;
  var warnings = 0;
  for (final i in issues) {
    if (i.severity == ValidationSeverity.error) errors++;
    if (i.severity == ValidationSeverity.warning) warnings++;
  }
  return (errors: errors, warnings: warnings);
}

/// `1 error`, `3 errors`.
String errorsLabel(int n) => '$n ${n == 1 ? 'error' : 'errors'}';

/// `1 warning`, `3 warnings`.
String warningsLabel(int n) => '$n ${n == 1 ? 'warning' : 'warnings'}';

/// Where a click on an issue goes.
sealed class IssueTarget {
  const IssueTarget();
}

/// The editor of record [id] in [domain].
final class RecordTarget extends IssueTarget {
  const RecordTarget(this.domain, this.id);

  final ShellDomain domain;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is RecordTarget && other.domain == domain && other.id == id;

  @override
  int get hashCode => Object.hash(domain, id);

  @override
  String toString() => 'RecordTarget(${domain.name}, $id)';
}

/// The Project Settings dialog on [tab].
final class SettingsTarget extends IssueTarget {
  const SettingsTarget(this.tab);

  final ProjectSettingsTab tab;

  @override
  bool operator ==(Object other) => other is SettingsTarget && other.tab == tab;

  @override
  int get hashCode => tab.hashCode;

  @override
  String toString() => 'SettingsTarget(${tab.name})';
}

/// `domainRoute` in `ValidationPage.tsx`: a record issue opens its record's
/// editor. A `derived-stats` issue carries the derived stat definition's id
/// as its `recordId` (`engine.ts`), which 0.1.6 sent to `/classes/<id>`,
/// a class that does not exist; 0.2.0 opens the Project Settings dialog on
/// Stats & Formulas, where derived stats are defined.
IssueTarget issueRoute(ValidationIssue issue) => switch (issue.domain) {
  ValidationDomain.classes => RecordTarget(ShellDomain.classes, issue.recordId),
  ValidationDomain.abilities => RecordTarget(
    ShellDomain.abilities,
    issue.recordId,
  ),
  ValidationDomain.items => RecordTarget(ShellDomain.items, issue.recordId),
  ValidationDomain.recipes => RecordTarget(ShellDomain.recipes, issue.recordId),
  ValidationDomain.npcs => RecordTarget(ShellDomain.npcs, issue.recordId),
  ValidationDomain.lootTables => RecordTarget(
    ShellDomain.lootTables,
    issue.recordId,
  ),
  ValidationDomain.derivedStats => const SettingsTarget(
    ProjectSettingsTab.statsAndFormulas,
  ),
};
