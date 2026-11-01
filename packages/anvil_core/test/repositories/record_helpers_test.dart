import 'package:anvil_core/src/repositories/record_helpers.dart';
import 'package:test/test.dart';

void main() {
  group('slugify', () {
    test('lower-cases and collapses non-alphanumeric runs to one dash', () {
      expect(slugify('Iron Sword (Copy)'), 'iron-sword-copy');
      expect(slugify("  Fancy!! Name's  "), 'fancy-name-s');
    });

    test('keeps digits and strips the edge dashes', () {
      expect(slugify('-Potion 2-'), 'potion-2');
      expect(slugify('___'), '');
    });
  });

  test('copyDisplayName appends (Copy)', () {
    expect(copyDisplayName('Warrior'), 'Warrior (Copy)');
  });

  test('copyExportKey is the slug plus 8 UUID characters', () {
    final key = copyExportKey('Warrior (Copy)');
    expect(key, matches(RegExp(r'^warrior-copy-[0-9a-f]{8}$')));
    expect(copyExportKey('Warrior (Copy)'), isNot(key));
  });
}
