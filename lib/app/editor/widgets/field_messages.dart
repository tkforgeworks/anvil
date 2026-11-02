/// The error and helper text a field shows for a save blocker and a
/// validation issue.
library;

import 'package:anvil_core/anvil_core.dart';

/// The error and helper text a field shows for [blocker] (a save blocker)
/// and [issue] (a validation issue from the last save), as
/// `DraftTextField` resolves them: a blocker or an error issue is the
/// error text, any other issue the helper text.
({String? error, String? helper, bool warning}) fieldMessages(
  String? blocker,
  ValidationIssue? issue,
) {
  if (blocker != null) return (error: blocker, helper: null, warning: false);
  if (issue == null) return (error: null, helper: null, warning: false);
  if (issue.severity == ValidationSeverity.error) {
    return (error: issue.message, helper: null, warning: false);
  }
  return (error: null, helper: issue.message, warning: true);
}
