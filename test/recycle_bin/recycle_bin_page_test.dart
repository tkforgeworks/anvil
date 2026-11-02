import 'package:anvil/app/lists/bulk_dialogs.dart';
import 'package:anvil/app/lists/list_columns.dart';
import 'package:anvil/app/lists/record_table.dart';
import 'package:anvil/app/lists/undo_snackbar.dart';
import 'package:anvil/app/recycle_bin/empty_trash_dialog.dart';
import 'package:anvil/app/recycle_bin/recycle_bin_page.dart';
import 'package:anvil/app/recycle_bin/trash_group_table.dart';
import 'package:anvil/app/shell/shell_domain.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil/app/theme/anvil_metrics.dart';
import 'package:anvil/app/theme/anvil_theme.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

final linux = TargetPlatformVariant.only(TargetPlatform.linux);

/// The page over a fake trash at the app's 1400×800, with the 220 px
/// sidebar's width taken.
class BinHarness {
  BinHarness([FakeTrashStore? store]) : store = store ?? sampleTrash();

  final FakeTrashStore store;
  late final lifecycle = FakeTrashLifecycle(store);
  late ProviderContainer container;

  int get epoch => container.read(writeEpochProvider);

  /// The calls other than list loads.
  List<String> get writes =>
      store.calls.where((c) => !c.startsWith('list')).toList();

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: store.overrides(lifecycle),
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: anvilTheme(AnvilThemeSpec.dark),
          home: const Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: AnvilLayout.sidebarWidth),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(AnvilSpacing.lg),
                    child: RecycleBinPage(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

/// The header text of [domain]'s section, or null when it is not shown.
String? headerText(WidgetTester tester, ShellDomain domain) {
  final finder = find.byKey(RecycleBinPage.groupHeaderKey(domain));
  if (finder.evaluate().isEmpty) return null;
  return tester.widget<Text>(finder).textSpan!.toPlainText();
}

Finder inGroup(ShellDomain domain, Finder finder) => find.descendant(
  of: find.byKey(TrashGroupTable.groupKey(domain)),
  matching: finder,
);

Finder selectBox(ShellDomain domain, String id) =>
    inGroup(domain, find.byKey(RecordTable.selectKey(id)));

Finder selectAll(ShellDomain domain) =>
    inGroup(domain, find.byKey(RecordTable.selectAllKey));

Finder action(ShellDomain domain, String label, String id) =>
    inGroup(domain, find.byKey(RecordTable.actionKey(label, id)));

bool? checked(WidgetTester tester, Finder box) =>
    tester.widget<Checkbox>(box).value;

final undoBar = find.byKey(undoSnackBarKey);

String undoMessage(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(of: undoBar, matching: find.byType(Text)).first,
    )
    .data!;

Future<void> tapUndo(WidgetTester tester) async {
  await tester.tap(find.byKey(undoSnackBarActionKey));
  await tester.pumpAndSettle();
}

VoidCallback? emptyTrashPressed(WidgetTester tester) => tester
    .widget<ButtonStyleButton>(find.byKey(RecycleBinPage.emptyTrashKey))
    .onPressed;

void main() {
  testWidgets('groups the soft-deleted records by domain in 0.1.6 order, '
      'with counts, and hides empty domains', (tester) async {
    final h = BinHarness();
    await h.pump(tester);

    expect(find.text('Recycle Bin'), findsOneWidget);
    expect(headerText(tester, ShellDomain.classes), 'Character Classes  (1)');
    expect(headerText(tester, ShellDomain.items), 'Items  (2)');
    expect(headerText(tester, ShellDomain.recipes), 'Crafting Recipes  (1)');
    for (final domain in [
      ShellDomain.abilities,
      ShellDomain.npcs,
      ShellDomain.lootTables,
    ]) {
      expect(headerText(tester, domain), isNull, reason: domain.name);
    }
    double top(ShellDomain d) =>
        tester.getTopLeft(find.byKey(RecycleBinPage.groupHeaderKey(d))).dy;
    expect(top(ShellDomain.classes), lessThan(top(ShellDomain.items)));
    expect(top(ShellDomain.items), lessThan(top(ShellDomain.recipes)));

    // Each table: Name, Export Key, Deleted At, Actions; rows by name.
    for (final label in ['Name', 'Export Key', 'Deleted At', 'Actions']) {
      expect(inGroup(ShellDomain.items, find.text(label)), findsOneWidget);
    }
    expect(
      tester.getTopLeft(find.text('Bronze Axe')).dy,
      lessThan(tester.getTopLeft(find.text('Iron Sword')).dy),
    );
    expect(find.text('iron_sword'), findsOneWidget);
    expect(
      inGroup(
        ShellDomain.items,
        find.text(formatDeletedAt('2026-10-31 14:05:09')),
      ),
      findsOneWidget,
    );
    // Active records are not in the trash.
    expect(find.text('Fireball'), findsNothing);
    expect(find.text('Leather Cap'), findsNothing);
    expect(emptyTrashPressed(tester), isNotNull);
    expect(find.text('Restore Selected'), findsNothing);
  }, variant: linux);

  testWidgets('select all works per domain, and the same id in two domains '
      'is two selections', (tester) async {
    final h = BinHarness();
    await h.pump(tester);

    await tester.tap(selectBox(ShellDomain.classes, 'dup'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    expect(checked(tester, selectBox(ShellDomain.items, 'dup')), isFalse);

    await tester.tap(selectAll(ShellDomain.items));
    await tester.pumpAndSettle();
    expect(find.text('3 selected'), findsOneWidget);
    expect(checked(tester, selectAll(ShellDomain.items)), isTrue);
    expect(checked(tester, selectAll(ShellDomain.recipes)), isFalse);
    expect(find.text('Restore Selected'), findsOneWidget);
    expect(find.text('Permanently Delete'), findsOneWidget);

    // Again: only the items leave the selection.
    await tester.tap(selectAll(ShellDomain.items));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    expect(checked(tester, selectBox(ShellDomain.classes, 'dup')), isTrue);

    // A partly selected group shows the indeterminate box.
    await tester.tap(selectBox(ShellDomain.items, 'i-1'));
    await tester.pumpAndSettle();
    expect(checked(tester, selectAll(ShellDomain.items)), isNull);
    expect(h.writes, isEmpty);
  }, variant: linux);

  testWidgets('Restore applies at once and its Undo returns the row to the '
      'trash', (tester) async {
    final h = BinHarness();
    await h.pump(tester);

    await tester.tap(action(ShellDomain.items, 'Restore', 'i-1'));
    await tester.pumpAndSettle();
    expect(h.writes, ['bulkRestore items i-1']);
    expect(h.epoch, 1);
    expect(find.text('Iron Sword'), findsNothing);
    expect(headerText(tester, ShellDomain.items), 'Items  (1)');
    expect(undoMessage(tester), 'Restored "Iron Sword"');

    await tapUndo(tester);
    expect(h.writes, ['bulkRestore items i-1', 'bulkSoftDelete items i-1']);
    expect(h.epoch, 2);
    expect(find.text('Iron Sword'), findsOneWidget);
    expect(headerText(tester, ShellDomain.items), 'Items  (2)');
    expect(undoBar, findsNothing);
  }, variant: linux);

  testWidgets('bulk restore across domains is one bump, and its Undo '
      'soft-deletes the same ids again', (tester) async {
    final h = BinHarness();
    await h.pump(tester);
    await tester.tap(selectBox(ShellDomain.classes, 'dup'));
    await tester.tap(selectBox(ShellDomain.items, 'i-1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Restore Selected'));
    await tester.pumpAndSettle();
    expect(h.writes, ['bulkRestore classes dup', 'bulkRestore items i-1']);
    expect(h.epoch, 1);
    expect(undoMessage(tester), 'Restored 2 records');
    expect(headerText(tester, ShellDomain.classes), isNull);
    expect(find.text('2 selected'), findsNothing);
    // The item sharing the class's id stayed in the trash.
    expect(find.text('Bronze Axe'), findsOneWidget);

    await tapUndo(tester);
    expect(h.writes.skip(2), [
      'bulkSoftDelete classes dup',
      'bulkSoftDelete items i-1',
    ]);
    expect(h.epoch, 2);
    expect(headerText(tester, ShellDomain.classes), 'Character Classes  (1)');
    expect(headerText(tester, ShellDomain.items), 'Items  (2)');
  }, variant: linux);

  testWidgets('a bulk restore within one domain names that domain', (
    tester,
  ) async {
    final h = BinHarness();
    await h.pump(tester);
    await tester.tap(selectAll(ShellDomain.items));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Restore Selected'));
    await tester.pumpAndSettle();
    expect(h.writes, ['bulkRestore items dup,i-1']);
    expect(undoMessage(tester), 'Restored 2 items');
    expect(headerText(tester, ShellDomain.items), isNull);
  }, variant: linux);

  testWidgets('Permanently Delete confirms first and offers no Undo', (
    tester,
  ) async {
    final h = BinHarness();
    await h.pump(tester);

    await tester.tap(action(ShellDomain.recipes, 'Permanently Delete', 'r-1'));
    await tester.pumpAndSettle();
    expect(find.text('Permanently Delete Record?'), findsOneWidget);
    expect(
      find.text(
        'Brew Potion will be permanently deleted. This action cannot be undone.',
        findRichText: true,
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(h.writes, isEmpty);

    await tester.tap(action(ShellDomain.recipes, 'Permanently Delete', 'r-1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(permanentDeleteConfirmKey));
    await tester.pumpAndSettle();
    expect(h.writes, ['bulkHardDelete recipes r-1']);
    expect(h.epoch, 1);
    expect(headerText(tester, ShellDomain.recipes), isNull);
    expect(undoBar, findsNothing);
  }, variant: linux);

  testWidgets('bulk permanent delete confirms and writes once per domain', (
    tester,
  ) async {
    final h = BinHarness();
    await h.pump(tester);
    await tester.tap(selectAll(ShellDomain.items));
    await tester.tap(selectBox(ShellDomain.recipes, 'r-1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Permanently Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Permanently Delete 3 Records?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(h.writes, isEmpty);
    expect(find.text('3 selected'), findsOneWidget);

    await tester.tap(find.text('Permanently Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(permanentDeleteConfirmKey));
    await tester.pumpAndSettle();
    expect(h.writes, [
      'bulkHardDelete items dup,i-1',
      'bulkHardDelete recipes r-1',
    ]);
    expect(h.epoch, 1);
    expect(undoBar, findsNothing);
    expect(headerText(tester, ShellDomain.items), isNull);
    expect(headerText(tester, ShellDomain.classes), 'Character Classes  (1)');
  }, variant: linux);

  testWidgets('Empty Trash needs both steps; Cancel at step 2 does nothing', (
    tester,
  ) async {
    final h = BinHarness();
    await h.pump(tester);

    await tester.tap(find.byKey(RecycleBinPage.emptyTrashKey));
    await tester.pumpAndSettle();
    expect(find.text('Empty Trash?'), findsOneWidget);
    expect(
      find.text(
        'This will permanently delete all 4 archived records across all '
        'domains. This action cannot be undone.',
        findRichText: true,
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(EmptyTrashDialog.continueKey));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Are you absolutely sure? This will permanently remove 4 records. '
        'There is no way to recover them.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(EmptyTrashDialog.continueKey), findsNothing);
    await tester.tap(find.byKey(EmptyTrashDialog.cancelKey));
    await tester.pumpAndSettle();
    expect(find.text('Empty Trash?'), findsNothing);
    expect(h.writes, isEmpty);
    expect(h.epoch, 0);

    // A new opening starts at step 1 again.
    await tester.tap(find.byKey(RecycleBinPage.emptyTrashKey));
    await tester.pumpAndSettle();
    expect(find.byKey(EmptyTrashDialog.confirmKey), findsNothing);
    await tester.tap(find.byKey(EmptyTrashDialog.continueKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Permanently Delete All'));
    await tester.pumpAndSettle();

    expect(h.writes, ['emptyTrash']);
    expect(h.epoch, 1);
    expect(find.text('Trash is empty'), findsOneWidget);
    expect(find.text('Deleted records will appear here.'), findsOneWidget);
    expect(emptyTrashPressed(tester), isNull);
    // The active records are untouched.
    expect(h.store.entries[ShellDomain.items]!.map((e) => e.name), [
      'Leather Cap',
    ]);
    expect(undoBar, findsNothing);
  }, variant: linux);

  testWidgets('an empty trash says so and disables Empty Trash', (
    tester,
  ) async {
    final h = BinHarness(
      FakeTrashStore({
        ShellDomain.items: [FakeEntry('i-1', 'Iron Sword', 'iron_sword')],
      }),
    );
    await h.pump(tester);

    expect(find.text('Trash is empty'), findsOneWidget);
    expect(emptyTrashPressed(tester), isNull);
    expect(find.byType(TrashGroupTable), findsNothing);
    await tester.tap(find.byKey(RecycleBinPage.emptyTrashKey));
    await tester.pumpAndSettle();
    expect(find.text('Empty Trash?'), findsNothing);
  }, variant: linux);

  testWidgets('a failing Empty Trash shows the SaveFailed message or the '
      '0.1.6 fallback, and changes nothing', (tester) async {
    final h = BinHarness();
    h.store.failures['emptyTrash'] = const SaveFailed(
      'FOREIGN KEY constraint failed',
      'cause',
    );
    await h.pump(tester);

    Future<void> empty() async {
      await tester.tap(find.byKey(RecycleBinPage.emptyTrashKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(EmptyTrashDialog.continueKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(EmptyTrashDialog.confirmKey));
      await tester.pumpAndSettle();
    }

    await empty();
    expect(find.byKey(RecycleBinPage.errorKey), findsOneWidget);
    expect(find.text('FOREIGN KEY constraint failed'), findsOneWidget);
    expect(h.epoch, 0);
    expect(headerText(tester, ShellDomain.items), 'Items  (2)');

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.byKey(RecycleBinPage.errorKey), findsNothing);

    h.store.failures['emptyTrash'] = StateError('boom');
    await empty();
    expect(find.text('Failed to empty trash.'), findsOneWidget);
    expect(h.epoch, 0);
  }, variant: linux);

  testWidgets('failing actions show 0.1.6\'s fallback texts', (tester) async {
    final h = BinHarness();
    await h.pump(tester);

    h.store.failures['bulkRestore'] = StateError('boom');
    await tester.tap(action(ShellDomain.items, 'Restore', 'i-1'));
    await tester.pumpAndSettle();
    expect(find.text('Restore failed.'), findsOneWidget);
    expect(undoBar, findsNothing);

    h.store.failures['bulkHardDelete'] = StateError('boom');
    await tester.tap(action(ShellDomain.items, 'Permanently Delete', 'i-1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(permanentDeleteConfirmKey));
    await tester.pumpAndSettle();
    expect(find.text('Delete failed.'), findsOneWidget);

    await tester.tap(selectAll(ShellDomain.items));
    await tester.pumpAndSettle();
    h.store.failures['bulkRestore'] = StateError('boom');
    await tester.tap(find.text('Restore Selected'));
    await tester.pumpAndSettle();
    expect(find.text('Bulk restore failed.'), findsOneWidget);

    h.store.failures['bulkHardDelete'] = StateError('boom');
    await tester.tap(find.text('Permanently Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(permanentDeleteConfirmKey));
    await tester.pumpAndSettle();
    expect(find.text('Bulk delete failed.'), findsOneWidget);
    expect(h.epoch, 0);
    expect(find.text('2 selected'), findsOneWidget);
  }, variant: linux);

  testWidgets('a bulk restore whose second domain fails still bumps once '
      'for the first domain\'s write', (tester) async {
    final h = BinHarness();
    await h.pump(tester);
    await tester.tap(selectBox(ShellDomain.classes, 'dup'));
    await tester.tap(selectBox(ShellDomain.items, 'i-1'));
    await tester.pumpAndSettle();

    h.store.failures['bulkRestore items'] = const SaveFailed('disk full', '');
    await tester.tap(find.text('Restore Selected'));
    await tester.pumpAndSettle();
    expect(h.writes, ['bulkRestore classes dup', 'bulkRestore items i-1']);
    expect(find.text('disk full'), findsOneWidget);
    expect(h.epoch, 1);
    expect(undoBar, findsNothing);
    // The class was restored and left the trash; the item stayed.
    expect(headerText(tester, ShellDomain.classes), isNull);
    expect(find.text('Iron Sword'), findsOneWidget);
  }, variant: linux);

  testWidgets('a failed load shows the 0.1.6 text', (tester) async {
    final h = BinHarness();
    h.store.failures['list'] = StateError('boom');
    await h.pump(tester);
    expect(find.text('Failed to load archived records.'), findsOneWidget);
  }, variant: linux);
}
