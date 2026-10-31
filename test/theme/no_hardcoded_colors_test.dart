import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The renderer colour convention (`.claude/CLAUDE.md`): widgets never write
/// a colour literal. Every colour comes from the theme (`context.colors`,
/// `context.forge`, `context.anvil`), so dark, light and custom modes all
/// apply. Only `lib/app/theme/anvil_palette.dart` holds literals: the
/// Electron palette the themes are built from. `Colors.transparent` paints
/// nothing and is allowed anywhere. `color_math.dart` builds `Color`s from
/// parsed theme-file channels, which the regex cannot tell from a literal.
void main() {
  const allowed = {'anvil_palette.dart', 'color_math.dart'};
  final literal = RegExp(
    r'\bColor(\.from[A-Z]+)?\(|\bColors\.(?!transparent\b)',
  );

  test('no colour literals in lib/ outside the palette', () {
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !allowed.contains(f.uri.pathSegments.last));
    for (final file in files) {
      for (final (i, line) in file.readAsLinesSync().indexed) {
        final code = line.split('//').first;
        if (literal.hasMatch(code)) {
          offenders.add('${file.path}:${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('the check itself catches a literal', () {
    expect(literal.hasMatch('color: Color(0xFF3B82F6),'), isTrue);
    expect(literal.hasMatch('Color.fromARGB(255, 0, 0, 0)'), isTrue);
    expect(literal.hasMatch('color: Colors.white,'), isTrue);
    expect(literal.hasMatch('color: Colors.transparent,'), isFalse);
    expect(literal.hasMatch('final Color? color;'), isFalse);
    expect(literal.hasMatch('Color.lerp(a, b, t)'), isFalse);
    expect(literal.hasMatch('Color.alphaBlend(a, b)'), isFalse);
  });
}
