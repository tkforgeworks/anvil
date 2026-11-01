import 'dart:io';

import 'package:path/path.dart' as p;

import 'log_rotation.dart';

enum LogLevel {
  error('ERROR'),
  warn('WARN '),
  info('INFO '),
  debug('DEBUG');

  const LogLevel(this.tag);

  /// Fixed-width tag as written in the file.
  final String tag;
}

/// The file logger, a port of 0.1.6's `app-logger.ts`: one `anvil.log` in
/// [directory], synchronous appends, rotation at 5 MB, and it never throws.
class AppLogger {
  AppLogger({required this.directory, required this.minimumLevel});

  final String directory;
  final LogLevel minimumLevel;

  static const fileName = 'anvil.log';

  String get filePath => p.join(directory, fileName);

  /// [error] is appended after an em dash; [stackTrace], when given, follows
  /// on the next lines (0.1.6 logged the error message only).
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    final detail = error == null ? '' : ' — $error';
    final stack = stackTrace == null ? '' : '\n$stackTrace'.trimRight();
    _write(LogLevel.error, '$message$detail$stack');
  }

  void warn(String message) => _write(LogLevel.warn, message);

  void info(String message) => _write(LogLevel.info, message);

  void debug(String message) => _write(LogLevel.debug, message);

  // Milliseconds only, like JS toISOString (Dart keeps microseconds on Linux).
  static String _timestamp() => DateTime.fromMillisecondsSinceEpoch(
    DateTime.now().millisecondsSinceEpoch,
    isUtc: true,
  ).toIso8601String();

  void _write(LogLevel level, String message) {
    if (level.index > minimumLevel.index) return;
    final line =
        '${_timestamp()} '
        '[${level.tag}] $message\n';
    try {
      final dir = Directory(directory);
      if (!dir.existsSync()) dir.createSync(recursive: true);
      rotateIfNeeded(filePath);
      File(filePath).writeAsStringSync(line, mode: FileMode.append);
    } catch (_) {
      // Logging must never crash the app.
    }
  }
}
