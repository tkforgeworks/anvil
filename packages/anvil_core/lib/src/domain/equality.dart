/// Value-equality helpers shared by the domain types.
///
/// Hand-written on purpose: `package:collection` is not a dependency of the
/// core. Not exported from the `domain.dart` barrel, so these names never
/// clash with the same-named helpers of the app's UI toolkit.
library;

import 'package:meta/meta.dart';

/// Placeholder default for nullable `copyWith` parameters, so that passing
/// `null` explicitly clears a field while omitting it keeps the old value.
@internal
const Object unset = _Unset();

class _Unset {
  const _Unset();
}

/// Element-wise equality: same length, equal elements at every index.
@internal
bool listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Content equality: the same keys with equal values, in any insertion order.
/// A key mapped to `null` is not the same as a missing key.
@internal
bool mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key)) return false;
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

/// Order-sensitive hash agreeing with [listEquals].
@internal
int listHash<T>(List<T> list) => Object.hashAll(list);

/// Order-insensitive hash agreeing with [mapEquals].
@internal
int mapHash<K, V>(Map<K, V> map) => Object.hashAllUnordered(
  map.entries.map((entry) => Object.hash(entry.key, entry.value)),
);

/// Deep equality for decoded JSON values (maps, lists, scalars), with maps
/// compared by content and lists by position.
@internal
bool jsonEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!jsonEquals(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!jsonEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map || b is Map || a is List || b is List) return false;
  return a == b;
}

/// Hash agreeing with [jsonEquals].
@internal
int jsonHash(Object? value) {
  if (value is Map) {
    return Object.hashAllUnordered(
      value.entries.map((e) => Object.hash(e.key, jsonHash(e.value))),
    );
  }
  if (value is List) return Object.hashAll(value.map(jsonHash));
  return value.hashCode;
}

/// A deeply unmodifiable copy of a decoded JSON value. Map key order is kept.
@internal
Object? freezeJson(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.unmodifiable({
      for (final e in value.entries) e.key as String: freezeJson(e.value),
    });
  }
  if (value is List) return List<Object?>.unmodifiable(value.map(freezeJson));
  return value;
}

/// [freezeJson] for a JSON object.
@internal
Map<String, Object?> freezeJsonObject(Map<String, Object?> value) =>
    freezeJson(value) as Map<String, Object?>;
