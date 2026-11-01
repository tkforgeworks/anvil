import 'package:anvil/app/menu/external_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('openExternal hands only absolute https URLs to the launcher', () async {
    final launched = <Uri>[];
    Future<bool> launch(Uri uri) async {
      launched.add(uri);
      return true;
    }

    for (final refused in [
      'http://x',
      'http://anvil.tkforgeworks.com/docs',
      'file:///etc/passwd',
      'javascript:alert(1)',
      'https:///no-host',
      'anvil.tkforgeworks.com/docs',
      '',
      '::not a url',
    ]) {
      expect(await openExternal(refused, launch: launch), isFalse);
    }
    expect(launched, isEmpty);

    expect(await openExternal(documentationUrl, launch: launch), isTrue);
    expect(launched, [Uri.parse('https://anvil.tkforgeworks.com/docs')]);
  });

  test('a launcher failure is reported as not opened', () async {
    expect(
      await openExternal(
        reportBugUrl,
        launch: (_) async => throw StateError('no browser'),
      ),
      isFalse,
    );
    expect(
      await openExternal(reportBugUrl, launch: (_) async => false),
      isFalse,
    );
  });
}
