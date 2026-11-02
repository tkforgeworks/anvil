/// The export key a create dialog proposes from a name.
library;

/// 0.1.6's `slugify` (`utils/slugify.ts`): lower case, every run of
/// characters outside `a-z0-9` one `-`, no leading or trailing `-`. The
/// core's `slugify` is `@internal`.
String slugifyExportKey(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-|-$'), '');
