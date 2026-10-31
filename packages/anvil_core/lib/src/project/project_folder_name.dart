/// Turns a project name into a folder name that is valid on Windows and
/// Linux.
///
/// Runs of characters that Windows forbids in file names (`< > : " / \ | ? *`
/// and control characters) collapse into a single underscore, then leading
/// and trailing underscores and surrounding whitespace are removed. Port of
/// `sanitizeFolderName` in the Electron `src/main/project/project-folder.ts`;
/// the result must stay identical so folders created by either app match.
///
/// Returns an empty string when nothing usable is left, which callers treat
/// as an invalid project name.
String sanitizeFolderName(String value) => value
    .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '')
    .trim();
