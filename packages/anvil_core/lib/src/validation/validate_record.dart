import '../db/project_database.dart';
import 'validate_project.dart' show runValidationFamilies;
import 'validation_issue.dart';

/// The issues [validateProject] would report for the record [id] of
/// [domain], in the same relative order, computed with the record pushed
/// into each family's SQL rather than by filtering a project pass.
///
/// Families that never report on [domain] are skipped. Cross-record inputs
/// are still read where an issue depends on them: a class's override cycle
/// is compared with the base graph's cycle, and a derived stat's cycle
/// issue is its entry in the base cycle. Runs synchronously on the caller's
/// connection (the editor's, after a save), inside one
/// [ProjectDatabase.read]. An unknown [id] yields no issues.
List<ValidationIssue> validateRecord(
  ProjectDatabase db,
  ValidationDomain domain,
  String id,
) => db.read((tx) => runValidationFamilies(tx, only: (domain: domain, id: id)));
