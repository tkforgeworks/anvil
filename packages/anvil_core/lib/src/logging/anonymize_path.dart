import 'dart:io';

/// Shortens [fullPath] to its last two segments, prefixed with an ellipsis
/// (`…/database/x.anvil`), so logs carry no user directory names. Splits on
/// both `/` and `\`; joins with the platform separator as 0.1.6 did.
String anonymizePath(String fullPath) {
  final segments = fullPath.split(RegExp(r'[\\/]'));
  if (segments.length <= 2) return fullPath;
  final sep = Platform.pathSeparator;
  return '…$sep${segments.sublist(segments.length - 2).join(sep)}';
}
