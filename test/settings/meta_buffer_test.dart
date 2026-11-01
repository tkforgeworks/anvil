// The cases of 0.1.6's `settings/__tests__/meta-buffer.test.ts` that
// concern the buffer itself. The commit cases (deletes, updates, adds, one
// reorder, refused deletes) belong to `MetaRepository.saveProjectSettings`
// and are covered by the core's repository tests.
import 'package:anvil/app/settings/project/meta_buffer.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_test/flutter_test.dart';

MetaRowDraft row(String id, String name) =>
    MetaRowDraft(id: id, displayName: name, exportKey: name.toLowerCase());

MetaRowDraft input(String name, String key) =>
    MetaRowDraft(id: '', displayName: name, exportKey: key);

void main() {
  final base = MetaBuffer(plainRowKind, [
    row('a', 'Alpha'),
    row('b', 'Beta'),
    row('c', 'Gamma'),
  ]);
  List<String> ids(MetaBuffer<MetaRowDraft> b) => [
    for (final r in b.toList()) r.id,
  ];

  group('in-memory mutations', () {
    test('position is the order: a loaded list keeps its rows as given', () {
      expect(ids(base), ['a', 'b', 'c']);
      expect(base.toList().first, same(base[0]));
    });

    test('appends with a client-side new: id at the end', () {
      final next = base.add(input('Delta', 'delta'));
      final added = next[3];
      expect(isNewMetaId(added.id), isTrue);
      expect(added.id, startsWith(newMetaIdPrefix));
      expect(next.length, 4);
      expect(added.displayName, 'Delta');
      expect(base.length, 3, reason: 'the buffer is immutable');
    });

    test('every new row gets its own id', () {
      final a = newMetaRowId();
      final b = newMetaRowId();
      expect(a, isNot(b));
      expect(isNewMetaId(a), isTrue);
    });

    test('rejects a duplicate export key on add and on update', () {
      expect(
        () => base.add(input('Other', 'beta')),
        throwsA(
          isA<MetaBufferConflict>().having(
            (e) => e.message,
            'message',
            'Export key "beta" is already used by "Beta".',
          ),
        ),
      );
      expect(
        () => base.update('a', (r) => r.copyWith(exportKey: 'gamma')),
        throwsA(
          isA<MetaBufferConflict>().having(
            (e) => e.message,
            'message',
            contains('gamma'),
          ),
        ),
      );
      // A row keeping its own key is fine.
      expect(
        () => base.update('a', (r) => r.copyWith(displayName: 'Alpha!')),
        returnsNormally,
      );
    });

    test('updating a row that is gone is refused', () {
      expect(
        () => base.update('zzz', (r) => r),
        throwsA(
          isA<MetaBufferConflict>().having(
            (e) => e.message,
            'message',
            'Item no longer exists.',
          ),
        ),
      );
    });

    test('edits a session-added row in place, and removing it leaves no '
        'trace', () {
      final withNew = base.add(input('Delta', 'delta'));
      final addedId = withNew[3].id;
      final edited = withNew.update(
        addedId,
        (r) => r.copyWith(displayName: 'Delta 2'),
      );
      expect(edited.byId(addedId)!.displayName, 'Delta 2');
      expect(edited.toList().where((r) => r.id == addedId), hasLength(1));
      final removed = edited.remove(addedId);
      expect(ids(removed), ['a', 'b', 'c']);
      expect(removed, base);
    });

    test('re-editing a persisted row overwrites rather than accumulates', () {
      final once = base.update('b', (r) => r.copyWith(displayName: 'B1'));
      final twice = once.update('b', (r) => r.copyWith(displayName: 'B2'));
      expect(twice.toList().where((r) => r.id == 'b'), hasLength(1));
      expect(twice[1].displayName, 'B2');
    });

    test('reorders a mix of persisted and new rows (move up by one)', () {
      final withNew = base.add(input('Delta', 'delta'));
      final addedId = withNew[3].id;
      final reordered = withNew.move(3, 2);
      expect(ids(reordered), ['a', 'b', addedId, 'c']);
    });

    test('a move outside the list changes nothing', () {
      expect(base.move(0, -1), same(base));
      expect(base.move(2, 3), same(base));
      expect(base.move(1, 1), same(base));
    });

    test('rarity and derived stat rows keep their own fields', () {
      final rarities = MetaBuffer(rarityRowKind, const [
        RarityRowDraft(
          id: 'r1',
          displayName: 'Common',
          exportKey: 'common',
          colorHex: '#FFFFFF',
        ),
      ]);
      final next = rarities.update(
        'r1',
        (r) => r.copyWith(colorHex: '#000000'),
      );
      expect(next[0].colorHex, '#000000');
      expect(
        () => rarities.add(
          const RarityRowDraft(
            id: '',
            displayName: 'Again',
            exportKey: 'common',
            colorHex: '#123456',
          ),
        ),
        throwsA(isA<MetaBufferConflict>()),
      );

      final derived =
          MetaBuffer(derivedStatRowKind, const <DerivedStatRowDraft>[]).add(
            const DerivedStatRowDraft(
              id: '',
              displayName: 'HP',
              exportKey: 'hp',
              formula: 'con * 10',
              outputType: DerivedStatOutputType.integer,
              roundingMode: RoundingMode.round,
            ),
          );
      expect(isNewMetaId(derived[0].id), isTrue);
      expect(derived[0].formula, 'con * 10');
    });
  });

  group('dirty detection (0.1.6 metaListDirty) is buffer equality', () {
    final two = MetaBuffer(plainRowKind, [row('a', 'Alpha'), row('b', 'Beta')]);

    test('is clean for an identical copy', () {
      expect(
        MetaBuffer(plainRowKind, [row('a', 'Alpha'), row('b', 'Beta')]),
        two,
      );
      expect(
        MetaBuffer(plainRowKind, [
          row('a', 'Alpha'),
          row('b', 'Beta'),
        ]).hashCode,
        two.hashCode,
      );
    });

    test('flags add, remove, edit and move', () {
      expect(two.add(input('New', 'new')), isNot(two));
      expect(two.remove('b'), isNot(two));
      expect(
        two.update('b', (r) => r.copyWith(displayName: 'Beta 2')),
        isNot(two),
      );
      expect(two.move(1, 0), isNot(two));
    });

    test('a row added then removed in the same session is clean', () {
      final withNew = two.add(input('Temp', 'temp'));
      expect(withNew.remove(withNew[2].id), two);
    });
  });

  group('slugifyMetaKey (0.1.6 slugify)', () {
    test('lower-cases and joins runs of other characters with _', () {
      expect(slugifyMetaKey('Max HP'), 'max_hp');
      expect(slugifyMetaKey('  Quest Item!! '), 'quest_item');
      expect(slugifyMetaKey('Crafting-Resource'), 'crafting_resource');
      expect(slugifyMetaKey('Épée'), 'p_e');
    });

    test('drops one leading and one trailing _ only, as 0.1.6', () {
      expect(slugifyMetaKey('__a__'), 'a');
      expect(slugifyMetaKey('!a!'), 'a');
    });

    test('every slug matches the export key pattern unless empty', () {
      for (final name in ['Strength', 'Alchemy Table', 'x9 y', 'Épée']) {
        expect(metaExportKeyPattern.hasMatch(slugifyMetaKey(name)), isTrue);
      }
      expect(metaExportKeyPattern.hasMatch('Has Space'), isFalse);
      expect(metaExportKeyPattern.hasMatch('UPPER'), isFalse);
      expect(metaExportKeyPattern.hasMatch('ok-key_1'), isTrue);
    });
  });
}
