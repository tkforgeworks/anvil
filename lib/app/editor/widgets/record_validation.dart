/// The single-record validation pass an editor shows after a save (design
/// §8.6, §10.2; 0.1.6 `useRecordValidation.ts`).
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../shell/shell_providers.dart';
import '../editor_state.dart';

/// Which record a [recordValidationProvider] entry is about.
typedef RecordValidationKey = (ValidationDomain, String);

/// The validation domain of an editor's [SaveDomain]; the six editor
/// domains have the same names in both enums.
ValidationDomain validationDomainOf(SaveDomain domain) =>
    ValidationDomain.values.byName(domain.name);

/// The issues of one record from the last validation of it, empty until
/// the editor asks for one: 0.1.6 showed nothing until the first save. The
/// editor calls [RecordValidationNotifier.afterSave] with every save
/// outcome (Save button, save bar, Ctrl+S), and the banner and field
/// indicators watch the list.
///
/// Mechanism: the core's `validateRecord(db, domain, id)` on the open
/// session's own connection, synchronously on the UI isolate, as design
/// §10.2 specifies. The core has no off-isolate single-record pass
/// (`ValidationService` only runs the project), the pass reads one
/// record's rows, and a background isolate would need a second connection;
/// this one opens none. It sees committed data only, so it runs after the
/// save transaction has committed.
///
/// Watches [requireSessionProvider], so a replaced or closed project resets
/// it; auto-disposed with the last widget that watches it.
final recordValidationProvider = NotifierProvider.autoDispose
    .family<
      RecordValidationNotifier,
      List<ValidationIssue>,
      RecordValidationKey
    >(RecordValidationNotifier.new);

class RecordValidationNotifier extends Notifier<List<ValidationIssue>> {
  RecordValidationNotifier(this.key);

  final RecordValidationKey key;

  @override
  List<ValidationIssue> build() {
    ref.watch(requireSessionProvider);
    return const [];
  }

  /// Validates the record now and returns its issues. A failure to read
  /// keeps the previous list and is logged.
  List<ValidationIssue> refresh() {
    final (domain, id) = key;
    try {
      final db = ref.read(requireSessionProvider).database;
      return state = List.unmodifiable(validateRecord(db, domain, id));
    } catch (error, stack) {
      ref
          .read(appLoggerProvider)
          .error(
            'Record validation failed for ${domain.value}/$id',
            error,
            stack,
          );
      return state;
    }
  }

  /// [refresh] when [outcome] is a completed save; the shape of
  /// `RecordEditorScope.onSaveOutcome` and the header's and save bar's.
  void afterSave(SaveOutcome outcome) {
    if (outcome == SaveOutcome.saved && ref.mounted) refresh();
  }
}
