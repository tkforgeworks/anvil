import 'dart:io';

/// Size at which the log file rotates (0.1.6: 5 MB).
const maxLogFileSize = 5 * 1024 * 1024;

/// Rotated files kept: `anvil.log.1` to `anvil.log.3`.
const maxLogRotations = 3;

/// Rotates [filePath] when it has reached [maxLogFileSize]: drops `.3`,
/// shifts `.2` to `.3` and `.1` to `.2`, then moves the file to `.1`.
/// Never throws.
void rotateIfNeeded(String filePath) {
  try {
    final file = File(filePath);
    if (!file.existsSync()) return;
    if (file.lengthSync() < maxLogFileSize) return;

    final oldest = File('$filePath.$maxLogRotations');
    if (oldest.existsSync()) oldest.deleteSync();

    for (var i = maxLogRotations - 1; i >= 1; i--) {
      final from = File('$filePath.$i');
      if (from.existsSync()) from.renameSync('$filePath.${i + 1}');
    }
    file.renameSync('$filePath.1');
  } catch (_) {
    // Rotation must never crash the app.
  }
}
