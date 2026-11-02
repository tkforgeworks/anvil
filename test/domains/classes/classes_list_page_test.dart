import 'package:anvil/app/domains/classes/classes_create_dialog.dart';
import 'package:anvil/app/domains/classes/classes_editor_page.dart';
import 'package:anvil/app/domains/classes/classes_pages.dart';
import 'package:anvil/app/lists/list_toolbar.dart';
import 'package:anvil/app/lists/record_table.dart';
import 'package:anvil/app/shell/editor_dialog.dart';
import 'package:anvil/app/shell/placeholders.dart';
import 'package:anvil/app/shell/shell_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_fakes.dart';

const activeNames = ['Mage', 'Warrior'];

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

/// The class the page opened in the editor dialog: the registry's
/// placeholder until the orchestrator registers [classEditor] in
/// `placeholders.dart`, the real page after.
String openedClass(WidgetTester tester) {
  expect(find.byType(EditorDialog), findsOneWidget);
  final page = find.byType(ClassEditorPage);
  if (page.evaluate().isNotEmpty) {
    return tester.widget<ClassEditorPage>(page).id;
  }
  final placeholder = tester.widget<EditorPlaceholder>(
    find.byType(EditorPlaceholder),
  );
  expect(placeholder.domain, ShellDomain.classes);
  return placeholder.id;
}

void main() {
  testWidgets('shows 0.1.6\'s columns and the active classes', (tester) async {
    final h = ClassHarness();
    await h.pump(tester, classesListPage());

    expect(find.text('Classes'), findsOneWidget);
    expect(find.text('+ New Class'), findsOneWidget);
    for (final label in ['Name', 'Export Key', 'Description']) {
      expect(header(label), findsOneWidget);
    }
    expect(shownNames(tester, [...activeNames, 'Retired Class']), activeNames);
    expect(find.text('A sturdy fighter.'), findsOneWidget);
    // Mage has no description.
    expect(find.text('—'), findsOneWidget);
  }, variant: linux);

  testWidgets('Last Modified sorts newest first; Archived shows the archive', (
    tester,
  ) async {
    final h = ClassHarness();
    await h.pump(tester, classesListPage());

    await tester.tap(find.byKey(ListToolbar.sortKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last Modified').last);
    await tester.pumpAndSettle();
    expect(shownNames(tester, activeNames), ['Mage', 'Warrior']);

    await tester.tap(find.text('Archived'));
    await tester.pumpAndSettle();
    expect(shownNames(tester, [...activeNames, 'Retired Class']), [
      'Retired Class',
    ]);
  }, variant: linux);

  testWidgets('New creates with the key filled from the name and opens it', (
    tester,
  ) async {
    final h = ClassHarness();
    await h.pump(tester, classesListPage());

    await tester.tap(find.text('+ New Class'));
    await tester.pumpAndSettle();
    expect(find.text('New Character Class'), findsOneWidget);
    final create = find.byKey(CreateClassDialog.createKey);
    expect(tester.widget<FilledButton>(create).onPressed, isNull);

    await tester.enterText(
      find.byKey(CreateClassDialog.nameKey),
      'Battle Mage',
    );
    await tester.pump();
    expect(find.text('battle-mage'), findsOneWidget);
    await tester.tap(create);
    await tester.pumpAndSettle();

    expect(h.classes.calls, contains('create Battle Mage battle-mage 1.0'));
    expect(h.epoch, 1);
    final created = h.classes.rows.last;
    expect(openedClass(tester), created.id);
  }, variant: linux);

  testWidgets('a taken key is refused in the dialog', (tester) async {
    final h = ClassHarness();
    await h.pump(tester, classesListPage());

    await tester.tap(find.text('+ New Class'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(CreateClassDialog.nameKey), 'Mage');
    await tester.pump();
    await tester.tap(find.byKey(CreateClassDialog.createKey));
    await tester.pumpAndSettle();
    expect(
      find.text('The export key "mage" is already used by another record.'),
      findsOneWidget,
    );
    expect(find.text('New Character Class'), findsOneWidget);
    expect(h.epoch, 0);
  }, variant: linux);

  testWidgets('Duplicate copies the row and opens the copy', (tester) async {
    final h = ClassHarness();
    await h.pump(tester, classesListPage());

    await tester.tap(find.byKey(RecordTable.actionKey('Duplicate', mageId)));
    await tester.pumpAndSettle();
    expect(h.classes.calls, contains('duplicate $mageId'));
    expect(h.epoch, 1);
    final copy = h.classes.rows.last;
    expect(copy.displayName, 'Mage (Copy)');
    expect(openedClass(tester), copy.id);
  }, variant: linux);

  testWidgets('the empty list shows 0.1.6\'s empty state', (tester) async {
    final h = ClassHarness();
    h.classes.rows.clear();
    await h.pump(tester, classesListPage());
    expect(find.text('No classes yet'), findsOneWidget);
    expect(
      find.text('Create your first character class to get started.'),
      findsOneWidget,
    );
    expect(find.text('+ Create First Class'), findsOneWidget);
  }, variant: linux);
}
