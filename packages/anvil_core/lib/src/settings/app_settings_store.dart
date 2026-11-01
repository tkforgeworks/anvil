import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'app_settings.dart';

/// Reads and writes `app-settings.json` (0.1.6's `app-settings-service.ts`).
///
/// The app passes the file path (in the application support directory).
class AppSettingsStore {
  AppSettingsStore({required this.filePath});

  /// The conventional file name inside the application support directory.
  static const fileName = 'app-settings.json';

  final String filePath;

  /// The settings on disk. A missing or unparsable file gives the defaults;
  /// this never throws.
  AppSettings read() {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return const AppSettings();
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) return const AppSettings();
      return AppSettings.normalize(decoded);
    } catch (_) {
      return const AppSettings();
    }
  }

  /// Merges [partial] (JSON-shaped keys, a present key with a null value
  /// clears it) over the current file, normalises, writes and returns the
  /// result. Throws on an I/O failure, as 0.1.6 does.
  AppSettings write(Map<String, Object?> partial) {
    final merged = AppSettings.normalize({...read().toJson(), ...partial});
    _persist(merged);
    return merged;
  }

  /// Applies [change] to the current settings, normalises, writes, returns.
  AppSettings update(AppSettings Function(AppSettings current) change) {
    final merged = AppSettings.normalize(change(read()).toJson());
    _persist(merged);
    return merged;
  }

  void _persist(AppSettings settings) {
    final file = File(filePath);
    Directory(p.dirname(filePath)).createSync(recursive: true);
    // Two-space indent and no trailing newline, as JSON.stringify(x, null, 2).
    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(settings.toJson()),
    );
  }
}
