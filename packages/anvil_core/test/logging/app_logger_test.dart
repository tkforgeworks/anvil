import 'dart:io';

import 'package:anvil_core/anvil_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late String dir;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('anvil_logger_');
    dir = p.join(tmp.path, 'logs');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  String content() => File(p.join(dir, 'anvil.log')).readAsStringSync();

  test('writes <ISO ms UTC> [TAG] message, padded tags, creating the dir', () {
    AppLogger(directory: dir, minimumLevel: LogLevel.debug)
      ..error('e')
      ..warn('w')
      ..info('i')
      ..debug('d');
    final lines = content().trimRight().split('\n');
    final ts = r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z';
    expect(lines[0], matches(RegExp('^$ts \\[ERROR\\] e\$')));
    expect(lines[1], matches(RegExp('^$ts \\[WARN \\] w\$')));
    expect(lines[2], matches(RegExp('^$ts \\[INFO \\] i\$')));
    expect(lines[3], matches(RegExp('^$ts \\[DEBUG\\] d\$')));
    expect(content().endsWith('\n'), isTrue);
  });

  test('error appends the error after an em dash', () {
    AppLogger(
      directory: dir,
      minimumLevel: LogLevel.info,
    ).error('boom', StateError('bad'));
    expect(content(), contains('[ERROR] boom — Bad state: bad\n'));
  });

  test('error with a stack trace puts it on following lines', () {
    AppLogger(
      directory: dir,
      minimumLevel: LogLevel.info,
    ).error('boom', 'x', StackTrace.fromString('#0 here'));
    expect(content(), contains('boom — x\n#0 here\n'));
  });

  test('minimum level filters lower-priority lines', () {
    AppLogger(directory: dir, minimumLevel: LogLevel.warn)
      ..debug('d')
      ..info('i')
      ..warn('w')
      ..error('e');
    final text = content();
    expect(text, isNot(contains('DEBUG')));
    expect(text, isNot(contains('INFO ')));
    expect(text, contains('[WARN ] w'));
    expect(text, contains('[ERROR] e'));
  });

  test('rotates before appending at 5 MB, not one byte under', () {
    Directory(dir).createSync(recursive: true);
    final file = File(p.join(dir, 'anvil.log'));
    final logger = AppLogger(directory: dir, minimumLevel: LogLevel.info);

    file.writeAsStringSync('x' * (maxLogFileSize - 1));
    logger.info('under');
    expect(File('${file.path}.1').existsSync(), isFalse);
    expect(file.readAsStringSync(), endsWith('under\n'));

    file.writeAsStringSync('y' * maxLogFileSize);
    logger.info('over');
    expect(File('${file.path}.1').lengthSync(), maxLogFileSize);
    expect(file.readAsStringSync(), contains('[INFO ] over'));
    expect(file.lengthSync(), lessThan(200));
  });

  test('never throws when the directory is unwritable', () {
    final blocker = p.join(tmp.path, 'blocker');
    File(blocker).writeAsStringSync('a file, not a directory');
    final logger = AppLogger(directory: blocker, minimumLevel: LogLevel.debug);
    expect(
      () => logger.error('x', Exception('y'), StackTrace.current),
      returnsNormally,
    );
    expect(() => logger.info('x'), returnsNormally);
  });

  group('anonymizePath', () {
    final s = Platform.pathSeparator;
    test('keeps the last two segments', () {
      expect(anonymizePath('/home/tim/Anvil/db/x.anvil'), '…${s}db${s}x.anvil');
    });
    test('splits Windows separators', () {
      expect(
        anonymizePath(r'C:\Users\tim\Anvil\x.anvil'),
        '…${s}Anvil${s}x.anvil',
      );
    });
    test('short paths are returned unchanged', () {
      expect(anonymizePath('x.anvil'), 'x.anvil');
      expect(anonymizePath('a/b'), 'a/b');
    });
  });
}
