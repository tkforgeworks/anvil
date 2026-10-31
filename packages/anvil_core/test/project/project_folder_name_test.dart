import 'package:anvil_core/anvil_core.dart';
import 'package:test/test.dart';

void main() {
  group('sanitizeFolderName', () {
    test('keeps an ordinary name unchanged', () {
      expect(sanitizeFolderName('My Game'), 'My Game');
    });

    test('replaces each run of forbidden characters with one underscore', () {
      expect(sanitizeFolderName('a/b:c'), 'a_b_c');
      expect(sanitizeFolderName('a//\\b'), 'a_b');
      expect(sanitizeFolderName('a<b>c"d|e?f*g'), 'a_b_c_d_e_f_g');
      expect(sanitizeFolderName('tab\there'), 'tab_here');
    });

    test('strips leading and trailing underscores and whitespace', () {
      expect(sanitizeFolderName('_name_'), 'name');
      expect(sanitizeFolderName('/name/'), 'name');
      expect(sanitizeFolderName('  name  '), 'name');
    });

    test('returns an empty string when nothing usable is left', () {
      expect(sanitizeFolderName('///'), '');
      expect(sanitizeFolderName(''), '');
    });
  });
}
