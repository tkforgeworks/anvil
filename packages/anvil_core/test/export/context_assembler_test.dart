// The export context against Electron 0.1.6 (test/fixtures/context-*.json),
// assembled from a real SQLite read of sample-0.1.6.anvil.
import 'package:anvil_core/anvil_core.dart';
import 'package:anvil_core/src/export/js_compat.dart' show jsonStringify;
import 'package:test/test.dart';

import '../db/support/fixture_copy.dart';
import 'support/fixtures.dart';

typedef _Json = Map<String, Object?>;

/// The two items of context-selection-items.json (Iron Sword, Healing
/// Potion), deliberately not in display-name order.
const List<String> _selectedItems = [
  '6069c26a-d758-4981-b29b-eed2c95fe6f3',
  'a4b66c54-05d2-4007-bed7-8f13bee1f087',
];

/// The soft-deleted Cursed Dagger.
const String _deletedItem = '436aa413-a7d6-4671-b067-28139fc1fa05';

void main() {
  final copy = FixtureCopy.setUpEach();

  _Json assemble(ExportScope scope) {
    final db = copy().track(ProjectDatabase.openReadOnly(copy().copyFixture()));
    return db.read((tx) => assembleExportContext(tx, scope));
  }

  group('full scope', () {
    test('deep-equals context-full.json', () {
      expect(assemble(const ExportScope.full()), fullContext());
    });

    test('encodes byte-identical to context-full.json', () {
      // JSON.stringify(ctx, null, 2) wrote the fixture; the REAL columns
      // must print as JavaScript numbers (12, not 12.0).
      expectSameBytes(
        jsonStringify(assemble(const ExportScope.full()), indent: 2)!,
        readFixture('context-full.json'),
      );
    });

    test('REAL columns arrive as doubles, as the presets expect', () {
      final ctx = assemble(const ExportScope.full());
      final cls = (ctx['classes'] as List).cast<_Json>().first;
      expect(cls['resource_multiplier'], isA<double>());
      final ability = (ctx['abilities'] as List).cast<_Json>().first;
      expect(ability['resource_cost'], isA<double>());
      expect(ability['cooldown'], isA<double>());
      expect((ctx['project'] as _Json)['max_level'], isA<int>());
    });
  });

  group('selection scope', () {
    test('deep-equals and encodes as context-selection-items.json', () {
      final ctx = assemble(
        ExportScope.selection(ExportDomain.items, _selectedItems),
      );
      expect(ctx, jsonFixture('context-selection-items.json'));
      expectSameBytes(
        jsonStringify(ctx, indent: 2)!,
        readFixture('context-selection-items.json'),
      );
    });

    test('soft-deleted and unknown ids are left out', () {
      final ctx = assemble(
        ExportScope.selection(ExportDomain.items, [
          _selectedItems.first,
          _deletedItem,
          'no-such-item',
        ]),
      );
      expect(
        (ctx['items'] as List).cast<_Json>().map((i) => i['display_name']),
        ['Iron Sword'],
      );
    });

    test('an empty selection exports no records, as 0.1.6', () {
      final ctx = assemble(ExportScope.selection(ExportDomain.items, []));
      for (final d in ExportDomain.values) {
        expect(ctx[d.contextKey], isEmpty, reason: d.contextKey);
      }
      expect(ctx['project'], fullContext()['project']);
      expect(ctx['meta'], fullContext()['meta']);
    });
  });

  for (final domain in ExportDomain.values) {
    test('domain scope ${domain.name}: that array only', () {
      final full = fullContext();
      final ctx = assemble(ExportScope.domain(domain));
      expect(ctx.keys, full.keys);
      expect(ctx['project'], full['project']);
      expect(ctx['meta'], full['meta']);
      for (final d in ExportDomain.values) {
        expect(
          ctx[d.contextKey],
          d == domain ? full[d.contextKey] : isEmpty,
          reason: d.contextKey,
        );
      }
      expect(full[domain.contextKey], isNotEmpty);
    });
  }

  test('soft-deleted items are not in the full context', () {
    final ids = (assemble(const ExportScope.full())['items'] as List)
        .cast<_Json>()
        .map((i) => i['id']);
    expect(ids, isNot(contains(_deletedItem)));
  });
}
