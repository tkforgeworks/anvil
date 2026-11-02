import 'dart:convert';
import 'dart:io';

import 'package:anvil/app/export/export_page.dart';
import 'package:anvil/app/export/template_dialog.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../dialogs/fakes.dart' show copyFixture;
import 'fakes.dart';

/// Lets the export isolates run until [done] holds.
Future<void> pumpUntil(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 500 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 1));
  }
  expect(done(), isTrue, reason: 'condition not reached');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'over the real ExportService and SqliteTemplateRepository on a fixture '
    'copy: the Nested JSON preview is byte-identical to the 0.1.6 preset '
    'fixture, and a template made in the dialog is stored with its history '
    'row and listed',
    (tester) async {
      final path = copyFixture();
      final db = ProjectDatabase.open(path);
      addTearDown(db.close);
      final templates = SqliteTemplateRepository(db);
      final history = SqliteSaveHistoryRepository(db);
      final h = ExportHarness();
      await h.pump(
        tester,
        exportService: ExportService(projectPath: path),
        templateRepository: templates,
      );
      await pumpUntil(tester, () => h.loaded?.selectors.isNotEmpty ?? false);
      expect(h.state.selectedId, 'nested-json');

      await tester.tap(find.byKey(ExportPage.previewKey));
      await pumpUntil(
        tester,
        () => find.byKey(ExportPage.previewOutputKey).evaluate().isNotEmpty,
      );
      final preview = tester
          .widget<Text>(find.byKey(ExportPage.previewOutputKey))
          .data!;
      final fixture = File(
        'packages/anvil_core/test/fixtures/preset-nested-json.txt',
      ).readAsBytesSync();
      expect(utf8.encode(preview), fixture);

      await tester.tap(find.byKey(ExportPage.newTemplateKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(templateNameKey), 'Item List');
      await tester.enterText(
        find.byKey(templateSourceKey),
        '{% for i in items %}{{ i.display_name }}\n{% endfor %}',
      );
      await tester.pump();
      await tester.tap(find.byKey(templateSaveKey));
      await pumpUntil(
        tester,
        () =>
            find.byType(TemplateDialog).evaluate().isEmpty &&
            h.state.selectors.any((s) => s.name == 'Item List'),
      );

      final stored = (await tester.runAsync(templates.list))!;
      final created = stored.singleWhere((t) => t.name == 'Item List');
      expect(h.state.selectedId, created.id);
      expect(h.epoch, 1);
      final recent = (await tester.runAsync(history.recent))!;
      expect(recent.first.description, templateChanged('Item List'));
    },
    variant: linux,
  );
}
