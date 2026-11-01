import 'package:test/test.dart';

/// Registers the value-equality laws every draft must keep.
///
/// - [build] makes the base value afresh on every call, from new
///   collections, so equality is never identity.
/// - [buildInOtherOrder] makes the same content with every keyed collection
///   filled in a different insertion order.
/// - [changes] change one field each, through `copyWith`.
/// - [reorders] reorder one ordered junction list each, through `copyWith`.
/// - [copyWithNoArgs] calls `copyWith()` with no arguments.
/// - [mutations] try to mutate one collection of a value each.
void draftLaws<T extends Object>({
  required T Function() build,
  required T Function() buildInOtherOrder,
  required Map<String, T Function(T)> changes,
  required Map<String, T Function(T)> reorders,
  required T Function(T) copyWithNoArgs,
  Map<String, void Function(T)> mutations = const {},
}) {
  test('values with identical content are equal, with equal hashCodes', () {
    final a = build();
    final b = build();
    expect(identical(a, b), isFalse);
    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
  });

  test('keyed collections compare by content, not insertion order', () {
    final a = build();
    final b = buildInOtherOrder();
    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
  });

  test('copyWith() with no arguments gives an equal value', () {
    final a = build();
    final b = copyWithNoArgs(a);
    expect(b, equals(a));
    expect(b.hashCode, a.hashCode);
  });

  group('changing one field makes the value unequal', () {
    for (final MapEntry(key: name, value: change) in changes.entries) {
      test(name, () {
        final original = build();
        final changed = change(original);
        expect(changed, isNot(equals(original)));
        expect(original, equals(build()), reason: 'copyWith left original');
      });
    }
  });

  group('reordering a junction list makes the value unequal', () {
    for (final MapEntry(key: name, value: reorder) in reorders.entries) {
      test(name, () {
        final original = build();
        final reordered = reorder(original);
        expect(reordered, isNot(equals(original)));
        expect(original, equals(build()), reason: 'copyWith left original');
      });
    }
  });

  group('collections are unmodifiable', () {
    for (final MapEntry(key: name, value: mutate) in mutations.entries) {
      test(name, () {
        final value = build();
        expect(() => mutate(value), throwsUnsupportedError);
        expect(value, equals(build()));
      });
    }
  });
}

/// [list] with its first two elements swapped.
List<E> swapFirstTwo<E>(List<E> list) => [list[1], list[0], ...list.skip(2)];
