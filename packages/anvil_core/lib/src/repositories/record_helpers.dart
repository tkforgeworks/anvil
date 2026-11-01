import 'package:meta/meta.dart';

import 'record_id.dart';

/// The slug 0.1.6's repositories built for a duplicate's export key: lower
/// case, every run of characters outside `a-z0-9` becomes one `-`, and a
/// leading and a trailing `-` are stripped (`class.repository.ts`).
@internal
String slugify(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-|-$'), '');

/// The display name of a duplicate: `<name> (Copy)`.
@internal
String copyDisplayName(String displayName) => '$displayName (Copy)';

/// The export key of a duplicate: the slug of its display name, `-` and the
/// first 8 characters of a new UUID, so repeated duplicates never collide on
/// the `UNIQUE` export key (design §7; every domain in 0.2.0).
@internal
String copyExportKey(String copyDisplayName) =>
    '${slugify(copyDisplayName)}-${newRecordId().substring(0, 8)}';
