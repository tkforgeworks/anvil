import 'package:anvil/app/domains/abilities/abilities_editor_page.dart';
import 'package:anvil/app/domains/abilities/abilities_pages.dart';
import 'package:anvil/app/domains/abilities/create_ability_dialog.dart';
import 'package:anvil/app/lists/bulk_dialogs.dart';
import 'package:anvil/app/lists/list_toolbar.dart';
import 'package:anvil/app/lists/record_table.dart';
import 'package:anvil/app/shell/shell_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const activeNames = ['Fireball', 'Slash'];

List<String> shownNames(WidgetTester tester, Iterable<String> candidates) {
  final shown = [
    for (final name in candidates)
      if (find.text(name).evaluate().isNotEmpty) name,
  ];
  shown.sort(
    (a, b) => tester
        .getTopLeft(find.text(a))
        .dy
        .compareTo(tester.getTopLeft(find.text(b)).dy),
  );
  return shown;
}

Finder header(String label) =>
    find.descendant(of: find.byType(DataTable), matching: find.text(label));

/// The ability editor the page opened (modal mode shows the registry's
/// builder, which is the real page since ANVL-191).
(ShellDomain, String) openedEditor(WidgetTester tester) {
  final page = tester.widget<AbilityEditorPage>(find.byType(AbilityEditorPage));
  return (ShellDomain.abilities, page.id);
}

void main() {
  testWidgets('shows 0.1.6\'s columns and the active abilities', (
    tester,
  ) async {
    final h = AbilityHarness();
    await h.pump(tester, abilitiesListPage());

    expect(find.text('Abilities'), findsOneWidget);
    expect(find.text('+ New Ability'), findsOneWidget);
    for (final label in ['Name', 'Export Key', 'Type', 'Description']) {
      expect(header(label), findsOneWidget);
    }
    expect(shownNames(tester, [...activeNames, 'Retired Move']), activeNames);
    expect(find.text('active'), findsOneWidget);
    expect(find.text('Hurls a ball of fire.'), findsOneWidget);
    // Slash has neither a type nor a description.
    expect(find.text('—'), findsNWidgets(2));
  }, variant: linux);

  testWidgets('search narrows by name; Last Modified sorts newest first', (
    tester,
  ) async {
    final h = AbilityHarness();
    await h.pump(tester, abilitiesListPage());

    await tester.enterText(find.byKey(ListToolbar.searchKey), 'fire');
    await tester.pumpAndSettle();
    expect(shownNames(tester, activeNames), ['Fireball']);
    await tester.enterText(find.byKey(ListToolbar.searchKey), '');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ListToolbar.sortKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last Modified').last);
    await tester.pumpAndSettle();
    expect(shownNames(tester, activeNames), ['Slash', 'Fireball']);
  }, variant: linux);

  testWidgets('Archived shows the archive and restores', (tester) async {
    final h = AbilityHarness();
    await h.pump(tester, abilitiesListPage());

    await tester.tap(find.text('Archived'));
    await tester.pumpAndSettle();
    expect(shownNames(tester, [...activeNames, 'Retired Move']), [
      'Retired Move',
    ]);
    await tester.tap(find.byTooltip('Restore'));
    await tester.pumpAndSettle();
    expect(h.repository.calls, contains('restore $retiredId'));
    expect(h.epoch, 1);
    expect(find.text('No archived abilities.'), findsOneWidget);
  }, variant: linux);

  testWidgets('New creates with the key filled from the name and opens it', (
    tester,
  ) async {
    final h = AbilityHarness();
    await h.pump(tester, abilitiesListPage());

    await tester.tap(find.text('+ New Ability'));
    await tester.pumpAndSettle();
    expect(find.text('New Ability'), findsOneWidget);
    final create = find.byKey(CreateAbilityDialog.createKey);
    expect(tester.widget<FilledButton>(create).onPressed, isNull);

    await tester.enterText(
      find.byKey(CreateAbilityDialog.nameKey),
      'Ice Lance!',
    );
    await tester.pump();
    expect(find.text('ice-lance'), findsOneWidget);

    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(h.repository.calls, contains('create Ice Lance! ice-lance'));
    expect(h.epoch, 1);
    final created = h.repository.rows.last;
    expect(openedEditor(tester), (ShellDomain.abilities, created.id));
  }, variant: linux);

  testWidgets('a typed key wins over the name; a taken key is refused in the '
      'dialog', (tester) async {
    final h = AbilityHarness();
    await h.pump(tester, abilitiesListPage());

    await tester.tap(find.text('+ New Ability'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(CreateAbilityDialog.exportKeyKey),
      'slash',
    );
    await tester.enterText(find.byKey(CreateAbilityDialog.nameKey), 'Cleave');
    await tester.pump();
    expect(find.text('slash'), findsWidgets);

    await tester.tap(find.byKey(CreateAbilityDialog.createKey));
    await tester.pumpAndSettle();
    expect(
      find.text('The export key "slash" is already used by another record.'),
      findsOneWidget,
    );
    expect(find.text('New Ability'), findsOneWidget);
    expect(h.epoch, 0);
  }, variant: linux);

  testWidgets('Duplicate copies the row and opens the copy', (tester) async {
    final h = AbilityHarness();
    await h.pump(tester, abilitiesListPage());

    await tester.tap(find.byKey(RecordTable.actionKey('Duplicate', slashId)));
    await tester.pumpAndSettle();
    expect(h.repository.calls, contains('duplicate $slashId'));
    expect(h.epoch, 1);
    final copy = h.repository.rows.last;
    expect(copy.displayName, 'Slash (Copy)');
    expect(openedEditor(tester), (ShellDomain.abilities, copy.id));
  }, variant: linux);

  testWidgets('a row tap opens the editor; bulk delete soft-deletes the '
      'selection', (tester) async {
    final h = AbilityHarness();
    await h.pump(tester, abilitiesListPage());

    await tester.tap(find.text('Slash'));
    await tester.pumpAndSettle();
    expect(openedEditor(tester), (ShellDomain.abilities, slashId));
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(RecordTable.selectAllKey));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    await tester.tap(find.text('Delete Selected'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(BulkDeleteDialog.confirmKey));
    await tester.pumpAndSettle();

    expect(
      h.repository.calls,
      contains('bulkSoftDelete abilities $fireballId,$slashId'),
    );
    expect(find.text('No abilities yet'), findsOneWidget);
  }, variant: linux);
}
