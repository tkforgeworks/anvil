/// When the project-wide validation pass last completed: the Validation
/// page's `Last checked` line (0.1.6 `validation.store` `lastValidatedAt`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editor/clock.dart';
import '../providers.dart';
import '../shell/shell_providers.dart';

/// The time [validationIssuesProvider] last settled on a result, or null
/// before the first one.
///
/// `ValidationIssuesNotifier` keeps no timestamp, so this listens to it and
/// stamps each completed run with [clockProvider]. It is not auto-dispose:
/// once read (the dashboard, the page the shell opens on, listens to it) it
/// follows every run for the rest of the session, and it resets when the
/// session changes. A run that completed before the first read is stamped
/// with the time of that read.
final validationLastCheckedProvider =
    NotifierProvider<ValidationLastCheckedNotifier, DateTime?>(
      ValidationLastCheckedNotifier.new,
    );

class ValidationLastCheckedNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() {
    ref.watch(projectSessionProvider);
    ref.listen(validationIssuesProvider, (_, next) {
      if (_settled(next)) state = ref.read(clockProvider)();
    });
    return _settled(ref.read(validationIssuesProvider))
        ? ref.read(clockProvider)()
        : null;
  }

  static bool _settled(AsyncValue<Object?> value) =>
      value.hasValue && !value.isLoading && !value.hasError;
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// `formatTimestamp` in `ValidationPage.tsx`: `Intl.DateTimeFormat` with
/// `dateStyle: 'medium', timeStyle: 'medium'` as an en-US locale prints it,
/// in local time: `Nov 1, 2026, 2:05:09 PM`.
String formatLastChecked(DateTime time) {
  final t = time.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final meridiem = t.hour < 12 ? 'AM' : 'PM';
  return '${_months[t.month - 1]} ${t.day}, ${t.year}, '
      '$hour12:${two(t.minute)}:${two(t.second)} $meridiem';
}
