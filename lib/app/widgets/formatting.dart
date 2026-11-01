/// Pure display formatting ported from the 0.1.6 renderer components, so the
/// rules are unit-tested without widgets.
library;

/// `formatFileSize` in `FileSizeDisplay.tsx`: bytes below 1 KiB as `N B`,
/// then KB, MB and GB (binary multiples) with one decimal, as JavaScript's
/// `toFixed(1)` prints them.
String formatFileSize(int bytes) {
  const kib = 1024;
  if (bytes == 0) return '0 B';
  if (bytes < kib) return '$bytes B';
  if (bytes < kib * kib) return '${_fixed1(bytes / kib)} KB';
  if (bytes < kib * kib * kib) return '${_fixed1(bytes / (kib * kib))} MB';
  return '${_fixed1(bytes / (kib * kib * kib))} GB';
}

// Dart's toStringAsFixed and JavaScript's toFixed agree for finite values in
// this range: both round the exact binary value half away from zero.
String _fixed1(double value) => value.toStringAsFixed(1);

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

/// `formatRelative` in `RelativeTimestamp.tsx`: `just now` under a minute
/// (and for times in the future), then minutes, hours, `yesterday`, days,
/// `last week` under 14 days, and after that the local date as
/// `toLocaleDateString(undefined, {month: 'short', day: 'numeric', year:
/// 'numeric'})` prints it in an en-US locale, `Oct 11, 2026`.
String formatRelativeTimestamp(DateTime time, {DateTime? now}) {
  final diffMs =
      (now ?? DateTime.now()).millisecondsSinceEpoch -
      time.millisecondsSinceEpoch;
  if (diffMs < 0) return 'just now';

  final seconds = diffMs ~/ 1000;
  final minutes = seconds ~/ 60;
  final hours = minutes ~/ 60;
  final days = hours ~/ 24;

  if (seconds < 60) return 'just now';
  if (minutes == 1) return '1 minute ago';
  if (minutes < 60) return '$minutes minutes ago';
  if (hours == 1) return '1 hour ago';
  if (hours < 24) return '$hours hours ago';
  if (days == 1) return 'yesterday';
  if (days < 7) return '$days days ago';
  if (days < 14) return 'last week';

  final local = time.toLocal();
  return '${_months[local.month - 1]} ${local.day}, ${local.year}';
}

/// The recent list's record summary (`countSummary` in `WelcomePage.tsx`):
/// the non-zero domain counts in 0.1.6's order joined by ` · `, or empty
/// when every count is zero.
String formatRecordSummary({
  required int items,
  required int abilities,
  required int classes,
  required int npcs,
  required int recipes,
  required int lootTables,
}) => [
  if (items != 0) '$items items',
  if (abilities != 0) '$abilities abilities',
  if (classes != 0) '$classes classes',
  if (npcs != 0) '$npcs NPCs',
  if (recipes != 0) '$recipes recipes',
  if (lootTables != 0) '$lootTables loot tables',
].join(' · ');
