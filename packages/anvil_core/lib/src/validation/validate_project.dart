import 'package:meta/meta.dart';

import '../db/project_database.dart';
import '../formula/derived_stat_cycles.dart';
import '../formula/formula_engine.dart';
import 'validation_issue.dart';

/// Runs every validation check, ported from Electron 0.1.6's
/// `validateProject` (`src/main/validation/engine.ts`), and returns the
/// issues in 0.1.6's order: direct references, junction references,
/// required custom fields, derived-stat syntax (base, then overrides),
/// derived-stat runtime at level 1, derived-stat cycles (base, then per
/// class) and stat growth formulas. All checks run inside one
/// [ProjectDatabase.read], so they see one snapshot.
///
/// Synchronous; the project-wide pass belongs on a background isolate
/// (`ValidationService.runProject`).
List<ValidationIssue> validateProject(ProjectDatabase db) =>
    db.read((tx) => runValidationFamilies(tx));

/// Restricts the check families to one record.
@internal
typedef RecordFilter = ({ValidationDomain domain, String id});

/// The check families, in 0.1.6's order. With [only], each family pushes
/// the record into its SQL and skips entirely when it never reports on
/// [only]'s domain, so the result is the project pass's issues for that
/// record, in the same relative order.
@internal
List<ValidationIssue> runValidationFamilies(
  ReadScope tx, {
  RecordFilter? only,
}) {
  final softSeverity = _softDeleteRefSeverity(tx);
  return [
    ..._checkDirectRefs(tx, softSeverity, only),
    ..._checkJunctionRefs(tx, softSeverity, only),
    ..._checkRequiredCustomFields(tx, only),
    ..._checkFormulaSyntax(tx, only),
    ..._checkFormulaRuntime(tx, only),
    ..._checkDerivedStatCycles(tx, only),
    ..._checkStatGrowthFormulas(tx, only),
  ];
}

ValidationIssue _issue(
  ValidationDomain domain,
  Object? recordId,
  Object? recordDisplayName,
  String? field,
  ValidationSeverity severity,
  String message,
) => ValidationIssue(
  domain: domain,
  recordId: '$recordId',
  recordDisplayName: '$recordDisplayName',
  field: field,
  severity: severity,
  message: message,
);

/// `AND <column> = ?` when [only] is set, else nothing.
String _recordClause(RecordFilter? only, String column, [String op = 'AND']) =>
    only == null ? '' : '$op $column = ?';

List<Object?> _recordParams(
  RecordFilter? only, [
  List<Object?> before = const [],
]) => [...before, if (only != null) only.id];

bool _skips(RecordFilter? only, ValidationDomain domain) =>
    only != null && only.domain != domain;

// ─── Settings ────────────────────────────────────────────────────────────────

/// `'Error'` makes soft-deleted references errors; anything else (including
/// no `project_info` row) warnings.
ValidationSeverity _softDeleteRefSeverity(ReadScope tx) {
  final rows = tx.select(
    'SELECT soft_delete_reference_severity AS v FROM project_info LIMIT 1',
  );
  return rows.isNotEmpty && rows.first['v'] == 'Error'
      ? ValidationSeverity.error
      : ValidationSeverity.warning;
}

// ─── Direct references ───────────────────────────────────────────────────────

final class _RefCheck {
  const _RefCheck({
    required this.domain,
    required this.fromTable,
    required this.fkCol,
    required this.nullable,
    required this.field,
    required this.targetTable,
    required this.targetSoftDeletes,
    required this.describeTarget,
  });

  final ValidationDomain domain;
  final String fromTable;
  final String fkCol;

  /// Rows whose [fkCol] is NULL are skipped.
  final bool nullable;
  final String field;
  final String targetTable;
  final bool targetSoftDeletes;
  final String describeTarget;
}

/// Electron's `DOMAIN_REF_CHECKS`, in its order. Every entry there has
/// `fromIdCol: 'id'`, `fromNameCol: 'display_name'` and
/// `fromActiveOnly: true`.
const _directRefChecks = [
  _RefCheck(
    domain: ValidationDomain.items,
    fromTable: 'items',
    fkCol: 'item_category_id',
    nullable: false,
    field: 'itemCategoryId',
    targetTable: 'item_categories',
    targetSoftDeletes: false,
    describeTarget: 'item category',
  ),
  _RefCheck(
    domain: ValidationDomain.items,
    fromTable: 'items',
    fkCol: 'rarity_id',
    nullable: false,
    field: 'rarityId',
    targetTable: 'rarities',
    targetSoftDeletes: false,
    describeTarget: 'rarity',
  ),
  _RefCheck(
    domain: ValidationDomain.recipes,
    fromTable: 'recipes',
    fkCol: 'output_item_id',
    nullable: false,
    field: 'outputItemId',
    targetTable: 'items',
    targetSoftDeletes: true,
    describeTarget: 'output item',
  ),
  _RefCheck(
    domain: ValidationDomain.recipes,
    fromTable: 'recipes',
    fkCol: 'crafting_station_id',
    nullable: true,
    field: 'craftingStationId',
    targetTable: 'crafting_stations',
    targetSoftDeletes: false,
    describeTarget: 'crafting station',
  ),
  _RefCheck(
    domain: ValidationDomain.recipes,
    fromTable: 'recipes',
    fkCol: 'crafting_specialization_id',
    nullable: true,
    field: 'craftingSpecializationId',
    targetTable: 'crafting_specializations',
    targetSoftDeletes: false,
    describeTarget: 'crafting specialization',
  ),
  _RefCheck(
    domain: ValidationDomain.npcs,
    fromTable: 'npcs',
    fkCol: 'npc_type_id',
    nullable: false,
    field: 'npcTypeId',
    targetTable: 'npc_types',
    targetSoftDeletes: false,
    describeTarget: 'NPC type',
  ),
  _RefCheck(
    domain: ValidationDomain.npcs,
    fromTable: 'npcs',
    fkCol: 'loot_table_id',
    nullable: true,
    field: 'lootTableId',
    targetTable: 'loot_tables',
    targetSoftDeletes: true,
    describeTarget: 'loot table',
  ),
];

/// Broken: the FK points at no row. Soft-deleted: the target row has
/// `deleted_at` set. Soft-deleted owners are never checked.
List<ValidationIssue> _checkDirectRefs(
  ReadScope tx,
  ValidationSeverity softSeverity,
  RecordFilter? only,
) {
  final issues = <ValidationIssue>[];
  for (final c in _directRefChecks) {
    if (_skips(only, c.domain)) continue;
    const ownerActive = 'AND f.deleted_at IS NULL';
    final fkNotNull = c.nullable ? 'AND f.${c.fkCol} IS NOT NULL' : '';
    final record = _recordClause(only, 'f.id');

    final broken = tx.select(
      'SELECT f.id AS id, f.display_name AS name, f.${c.fkCol} AS ref '
      'FROM ${c.fromTable} f '
      'LEFT JOIN ${c.targetTable} t ON t.id = f.${c.fkCol} '
      'WHERE t.id IS NULL $fkNotNull $ownerActive $record',
      _recordParams(only),
    );
    for (final r in broken) {
      issues.add(
        _issue(
          c.domain,
          r['id'],
          r['name'],
          c.field,
          ValidationSeverity.error,
          "References nonexistent ${c.describeTarget} '${r['ref']}'.",
        ),
      );
    }

    if (c.targetSoftDeletes) {
      final soft = tx.select(
        'SELECT f.id AS id, f.display_name AS name, '
        't.display_name AS targetName '
        'FROM ${c.fromTable} f '
        'JOIN ${c.targetTable} t ON t.id = f.${c.fkCol} '
        'WHERE t.deleted_at IS NOT NULL $ownerActive $record',
        _recordParams(only),
      );
      for (final r in soft) {
        issues.add(
          _issue(
            c.domain,
            r['id'],
            r['name'],
            c.field,
            softSeverity,
            'References soft-deleted ${c.describeTarget} '
            "'${r['targetName']}'.",
          ),
        );
      }
    }
  }
  return issues;
}

// ─── Junction references ─────────────────────────────────────────────────────

final class _JunctionCheck {
  const _JunctionCheck({
    required this.domain,
    required this.ownerTable,
    required this.junction,
    required this.ownerFkCol,
    required this.targetFkCol,
    required this.targetTable,
    required this.field,
    required this.describeTarget,
  });

  final ValidationDomain domain;
  final String ownerTable;
  final String junction;
  final String ownerFkCol;
  final String targetFkCol;
  final String targetTable;
  final String field;
  final String describeTarget;
}

/// Electron's junction checks, in its order. Every target there soft
/// deletes (`targetSoftDeletes: true`).
const _junctionChecks = [
  _JunctionCheck(
    domain: ValidationDomain.classes,
    ownerTable: 'classes',
    junction: 'class_ability_assignments',
    ownerFkCol: 'class_id',
    targetFkCol: 'ability_id',
    targetTable: 'abilities',
    field: 'abilityAssignments',
    describeTarget: 'ability',
  ),
  _JunctionCheck(
    domain: ValidationDomain.recipes,
    ownerTable: 'recipes',
    junction: 'recipe_ingredients',
    ownerFkCol: 'recipe_id',
    targetFkCol: 'item_id',
    targetTable: 'items',
    field: 'ingredients',
    describeTarget: 'ingredient item',
  ),
  _JunctionCheck(
    domain: ValidationDomain.npcs,
    ownerTable: 'npcs',
    junction: 'npc_class_assignments',
    ownerFkCol: 'npc_id',
    targetFkCol: 'class_id',
    targetTable: 'classes',
    field: 'classAssignments',
    describeTarget: 'class',
  ),
  _JunctionCheck(
    domain: ValidationDomain.npcs,
    ownerTable: 'npcs',
    junction: 'npc_ability_assignments',
    ownerFkCol: 'npc_id',
    targetFkCol: 'ability_id',
    targetTable: 'abilities',
    field: 'abilityAssignments',
    describeTarget: 'ability',
  ),
  _JunctionCheck(
    domain: ValidationDomain.lootTables,
    ownerTable: 'loot_tables',
    junction: 'loot_table_entries',
    ownerFkCol: 'loot_table_id',
    targetFkCol: 'item_id',
    targetTable: 'items',
    field: 'entries',
    describeTarget: 'item',
  ),
];

List<ValidationIssue> _checkJunctionRefs(
  ReadScope tx,
  ValidationSeverity softSeverity,
  RecordFilter? only,
) {
  final issues = <ValidationIssue>[];
  for (final c in _junctionChecks) {
    if (_skips(only, c.domain)) continue;
    final record = _recordClause(only, 'o.id');

    final broken = tx.select(
      'SELECT o.id AS id, o.display_name AS name, j.${c.targetFkCol} AS ref '
      'FROM ${c.junction} j '
      'JOIN ${c.ownerTable} o ON o.id = j.${c.ownerFkCol} '
      'LEFT JOIN ${c.targetTable} t ON t.id = j.${c.targetFkCol} '
      'WHERE t.id IS NULL AND o.deleted_at IS NULL $record',
      _recordParams(only),
    );
    for (final r in broken) {
      issues.add(
        _issue(
          c.domain,
          r['id'],
          r['name'],
          c.field,
          ValidationSeverity.error,
          'Assignment references nonexistent ${c.describeTarget} '
          "'${r['ref']}'.",
        ),
      );
    }

    final soft = tx.select(
      'SELECT o.id AS id, o.display_name AS name, t.display_name AS targetName '
      'FROM ${c.junction} j '
      'JOIN ${c.ownerTable} o ON o.id = j.${c.ownerFkCol} '
      'JOIN ${c.targetTable} t ON t.id = j.${c.targetFkCol} '
      'WHERE t.deleted_at IS NOT NULL AND o.deleted_at IS NULL $record',
      _recordParams(only),
    );
    for (final r in soft) {
      issues.add(
        _issue(
          c.domain,
          r['id'],
          r['name'],
          c.field,
          softSeverity,
          'Assignment references soft-deleted ${c.describeTarget} '
          "'${r['targetName']}'.",
        ),
      );
    }
  }
  return issues;
}

// ─── Required custom fields ──────────────────────────────────────────────────

/// Active records in a required definition's scope whose value is missing
/// or empty.
List<ValidationIssue> _checkRequiredCustomFields(
  ReadScope tx,
  RecordFilter? only,
) {
  if (_skips(only, ValidationDomain.items) &&
      _skips(only, ValidationDomain.npcs)) {
    return const [];
  }
  final issues = <ValidationIssue>[];
  final defs = tx.select(
    'SELECT id, scope_type, scope_id, field_name '
    'FROM custom_field_definitions '
    'WHERE is_required = 1',
  );
  for (final def in defs) {
    final isItemScope = def['scope_type'] == 'item_category';
    final ownerTable = isItemScope ? 'items' : 'npcs';
    final scopeCol = isItemScope ? 'item_category_id' : 'npc_type_id';
    final domain = isItemScope ? ValidationDomain.items : ValidationDomain.npcs;
    if (_skips(only, domain)) continue;

    final offenders = tx.select(
      'SELECT o.id AS id, o.display_name AS name '
      'FROM $ownerTable o '
      'LEFT JOIN custom_field_values v '
      'ON v.domain = ? AND v.record_id = o.id AND v.field_definition_id = ? '
      'WHERE o.$scopeCol = ? '
      'AND o.deleted_at IS NULL '
      "AND (v.value IS NULL OR v.value = '') "
      '${_recordClause(only, 'o.id')}',
      _recordParams(only, [ownerTable, def['id'], def['scope_id']]),
    );
    final fieldName = def['field_name'];
    for (final o in offenders) {
      issues.add(
        _issue(
          domain,
          o['id'],
          o['name'],
          'custom:$fieldName',
          ValidationSeverity.error,
          "Required field '$fieldName' is empty.",
        ),
      );
    }
  }
  return issues;
}

// ─── Derived-stat formulas ───────────────────────────────────────────────────

const _derivedStatsSql =
    'SELECT id, display_name, export_key, formula FROM derived_stat_definitions';

/// Syntax errors in base formulas, then in the overrides of active classes.
List<ValidationIssue> _checkFormulaSyntax(ReadScope tx, RecordFilter? only) {
  final issues = <ValidationIssue>[];

  if (!_skips(only, ValidationDomain.derivedStats)) {
    final base = tx.select(
      '$_derivedStatsSql ${_recordClause(only, 'id', 'WHERE')}',
      _recordParams(only),
    );
    for (final r in base) {
      final err = validateFormula(r['formula'] as String);
      if (err != null) {
        issues.add(
          _issue(
            ValidationDomain.derivedStats,
            r['id'],
            r['display_name'],
            'formula',
            ValidationSeverity.error,
            'Formula syntax error: $err',
          ),
        );
      }
    }
  }

  if (!_skips(only, ValidationDomain.classes)) {
    final overrides = tx.select(
      'SELECT o.class_id, o.derived_stat_id, o.formula, '
      'c.display_name AS class_name, d.display_name AS derived_name '
      'FROM class_derived_stat_overrides o '
      'JOIN classes c ON c.id = o.class_id '
      'JOIN derived_stat_definitions d ON d.id = o.derived_stat_id '
      'WHERE c.deleted_at IS NULL ${_recordClause(only, 'c.id')}',
      _recordParams(only),
    );
    for (final r in overrides) {
      final err = validateFormula(r['formula'] as String);
      if (err != null) {
        final derivedName = r['derived_name'];
        issues.add(
          _issue(
            ValidationDomain.classes,
            r['class_id'],
            r['class_name'],
            'derivedStat:$derivedName',
            ValidationSeverity.error,
            "Override formula for '$derivedName' has syntax error: $err",
          ),
        );
      }
    }
  }

  return issues;
}

/// Electron's `buildClassLevel1Bindings`: every stat's export key bound to
/// the class's level-1 growth value (0 when it has none), then the class
/// metadata fields (overwriting), then `resource_multiplier`.
Map<String, double> _level1Bindings(
  ReadScope tx,
  Object? classId,
  double resourceMultiplier,
) {
  final bindings = <String, double>{};
  for (final s in tx.select(
    'SELECT s.export_key AS key, COALESCE(g.value, 0) AS value '
    'FROM stats s '
    'LEFT JOIN class_stat_growth g '
    'ON g.stat_id = s.id AND g.class_id = ? AND g.level = 1',
    [classId],
  )) {
    bindings[s['key'] as String] = (s['value'] as num).toDouble();
  }
  for (final m in tx.select(
    'SELECT field_key AS key, value FROM class_metadata_fields '
    'WHERE class_id = ?',
    [classId],
  )) {
    bindings[m['key'] as String] = (m['value'] as num).toDouble();
  }
  bindings['resource_multiplier'] = resourceMultiplier;
  return bindings;
}

/// Each active class's effective formula (override, else base) for every
/// derived stat, evaluated at level 1. Pairs whose effective formula failed
/// the syntax check are skipped, as 0.1.6 skips them.
List<ValidationIssue> _checkFormulaRuntime(ReadScope tx, RecordFilter? only) {
  if (_skips(only, ValidationDomain.classes)) return const [];
  final issues = <ValidationIssue>[];

  final base = tx.select(_derivedStatsSql);
  final classes = tx.select(
    'SELECT id, display_name, resource_multiplier AS rm FROM classes '
    'WHERE deleted_at IS NULL ${_recordClause(only, 'id')}',
    _recordParams(only),
  );
  final overrideMap = <String, String>{
    for (final o in tx.select(
      'SELECT class_id, derived_stat_id, formula '
      'FROM class_derived_stat_overrides '
      '${_recordClause(only, 'class_id', 'WHERE')}',
      _recordParams(only),
    ))
      '${o['class_id']}:${o['derived_stat_id']}': o['formula'] as String,
  };
  final syntaxOk = <String, bool>{};

  for (final cls in classes) {
    final bindings = _level1Bindings(
      tx,
      cls['id'],
      (cls['rm'] as num).toDouble(),
    );
    for (final ds in base) {
      final formula =
          overrideMap['${cls['id']}:${ds['id']}'] ?? ds['formula'] as String;
      if (!syntaxOk.putIfAbsent(
        formula,
        () => validateFormula(formula) == null,
      )) {
        continue;
      }
      final result = evaluateFormula(formula, bindings);
      final error = result.error;
      if (error != null && !result.isSyntaxError) {
        final name = ds['display_name'];
        issues.add(
          _issue(
            ValidationDomain.classes,
            cls['id'],
            cls['display_name'],
            'derivedStat:$name',
            ValidationSeverity.warning,
            "Formula for '$name' failed at level 1: $error",
          ),
        );
      }
    }
  }
  return issues;
}

/// A cycle in the base graph (one issue per stat in it), then, per active
/// class with overrides, a cycle its overrides create that differs from the
/// base one. Cycle detection and formula skipping are
/// [findDerivedStatCycle]'s.
List<ValidationIssue> _checkDerivedStatCycles(
  ReadScope tx,
  RecordFilter? only,
) {
  if (_skips(only, ValidationDomain.derivedStats) &&
      _skips(only, ValidationDomain.classes)) {
    return const [];
  }
  final issues = <ValidationIssue>[];

  final definitions = [
    for (final r in tx.select(_derivedStatsSql))
      DerivedStatFormula(
        id: r['id'] as String,
        displayName: r['display_name'] as String,
        exportKey: r['export_key'] as String,
        formula: r['formula'] as String,
      ),
  ];
  final baseCycle = findDerivedStatCycle(definitions);
  if (baseCycle != null && !_skips(only, ValidationDomain.derivedStats)) {
    for (var i = 0; i < baseCycle.ids.length; i++) {
      final id = baseCycle.ids[i];
      if (only != null && only.id != id) continue;
      issues.add(
        _issue(
          ValidationDomain.derivedStats,
          id,
          baseCycle.names[i],
          'formula',
          ValidationSeverity.error,
          baseCycle.message,
        ),
      );
    }
  }
  if (_skips(only, ValidationDomain.classes)) return issues;

  final classes = tx.select(
    'SELECT id, display_name FROM classes '
    'WHERE deleted_at IS NULL ${_recordClause(only, 'id')}',
    _recordParams(only),
  );
  final overrideByClass = <String, Map<String, String>>{};
  for (final o in tx.select(
    'SELECT class_id, derived_stat_id, formula '
    'FROM class_derived_stat_overrides '
    '${_recordClause(only, 'class_id', 'WHERE')}',
    _recordParams(only),
  )) {
    (overrideByClass['${o['class_id']}'] ??= {})['${o['derived_stat_id']}'] =
        o['formula'] as String;
  }

  for (final cls in classes) {
    final overrides = overrideByClass['${cls['id']}'];
    if (overrides == null || overrides.isEmpty) continue;
    final cycle = findDerivedStatCycle(definitions, overrides: overrides);
    if (cycle != null && !cycle.isSameCycleAs(baseCycle)) {
      issues.add(
        _issue(
          ValidationDomain.classes,
          cls['id'],
          cls['display_name'],
          'derivedStatOverrides',
          ValidationSeverity.error,
          cycle.overrideMessage,
        ),
      );
    }
  }
  return issues;
}

// ─── Stat growth formulas ────────────────────────────────────────────────────

const _allowedGrowthVariables = {'level', 'max_level'};

/// Per formula of an active class: a syntax error (and nothing else), or a
/// warning for variables other than `level`/`max_level` and the first level
/// from 1 to `max_level` at which evaluation fails.
List<ValidationIssue> _checkStatGrowthFormulas(
  ReadScope tx,
  RecordFilter? only,
) {
  if (_skips(only, ValidationDomain.classes)) return const [];
  final issues = <ValidationIssue>[];
  // Like 0.1.6, a file without a project_info row fails here.
  final maxLevel =
      tx.select('SELECT max_level FROM project_info LIMIT 1').first['max_level']
          as int;

  final rows = tx.select(
    'SELECT f.class_id, f.stat_id, f.formula, '
    'c.display_name AS class_name, s.display_name AS stat_name '
    'FROM class_stat_growth_formulas f '
    'JOIN classes c ON c.id = f.class_id AND c.deleted_at IS NULL '
    'JOIN stats s ON s.id = f.stat_id '
    '${_recordClause(only, 'f.class_id', 'WHERE')}',
    _recordParams(only),
  );
  for (final row in rows) {
    final formula = row['formula'] as String;
    final statName = row['stat_name'];
    final field = 'statGrowthFormula:$statName';
    ValidationIssue issue(ValidationSeverity severity, String message) =>
        _issue(
          ValidationDomain.classes,
          row['class_id'],
          row['class_name'],
          field,
          severity,
          message,
        );

    final syntaxErr = validateFormula(formula);
    if (syntaxErr != null) {
      issues.add(
        issue(
          ValidationSeverity.error,
          'Stat growth formula for $statName: $syntaxErr',
        ),
      );
      continue;
    }

    final unknowns = [
      for (final v in extractVariableNames(formula))
        if (!_allowedGrowthVariables.contains(v)) v,
    ];
    if (unknowns.isNotEmpty) {
      issues.add(
        issue(
          ValidationSeverity.warning,
          'Stat growth formula for $statName references unknown '
          'variable(s): ${unknowns.join(', ')}. '
          'Only "level" and "max_level" are available.',
        ),
      );
    }

    for (var level = 1; level <= maxLevel; level++) {
      final result = evaluateFormula(formula, {
        'level': level.toDouble(),
        'max_level': maxLevel.toDouble(),
      });
      final error = result.error;
      if (error != null) {
        issues.add(
          issue(
            ValidationSeverity.error,
            'Stat growth formula for $statName fails at level $level: $error',
          ),
        );
        break;
      }
    }
  }
  return issues;
}
