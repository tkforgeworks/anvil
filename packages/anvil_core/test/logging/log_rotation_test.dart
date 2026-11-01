import 'dart:io';

import 'package:anvil_core/anvil_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void _fill(String path, int bytes, String char) =>
    File(path).writeAsStringSync(char * bytes);

void main() {
  late Directory tmp;
  late String log;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('anvil_rotation_');
    log = p.join(tmp.path, 'anvil.log');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('a missing file is a no-op', () {
    rotateIfNeeded(log);
    expect(tmp.listSync(), isEmpty);
  });

  test('one byte under the limit does not rotate', () {
    _fill(log, maxLogFileSize - 1, 'a');
    rotateIfNeeded(log);
    expect(File(log).existsSync(), isTrue);
    expect(File('$log.1').existsSync(), isFalse);
  });

  test('exactly the limit rotates', () {
    _fill(log, maxLogFileSize, 'a');
    rotateIfNeeded(log);
    expect(File(log).existsSync(), isFalse);
    expect(File('$log.1').lengthSync(), maxLogFileSize);
  });

  test('keeps three backups, oldest dropped, order preserved', () {
    for (final c in ['a', 'b', 'c', 'd']) {
      _fill(log, maxLogFileSize, c);
      rotateIfNeeded(log);
    }
    expect(File(log).existsSync(), isFalse);
    String head(String f) =>
        String.fromCharCode(File(f).readAsBytesSync().first);
    expect(head('$log.1'), 'd');
    expect(head('$log.2'), 'c');
    expect(head('$log.3'), 'b');
    expect(File('$log.4').existsSync(), isFalse);
  });
}
