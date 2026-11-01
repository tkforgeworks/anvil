/// The pure buffer behind the Project Settings meta lists (ANVL-121),
/// ported from 0.1.6's `settings/meta-buffer.ts`.
///
/// The dialog holds stats, rarities, crafting stations, crafting
/// specializations and derived stats in [MetaBuffer]s and only writes on
/// Save, when the buffers become one `ProjectSettingsDraft` for
/// `MetaRepository.saveProjectSettings`. 0.1.6's `commitMetaList` (the
/// replay of deletes, updates, adds and one reorder) lives in the core's
/// `saveProjectSettings`; what is left here is the id scheme for rows not
/// yet persisted and the in-memory mutations.
///
/// A row's position in the buffer is its `sort_order`, so 0.1.6's
/// `normalizeOrder` and the swap payload of `reorderBuffer` reduce to list
/// moves, and dirty detection is list equality over the value-equal row
/// drafts.
library;

import 'dart:math';

import 'package:anvil_core/anvil_core.dart';

/// How a buffer reads and rewrites one row type. The three instances are
/// constants, so buffers of the same kind compare equal by their rows.
abstract interface class MetaRowKind<T> {
  String idOf(T row);
  String displayNameOf(T row);
  String exportKeyOf(T row);
  T withId(T row, String id);
}

final class _PlainRowKind implements MetaRowKind<MetaRowDraft> {
  const _PlainRowKind();
  @override
  String idOf(MetaRowDraft row) => row.id;
  @override
  String displayNameOf(MetaRowDraft row) => row.displayName;
  @override
  String exportKeyOf(MetaRowDraft row) => row.exportKey;
  @override
  MetaRowDraft withId(MetaRowDraft row, String id) => row.copyWith(id: id);
}

final class _RarityRowKind implements MetaRowKind<RarityRowDraft> {
  const _RarityRowKind();
  @override
  String idOf(RarityRowDraft row) => row.id;
  @override
  String displayNameOf(RarityRowDraft row) => row.displayName;
  @override
  String exportKeyOf(RarityRowDraft row) => row.exportKey;
  @override
  RarityRowDraft withId(RarityRowDraft row, String id) => row.copyWith(id: id);
}

final class _DerivedStatRowKind implements MetaRowKind<DerivedStatRowDraft> {
  const _DerivedStatRowKind();
  @override
  String idOf(DerivedStatRowDraft row) => row.id;
  @override
  String displayNameOf(DerivedStatRowDraft row) => row.displayName;
  @override
  String exportKeyOf(DerivedStatRowDraft row) => row.exportKey;
  @override
  DerivedStatRowDraft withId(DerivedStatRowDraft row, String id) =>
      row.copyWith(id: id);
}

/// Stats, crafting stations and crafting specializations.
const MetaRowKind<MetaRowDraft> plainRowKind = _PlainRowKind();
const MetaRowKind<RarityRowDraft> rarityRowKind = _RarityRowKind();
const MetaRowKind<DerivedStatRowDraft> derivedStatRowKind =
    _DerivedStatRowKind();

final _random = Random.secure();

/// A fresh client-side id for a row added in this session: the core's
/// `newMetaIdPrefix` (`new:`) and 32 random hex digits, as 0.1.6's
/// `newMetaId()` used `new:` and a UUID.
String newMetaRowId() {
  final hex = StringBuffer(newMetaIdPrefix);
  for (var i = 0; i < 16; i++) {
    hex.write(_random.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return hex.toString();
}

/// A buffer edit refused with 0.1.6's message: a clashing export key or a
/// row that is gone.
final class MetaBufferConflict implements Exception {
  const MetaBufferConflict(this.message);

  final String message;

  @override
  String toString() => 'MetaBufferConflict: $message';
}

/// One buffered meta list: an immutable, value-equal ordered list of rows.
/// Every mutation returns a new buffer.
final class MetaBuffer<T> {
  MetaBuffer(this.kind, Iterable<T> rows) : _rows = List.unmodifiable(rows);

  final MetaRowKind<T> kind;
  final List<T> _rows;

  /// The rows in order, for the draft; position is `sort_order`.
  List<T> toList() => _rows;

  int get length => _rows.length;

  bool get isEmpty => _rows.isEmpty;

  T operator [](int index) => _rows[index];

  int indexOf(String id) => _rows.indexWhere((r) => kind.idOf(r) == id);

  /// The row with [id], or null.
  T? byId(String id) {
    final i = indexOf(id);
    return i == -1 ? null : _rows[i];
  }

  /// Appends [row] under a new `new:` id ([id] when given, for tests) and
  /// returns the buffer with it last. Throws [MetaBufferConflict] when
  /// another row already has its export key (0.1.6
  /// `assertUniqueExportKey`).
  MetaBuffer<T> add(T row, {String? id}) {
    final added = kind.withId(row, id ?? newMetaRowId());
    _assertUniqueExportKey(kind.exportKeyOf(added));
    return MetaBuffer(kind, [..._rows, added]);
  }

  /// Replaces the row with [id] by [apply] of it, keeping its id and
  /// position. Throws [MetaBufferConflict] when the row is gone or the new
  /// export key belongs to another row; a row keeping its own key is fine.
  MetaBuffer<T> update(String id, T Function(T row) apply) {
    final index = indexOf(id);
    if (index == -1) throw const MetaBufferConflict('Item no longer exists.');
    final updated = kind.withId(apply(_rows[index]), id);
    _assertUniqueExportKey(kind.exportKeyOf(updated), exceptId: id);
    return MetaBuffer(kind, [
      for (var i = 0; i < _rows.length; i++) i == index ? updated : _rows[i],
    ]);
  }

  /// Drops the row with [id]; unchanged when there is none.
  MetaBuffer<T> remove(String id) =>
      MetaBuffer(kind, _rows.where((r) => kind.idOf(r) != id));

  /// Moves the row at [from] to [to] (0.1.6's move up/down swapped
  /// neighbours, which is a move by one). Out-of-range indexes leave the
  /// buffer unchanged.
  MetaBuffer<T> move(int from, int to) {
    if (from < 0 || from >= _rows.length || to < 0 || to >= _rows.length) {
      return this;
    }
    if (from == to) return this;
    final next = List.of(_rows);
    final row = next.removeAt(from);
    next.insert(to, row);
    return MetaBuffer(kind, next);
  }

  void _assertUniqueExportKey(String exportKey, {String? exceptId}) {
    for (final r in _rows) {
      if (kind.idOf(r) != exceptId && kind.exportKeyOf(r) == exportKey) {
        throw MetaBufferConflict(
          'Export key "$exportKey" is already used by '
          '"${kind.displayNameOf(r)}".',
        );
      }
    }
  }

  @override
  bool operator ==(Object other) {
    if (other is! MetaBuffer<T> || !identical(other.kind, kind)) return false;
    if (other._rows.length != _rows.length) return false;
    for (var i = 0; i < _rows.length; i++) {
      if (other._rows[i] != _rows[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(kind, Object.hashAll(_rows));

  @override
  String toString() => 'MetaBuffer($_rows)';
}

/// 0.1.6's `slugify` for meta export keys (`MetaListSection.tsx`,
/// `ProjectSettingsTab.tsx`): lower-cased, every run of characters other
/// than `a-z0-9` becomes `_`, and one leading and one trailing `_` are
/// dropped.
String slugifyMetaKey(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_|_$'), '');

/// The shape a new or changed meta export key must have. 0.1.6 enforced no
/// pattern (only a non-empty trimmed key); 0.2.0 refuses anything else for
/// keys it writes, while keys already stored are kept as they are.
final RegExp metaExportKeyPattern = RegExp(r'^[a-z0-9_-]+$');

/// The message for an export key outside [metaExportKeyPattern].
const String metaExportKeyPatternMessage =
    'Export key may only contain lowercase letters, digits, "_" and "-".';
