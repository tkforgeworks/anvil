/// Byte-for-byte comparison with a readable line diff, for the export
/// parity tests (copied from the ANVL-151 spike).
library;

/// Null when [expected] and [actual] are identical; otherwise a report with
/// the first differing offset and a line diff (`-` expected, `+` actual).
String? describeDifference(
  String expected,
  String actual, {
  int maxLines = 40,
}) {
  if (expected == actual) return null;
  var i = 0;
  while (i < expected.length &&
      i < actual.length &&
      expected.codeUnitAt(i) == actual.codeUnitAt(i)) {
    i++;
  }
  final out = StringBuffer()
    ..writeln(
      'Outputs differ: expected ${expected.length} chars, '
      'actual ${actual.length} chars; first difference at offset $i',
    )
    ..writeln('  expected: ${_excerpt(expected, i)}')
    ..writeln('  actual:   ${_excerpt(actual, i)}');
  final a = expected.split('\n'), b = actual.split('\n');
  final ops = _lineDiff(a, b);
  var shown = 0;
  for (final op in ops) {
    if (op.startsWith(' ')) continue;
    if (shown++ >= maxLines) {
      out.writeln('  ... (more differences)');
      break;
    }
    out.writeln('  $op');
  }
  return out.toString();
}

/// Number of lines that differ (removed + added) between the two texts.
int differingLineCount(String expected, String actual) => _lineDiff(
  expected.split('\n'),
  actual.split('\n'),
).where((op) => !op.startsWith(' ')).length;

String _excerpt(String s, int at) {
  final start = at - 20 < 0 ? 0 : at - 20;
  final end = at + 40 > s.length ? s.length : at + 40;
  return '"${_visible(s.substring(start, end))}"';
}

String _visible(String s) => s
    .replaceAll('\\', r'\\')
    .replaceAll('\n', r'\n')
    .replaceAll('\r', r'\r')
    .replaceAll('\t', r'\t');

List<String> _lineDiff(List<String> a, List<String> b) {
  final n = a.length, m = b.length;
  final lcs = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      lcs[i][j] = a[i] == b[j]
          ? lcs[i + 1][j + 1] + 1
          : (lcs[i + 1][j] >= lcs[i][j + 1] ? lcs[i + 1][j] : lcs[i][j + 1]);
    }
  }
  final ops = <String>[];
  var i = 0, j = 0;
  while (i < n && j < m) {
    if (a[i] == b[j]) {
      ops.add(' ${a[i]}');
      i++;
      j++;
    } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
      ops.add('-${_visible(a[i++])}');
    } else {
      ops.add('+${_visible(b[j++])}');
    }
  }
  while (i < n) {
    ops.add('-${_visible(a[i++])}');
  }
  while (j < m) {
    ops.add('+${_visible(b[j++])}');
  }
  return ops;
}
