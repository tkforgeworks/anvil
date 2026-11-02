import 'package:anvil/app/lists/list_columns.dart';
import 'package:anvil/app/lists/list_domain_adapter.dart';
import 'package:anvil/app/lists/record_list_controller.dart';
import 'package:anvil/app/shell/shell_domain.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../dialogs/fakes.dart' show copyFixture;
import 'sqlite_recipe_list_adapter.dart';

void main() {
  test('softDelete moves a fixture recipe from active to archived and bumps '
      'the write epoch once', () async {
    final db = ProjectDatabase.open(copyFixture());
    addTearDown(db.close);
    final adapter = SqliteRecipeListAdapter(SqliteRecipeRepository(db));
    final container = ProviderContainer(
      overrides: [
        lifecycleRepositoryProvider.overrideWithValue(
          SqliteLifecycleRepository(db),
        ),
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    final provider = recordListProvider(adapter);
    expect(recordListProvider(adapter), same(provider));
    container.listen(provider, (_, _) {});

    final before = await container.read(provider.future);
    expect(before.mode, ListViewMode.active);
    expect(before.rows, isNotEmpty);
    expect(before.lastError, isNull);
    final target = before.visible.first;
    final activeCount = before.rows.length;

    await container.read(provider.notifier).softDelete(target.id);
    expect(container.read(writeEpochProvider), 1);

    final after = await container.read(provider.future);
    expect(after.lastError, isNull);
    expect(after.rows.length, activeCount - 1);
    expect(after.rows.map((r) => r.id), isNot(contains(target.id)));

    container.read(provider.notifier).setMode(ListViewMode.archived);
    final archived = await container.read(provider.future);
    expect(archived.mode, ListViewMode.archived);
    final row = archived.rows.singleWhere((r) => r.id == target.id);
    expect(row.deletedAt, isNotNull);

    // A foreign key refusal arrives as the error line, not a throw.
    final itemAdapter = _ItemAdapter(SqliteItemRepository(db));
    final itemProvider = recordListProvider(itemAdapter);
    container.listen(itemProvider, (_, _) {});
    await container.read(itemProvider.future);
    // The archived recipe still names its output item.
    await container.read(itemProvider.notifier).hardDelete(target.outputItemId);
    expect(container.read(writeEpochProvider), 1);
    expect(
      container.read(itemProvider).value!.lastError,
      contains('FOREIGN KEY'),
    );
  });

  test('formatDeletedAt renders 0.1.6\'s en-US local time', () {
    final local = DateTime.utc(2026, 10, 31, 14, 5, 9).toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final expected =
        '${local.month}/${local.day}/${local.year}, '
        '$hour:05:09 ${local.hour < 12 ? 'AM' : 'PM'}';
    expect(formatDeletedAt('2026-10-31 14:05:09'), expected);
    expect(formatDeletedAt('2026-10-31T14:05:09.000Z'), expected);
    expect(formatDeletedAt(null), '—');
    expect(formatDeletedAt('not a date'), 'not a date');
  });
}

class _ItemAdapter
    with ListAdapterDefaults<ItemRecord>
    implements ListDomainAdapter<ItemRecord> {
  _ItemAdapter(this.repository);

  final ItemRepository repository;

  @override
  ShellDomain get domain => ShellDomain.items;

  @override
  Future<List<ItemRecord>> list(RecordListMode mode) =>
      repository.list(mode: mode);

  @override
  String idOf(ItemRecord row) => row.id;

  @override
  String displayNameOf(ItemRecord row) => row.displayName;

  @override
  String exportKeyOf(ItemRecord row) => row.exportKey;

  @override
  String? deletedAtOf(ItemRecord row) => row.deletedAt;

  @override
  List<ListColumn<ItemRecord>> get columns => [
    ListColumn(label: 'Category', cell: (_, row) => Text(row.itemCategoryId)),
  ];

  @override
  Future<void> softDelete(String id) => repository.softDelete(id);

  @override
  Future<void> restore(String id) => repository.restore(id);

  @override
  Future<void> hardDelete(String id) => repository.hardDelete(id);

  @override
  Future<ItemRecord?> duplicate(String id) => repository.duplicate(id);
}
