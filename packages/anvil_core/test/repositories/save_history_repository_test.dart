import 'package:anvil_core/anvil_core.dart';
import 'package:test/test.dart';

import '../db/support/fixture_copy.dart';

const String _ironSword = '6069c26a-d758-4981-b29b-eed2c95fe6f3';

/// The two rows 0.1.6 wrote into the fixture, newest first.
const List<SaveHistoryEntry> _electronRows = [
  SaveHistoryEntry(
    id: 2,
    savedAt: '2026-10-30T18:05:00Z',
    description: 'Warrior class changed, Iron Sword item changed',
    isAutoSave: true,
  ),
  SaveHistoryEntry(
    id: 1,
    savedAt: '2026-10-30T18:00:00Z',
    description: 'Project created',
    isAutoSave: false,
  ),
];

void main() {
  final fixture = FixtureCopy.setUpEach();

  late ProjectDatabase db;
  late SaveHistoryRepository repo;

  setUp(() {
    db = fixture().openFixture();
    repo = SqliteSaveHistoryRepository(db);
  });

  test('recent returns the two Electron rows newest first', () async {
    expect(await repo.recent(), _electronRows);
    expect(await repo.recent(limit: 1), [_electronRows.first]);
  });

  test('a Dart save adds a third row at the top', () async {
    final items = SqliteItemRepository(db);
    await items.save(_ironSword, await items.load(_ironSword));

    final recent = await repo.recent();
    expect(recent, hasLength(3));
    expect(recent.sublist(1), _electronRows);
    final newest = recent.first;
    expect(newest.id, 3);
    expect(newest.description, 'Iron Sword - Item changed');
    expect(newest.isAutoSave, isFalse);
    expect(
      newest.savedAt,
      matches(RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$')),
    );
    expect(newest.savedAt.compareTo(_electronRows.first.savedAt), 1);
  });
}
