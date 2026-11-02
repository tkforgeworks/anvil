import 'package:anvil/app/editor/export_key_slug.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lower-cases and joins runs of other characters with one dash', () {
    expect(slugifyExportKey('Iron Sword!'), 'iron-sword');
    expect(slugifyExportKey('  Fire--Ball  '), 'fire-ball');
  });

  test('characters outside a-z0-9 leave nothing', () {
    expect(slugifyExportKey('ÄÖ'), '');
  });
}
