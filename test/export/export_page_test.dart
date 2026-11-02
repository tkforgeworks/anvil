import 'dart:convert';
import 'dart:io';

import 'package:anvil/app/editor/dirty_editors.dart';
import 'package:anvil/app/editor/editor_state.dart';
import 'package:anvil/app/export/export_controller.dart';
import 'package:anvil/app/export/export_page.dart';
import 'package:anvil/app/export/record_selection_list.dart';
import 'package:anvil/app/export/template_dialog.dart';
import 'package:anvil/app/shell/app_router.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

/// Valid Nunjucks outside the 0.2 subset: a macro on line 2.
const macroSource =
    '{% for i in items %}{{ i.display_name }}{% endfor %}\n'
    '  {% macro label(x) %}{{ x }}{% endmacro %}';

const goodSource = '{% for i in items %}{{ i.display_name }}\n{% endfor %}';

Future<void> choose(
  WidgetTester tester,
  ExportHarness h,
  Key picker,
  String label,
) async {
  await tester.ensureVisible(find.byKey(picker));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(picker));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
  await h.settle(tester);
}

Future<void> tapKey(WidgetTester tester, ExportHarness h, Key key) async {
  await tester.pump();
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await h.settle(tester);
}

/// Lets real file I/O run until [done] holds.
Future<void> pumpUntil(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 1));
  }
  expect(done(), isTrue, reason: 'condition not reached');
  await tester.pumpAndSettle();
}

bool enabled(WidgetTester tester, Key key) {
  final finder = find.descendant(
    of: find.byKey(key),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  );
  final button = finder.evaluate().isEmpty
      ? tester.widget<ButtonStyleButton>(find.byKey(key))
      : tester.widget<ButtonStyleButton>(finder.first);
  return button.onPressed != null;
}

List<DropdownMenuItem<String>> selectorItems(WidgetTester tester) => tester
    .widget<DropdownButton<String>>(
      find.descendant(
        of: find.byKey(ExportPage.selectorKey),
        matching: find.byType(DropdownButton<String>),
      ),
    )
    .items!;

String? errorText(WidgetTester tester) {
  final line = find.byKey(ExportPage.errorKey);
  if (line.evaluate().isEmpty) return null;
  return tester
      .widgetList<Text>(find.descendant(of: line, matching: find.byType(Text)))
      .first
      .data;
}

String? successText(WidgetTester tester) {
  final line = find.byKey(ExportPage.successKey);
  if (line.evaluate().isEmpty) return null;
  return tester
      .widgetList<Text>(find.descendant(of: line, matching: find.byType(Text)))
      .first
      .data;
}

String selectAllLabel(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(RecordSelectionList.selectAllKey),
        matching: find.byType(Text),
      ),
    )
    .data!;

bool? selectAllValue(WidgetTester tester) => tester
    .widget<Checkbox>(
      find.descendant(
        of: find.byKey(RecordSelectionList.selectAllKey),
        matching: find.byType(Checkbox),
      ),
    )
    .value;

void main() {
  testWidgets(
    'lists the presets with the Built-in chip, then the templates; the '
    'selected entry shows its description and, for a template, edit and '
    'delete',
    (tester) async {
      final h = ExportHarness(
        templates: [
          template('tpl-1', 'Recipe Book', goodSource, description: 'Mine'),
        ],
      );
      await h.pump(tester);

      expect(find.text('Export'), findsOneWidget);
      expect(find.text('New Template'), findsOneWidget);
      expect(find.text('Template / Preset'), findsOneWidget);
      expect(h.state.selectedId, 'nested-json');
      expect(
        find.text(
          'Hierarchical JSON with nested sub-objects for referenced records',
        ),
        findsOneWidget,
      );
      expect(find.byKey(ExportPage.editTemplateKey), findsNothing);

      expect(
        [for (final i in selectorItems(tester)) i.value],
        ['nested-json', 'flat-json', 'csv', 'tpl-1'],
      );
      await tester.tap(find.byKey(ExportPage.selectorKey));
      await tester.pumpAndSettle();
      // Three presets in the open menu, plus the selected one in the button.
      expect(find.text('Built-in'), findsNWidgets(4));
      await tester.tap(find.text('Recipe Book').last);
      await h.settle(tester);

      expect(h.state.selectedId, 'tpl-1');
      expect(find.text('Mine'), findsOneWidget);
      expect(find.byTooltip('Edit template'), findsOneWidget);
      expect(find.byTooltip('Delete template'), findsOneWidget);
      expect(find.text('Built-in'), findsNothing);
    },
    variant: linux,
  );

  testWidgets(
    'scope: the domain picker shows for Single Domain and Record Selection, '
    'the checklist follows the 0.1.6 select-all rule, and a selection with '
    'nothing checked renders as the domain scope',
    (tester) async {
      final h = ExportHarness(classes: const {});
      await h.pump(tester);

      expect(find.byKey(ExportPage.domainKey), findsNothing);
      expect(enabled(tester, ExportPage.previewKey), isTrue);

      await choose(tester, h, ExportPage.scopeKey, 'Single Domain');
      expect(find.byKey(ExportPage.domainKey), findsOneWidget);
      expect(find.byKey(RecordSelectionList.selectAllKey), findsNothing);
      // No domain yet: both buttons wait for one.
      expect(enabled(tester, ExportPage.previewKey), isFalse);
      expect(enabled(tester, ExportPage.executeKey), isFalse);

      await choose(tester, h, ExportPage.domainKey, 'Items');
      expect(enabled(tester, ExportPage.previewKey), isTrue);
      await tapKey(tester, h, ExportPage.previewKey);
      expect(
        h.service.renders.last.scope,
        ExportScope.domain(ExportDomain.items),
      );

      await choose(tester, h, ExportPage.scopeKey, 'Record Selection');
      expect(find.byKey(ExportPage.domainKey), findsOneWidget);
      // Changing the mode cleared the checklist but kept the domain.
      expect(h.state.domain, ExportDomain.items);
      expect(selectAllLabel(tester), 'Select All (0/2)');
      expect(selectAllValue(tester), isFalse);
      expect(find.text('Bronze Axe'), findsOneWidget);
      expect(find.text('Iron Sword'), findsOneWidget);

      await tapKey(tester, h, ExportPage.previewKey);
      expect(
        h.service.renders.last.scope,
        ExportScope.domain(ExportDomain.items),
        reason: 'nothing checked exports the whole domain',
      );

      await tapKey(tester, h, RecordSelectionList.recordKey('i-2'));
      expect(selectAllLabel(tester), 'Select All (1/2)');
      expect(selectAllValue(tester), isNull);
      await tapKey(tester, h, ExportPage.previewKey);
      expect(
        h.service.renders.last.scope,
        ExportScope.selection(ExportDomain.items, ['i-2']),
      );

      await tapKey(tester, h, RecordSelectionList.selectAllKey);
      expect(selectAllLabel(tester), 'Select All (2/2)');
      expect(selectAllValue(tester), isTrue);
      await tapKey(tester, h, RecordSelectionList.selectAllKey);
      expect(selectAllLabel(tester), 'Select All (0/2)');

      await choose(tester, h, ExportPage.domainKey, 'Classes');
      expect(find.byKey(RecordSelectionList.selectAllKey), findsNothing);
      expect(find.text('No records found in this domain.'), findsOneWidget);

      await choose(tester, h, ExportPage.scopeKey, 'Full Project');
      expect(find.byKey(ExportPage.domainKey), findsNothing);
      await tapKey(tester, h, ExportPage.previewKey);
      expect(h.service.renders.last.scope, const ExportScope.full());
    },
    variant: linux,
  );

  testWidgets('the preview shows the output and any scope, selector or '
      'checklist change clears it', (tester) async {
    final h = ExportHarness();
    await h.pump(tester);
    h.service.onRender = (id, _) =>
        ExportOutput(text: '{\n  "preset": "$id"\n}', suggestedFileName: 'x');

    await tapKey(tester, h, ExportPage.previewKey);
    expect(find.text('Preview'), findsNWidgets(2));
    expect(
      tester.widget<Text>(find.byKey(ExportPage.previewOutputKey)).data,
      '{\n  "preset": "nested-json"\n}',
    );

    await choose(tester, h, ExportPage.scopeKey, 'Single Domain');
    expect(find.byKey(ExportPage.previewOutputKey), findsNothing);

    await choose(tester, h, ExportPage.domainKey, 'Items');
    await tapKey(tester, h, ExportPage.previewKey);
    expect(find.byKey(ExportPage.previewOutputKey), findsOneWidget);
    await choose(tester, h, ExportPage.selectorKey, 'Flat JSON');
    expect(find.byKey(ExportPage.previewOutputKey), findsNothing);

    await choose(tester, h, ExportPage.scopeKey, 'Record Selection');
    await tapKey(tester, h, ExportPage.previewKey);
    expect(find.byKey(ExportPage.previewOutputKey), findsOneWidget);
    await tapKey(tester, h, RecordSelectionList.recordKey('i-1'));
    expect(find.byKey(ExportPage.previewOutputKey), findsNothing);
  }, variant: linux);

  testWidgets(
    'the validation gate shows 0.1.6 message with Open Validation Panel, '
    'which goes to /validation; the line closes',
    (tester) async {
      final h = ExportHarness();
      await h.pump(tester);
      const message =
          'Export blocked: 2 validation errors must be resolved before '
          'exporting.';
      h.service.onRender = (_, _) => throw const ExportBlocked(message);

      await tapKey(tester, h, ExportPage.previewKey);
      expect(errorText(tester), message);
      expect(find.text('Open Validation Panel'), findsOneWidget);
      expect(find.byKey(ExportPage.previewOutputKey), findsNothing);

      await tapKey(tester, h, ExportPage.errorCloseKey);
      expect(errorText(tester), isNull);

      await tapKey(tester, h, ExportPage.executeKey);
      expect(errorText(tester), message);
      expect(h.dialogs.requests, isEmpty, reason: 'no dialog when blocked');
      expect(
        h.logLines.where((l) => l.contains('Export blocked')),
        hasLength(1),
      );
      await tapKey(tester, h, ExportPage.openValidationKey);
      expect(h.location, '/validation');
      expect(find.text('Validation stand-in'), findsOneWidget);
    },
    variant: linux,
  );

  testWidgets('render failures: a template error with its position, the '
      'timeout, and the fallbacks', (tester) async {
    final h = ExportHarness();
    await h.pump(tester);

    final templateError = AnvilTemplateError(
      TemplateErrorKind.render,
      'undefined value',
      line: 3,
      column: 7,
    );
    h.service.onRender = (_, _) => throw templateError;
    await tapKey(tester, h, ExportPage.previewKey);
    expect(errorText(tester), templateError.toString());
    expect(errorText(tester), contains('[Line 3, Column 7]'));
    expect(find.text('Open Validation Panel'), findsNothing);

    h.service.onRender = (_, _) => throw RenderTimeout(Duration(seconds: 10));
    await tapKey(tester, h, ExportPage.previewKey);
    expect(errorText(tester), 'Export timed out after 10 s.');

    h.service.onRender = (_, _) => throw StateError('boom');
    await tapKey(tester, h, ExportPage.previewKey);
    expect(errorText(tester), 'Preview failed.');
    await tapKey(tester, h, ExportPage.executeKey);
    expect(errorText(tester), 'Export failed.');
  }, variant: linux);

  testWidgets(
    'an unsupported template is disabled with the design warning, the '
    'notice shows once per session and is logged once, and Edit opens the '
    'dialog with the caret at the reported position',
    (tester) async {
      final h = ExportHarness(
        templates: [
          template('tpl-bad', 'Bad Macro', macroSource),
          template('tpl-ok', 'Good', goodSource),
        ],
      );
      await h.pump(tester);
      final check = checkTemplate(macroSource)!;
      expect(check.line, 2);

      final items = selectorItems(tester);
      expect(items.firstWhere((i) => i.value == 'tpl-bad').enabled, isFalse);
      expect(items.firstWhere((i) => i.value == 'tpl-ok').enabled, isTrue);
      expect(
        find.text(
          'Bad Macro: ${check.message} (line 2, column ${check.column}), '
          'which Anvil 0.2 does not support. Edit the template to export '
          'with it.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(ExportPage.unsupportedKey('tpl-ok')), findsNothing);

      // A tap on the disabled entry selects nothing.
      await tester.tap(find.byKey(ExportPage.selectorKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bad Macro').last, warnIfMissed: false);
      await tester.pumpAndSettle();
      if (find.text('Nested JSON').evaluate().length > 1) {
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
      }
      expect(h.state.selectedId, 'nested-json');

      // The one notice.
      const notice = '1 custom template needs changes before it can export';
      expect(find.text(notice), findsOneWidget);
      expect(h.logLines.where((l) => l.contains(notice)), hasLength(1));
      expect(h.logLines.single, contains('[WARN'));

      // Edit lands on line 2, column C.
      await tapKey(tester, h, ExportPage.unsupportedEditKey('tpl-bad'));
      expect(find.text('Edit Template'), findsOneWidget);
      final field = tester.widget<TextField>(find.byKey(templateSourceKey));
      expect(field.controller!.text, macroSource);
      expect(
        field.controller!.selection,
        TextSelection.collapsed(
          offset: caretOffset(macroSource, 2, check.column),
        ),
      );
      expect(
        macroSource.substring(caretOffset(macroSource, 2, check.column)),
        startsWith('macro'),
      );
      expect(
        tester.widget<Text>(find.byKey(templateCheckKey)).data,
        '${check.message} (line 2, column ${check.column})',
      );
      await tapKey(tester, h, templateCancelKey);

      // A write re-lists the selectors, and the notice does not return.
      ScaffoldMessenger.of(tester.element(find.byType(ExportPage)))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();
      final lists = h.service.listCount;
      h.container.read(writeEpochProvider.notifier).bump();
      await h.settle(tester);
      expect(h.service.listCount, lists + 1);
      expect(find.text(notice), findsNothing);

      // Nor after leaving the page and coming back.
      h.container.read(routerProvider).go('/validation');
      await h.settle(tester);
      h.container.read(routerProvider).go('/export');
      await h.settle(tester);
      expect(find.byType(ExportPage), findsOneWidget);
      expect(find.text(notice), findsNothing);
      expect(h.logLines.where((l) => l.contains(notice)), hasLength(1));
    },
    variant: linux,
  );

  testWidgets('a selected template edited into one Anvil cannot run falls '
      'back to the first preset', (tester) async {
    final h = ExportHarness(
      templates: [template('tpl-ok', 'Good', goodSource)],
    );
    await h.pump(tester);
    await choose(tester, h, ExportPage.selectorKey, 'Good');
    expect(h.state.selectedId, 'tpl-ok');

    await tapKey(tester, h, ExportPage.editTemplateKey);
    await tester.enterText(find.byKey(templateSourceKey), macroSource);
    await tester.pump(templateCheckDelay);
    expect(find.byKey(templateCheckKey), findsOneWidget);
    // The warning never blocks saving: the source is stored as typed.
    await tapKey(tester, h, templateSaveKey);

    expect(h.templates.templates.single.templateSource, macroSource);
    expect(h.state.selectedId, 'nested-json');
    expect(find.byKey(ExportPage.unsupportedKey('tpl-ok')), findsOneWidget);
  }, variant: linux);

  testWidgets('execute writes the output through the save dialog, which starts '
      'in the exports folder (created) with the suggested name, as UTF-8', (
    tester,
  ) async {
    final h = ExportHarness();
    await h.pump(tester);
    const text = '{\n  "name": "Épée ✓"\n}\n';
    h.service.onRender = (_, _) =>
        ExportOutput(text: text, suggestedFileName: 'export.json');
    final target = '${h.dir.path}/chosen.json';
    h.dialogs.saveLocation = target;

    await tester.tap(find.byKey(ExportPage.executeKey));
    await pumpUntil(tester, () => h.state.success != null);

    expect(h.dialogs.requests, [
      'save location from ${h.exportsDir} as export.json',
    ]);
    expect(Directory(h.exportsDir).existsSync(), isTrue);
    expect(File(target).readAsBytesSync(), utf8.encode(text));
    expect(successText(tester), 'Exported to $target');
    expect(
      h.logLines.where((l) => l.contains('Export completed')),
      hasLength(1),
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(ExportPage.successKey),
        matching: find.byTooltip('Close'),
      ),
    );
    await h.settle(tester);
    expect(successText(tester), isNull);
  }, variant: linux);

  testWidgets('more than one CSV file asks for a folder and writes every file '
      'into it; one CSV file is saved as the summary text', (tester) async {
    final h = ExportHarness();
    await h.pump(tester);
    final files = [
      CsvFile('items.csv', 'id,name\ni-1,Bronze Axe\n'),
      CsvFile('classes.csv', 'id,name\nc-1,Mage\n'),
    ];
    h.service.onRender = (_, _) => ExportOutput(
      text: '--- items.csv ---\n...',
      files: files,
      suggestedFileName: 'export.txt',
    );
    final folder = '${h.dir.path}/csv-out';
    h.dialogs.directory = folder;

    await tester.tap(find.byKey(ExportPage.executeKey));
    await pumpUntil(tester, () => h.state.success != null);

    expect(h.dialogs.requests, ['directory from ${h.exportsDir}']);
    expect(successText(tester), 'Exported to $folder');
    for (final f in files) {
      expect(
        File('$folder/${f.filename}').readAsStringSync(),
        f.content,
        reason: f.filename,
      );
    }

    h.service.onRender = (_, _) => ExportOutput(
      text: '--- items.csv ---\nsummary',
      files: [files.first],
      suggestedFileName: 'export.txt',
    );
    h.dialogs
      ..requests.clear()
      ..saveLocation = '${h.dir.path}/one.txt';
    await tester.tap(find.byKey(ExportPage.executeKey));
    await pumpUntil(
      tester,
      () => h.state.success?.endsWith('one.txt') ?? false,
    );
    expect(h.dialogs.requests, [
      'save location from ${h.exportsDir} as export.txt',
    ]);
    expect(
      File('${h.dir.path}/one.txt').readAsStringSync(),
      '--- items.csv ---\nsummary',
    );
  }, variant: linux);

  testWidgets('cancelling either dialog shows Export canceled. and writes '
      'nothing', (tester) async {
    final h = ExportHarness();
    await h.pump(tester);

    await tester.tap(find.byKey(ExportPage.executeKey));
    await pumpUntil(tester, () => h.state.error != null);
    expect(errorText(tester), 'Export canceled.');
    expect(successText(tester), isNull);

    h.service.onRender = (_, _) => ExportOutput(
      text: '',
      files: [CsvFile('a.csv', 'a'), CsvFile('b.csv', 'b')],
      suggestedFileName: 'export.txt',
    );
    await tapKey(tester, h, ExportPage.errorCloseKey);
    await tester.tap(find.byKey(ExportPage.executeKey));
    await pumpUntil(tester, () => h.state.error != null);
    expect(errorText(tester), 'Export canceled.');
    expect(h.dialogs.requests.last, 'directory from ${h.exportsDir}');
    expect(Directory(h.exportsDir).listSync(), isEmpty);
  }, variant: linux);

  testWidgets('a project without the folder structure opens the dialogs at '
      'no folder', (tester) async {
    final h = ExportHarness();
    await h.pump(tester, projectFolder: false);
    await tester.tap(find.byKey(ExportPage.executeKey));
    await pumpUntil(tester, () => h.state.error != null);
    expect(h.dialogs.requests, ['save location from null as export.json']);
  }, variant: linux);

  testWidgets('New Template: Save waits for a name, both fields are trimmed, '
      'the source is kept as typed, the template is selected and the epoch '
      'bumped once', (tester) async {
    final h = ExportHarness();
    await h.pump(tester);

    await tapKey(tester, h, ExportPage.newTemplateKey);
    expect(find.text('New Custom Template'), findsOneWidget);
    expect(find.text('Create Template'), findsOneWidget);
    expect(find.text('Template Source (Nunjucks)'), findsOneWidget);
    expect(enabled(tester, templateSaveKey), isFalse);

    // The writing guide, verbatim, collapsed until toggled.
    expect(find.text(templateWritingGuide), findsNothing);
    await tapKey(tester, h, templateGuideToggleKey);
    expect(
      find.byWidgetPredicate(
        (w) => w is SelectableText && w.data == templateWritingGuide,
      ),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(templateNameKey), '   ');
    await tester.pump();
    expect(enabled(tester, templateSaveKey), isFalse);
    await tester.enterText(find.byKey(templateNameKey), '  Recipe Book  ');
    await tester.enterText(
      find.byKey(templateDescriptionKey),
      '  Recipes as text ',
    );
    await tester.enterText(find.byKey(templateSourceKey), '  $goodSource\n');
    await choose(tester, h, templateFormatKey, 'JSON');
    await tester.pump(templateCheckDelay);
    expect(find.byKey(templateCheckKey), findsNothing);
    expect(enabled(tester, templateSaveKey), isTrue);

    await tapKey(tester, h, templateSaveKey);

    expect(find.byType(TemplateDialog), findsNothing);
    final created = h.templates.templates.single;
    expect(created.name, 'Recipe Book');
    expect(created.description, 'Recipes as text');
    expect(created.templateSource, '  $goodSource\n');
    expect(created.format, 'json');
    expect(h.epoch, 1);
    expect(h.state.selectedId, created.id);
    expect(find.text('Recipes as text'), findsOneWidget);
  }, variant: linux);

  testWidgets(
    'Edit Template saves changes; Delete asks first, and deleting the '
    'selected template falls back to the first preset',
    (tester) async {
      final h = ExportHarness(
        templates: [
          template('tpl-1', 'Recipe Book', goodSource, format: 'csv'),
        ],
      );
      await h.pump(tester);
      await choose(tester, h, ExportPage.selectorKey, 'Recipe Book');

      await tapKey(tester, h, ExportPage.editTemplateKey);
      expect(find.text('Edit Template'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.text('CSV'), findsOneWidget);
      await tester.enterText(find.byKey(templateNameKey), 'Recipe Index ');
      await tapKey(tester, h, templateSaveKey);
      expect(h.templates.calls, ['update tpl-1']);
      expect(h.templates.templates.single.name, 'Recipe Index');
      expect(h.templates.templates.single.format, 'csv');
      expect(h.epoch, 1);
      expect(h.state.selectedId, 'tpl-1');

      // Cancel in the confirm dialog keeps the template.
      await tapKey(tester, h, ExportPage.deleteTemplateKey);
      expect(find.text('Delete template?'), findsOneWidget);
      await tapKey(tester, h, ExportPage.deleteCancelKey);
      expect(h.templates.templates, hasLength(1));
      expect(h.epoch, 1);

      await tapKey(tester, h, ExportPage.deleteTemplateKey);
      await tapKey(tester, h, ExportPage.deleteConfirmKey);
      expect(h.templates.templates, isEmpty);
      expect(h.epoch, 2);
      expect(h.state.selectedId, 'nested-json');
      expect(
        [for (final i in selectorItems(tester)) i.value],
        ['nested-json', 'flat-json', 'csv'],
      );
    },
    variant: linux,
  );

  testWidgets('a failed template save keeps the dialog open with the message', (
    tester,
  ) async {
    final h = ExportHarness();
    await h.pump(tester);
    h.templates.failure = SaveFailed('disk full', StateError('disk'));
    await tapKey(tester, h, ExportPage.newTemplateKey);
    await tester.enterText(find.byKey(templateNameKey), 'X');
    await tapKey(tester, h, templateSaveKey);
    expect(find.byType(TemplateDialog), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(templateErrorKey)).data, 'disk full');
    expect(h.epoch, 0);
  }, variant: linux);

  testWidgets('while editors hold unsaved changes the page says the export '
      'reflects saved records only', (tester) async {
    final h = ExportHarness();
    await h.pump(tester);
    expect(find.byKey(ExportPage.dirtyNoteKey), findsNothing);

    final dirty = h.container.read(dirtyEditorsProvider.notifier);
    for (final id in ['i-1', 'i-2']) {
      dirty.put(
        DirtyEditor(
          domain: SaveDomain.items,
          recordId: id,
          displayName: id,
          save: () async => SaveOutcome.saved,
          discard: () {},
        ),
      );
    }
    await h.settle(tester);
    expect(
      tester.widget<Text>(find.byKey(ExportPage.dirtyNoteKey)).data,
      'Export reflects saved records only. 2 record(s) have unsaved changes.',
    );

    dirty
      ..remove(SaveDomain.items, 'i-1')
      ..remove(SaveDomain.items, 'i-2');
    await h.settle(tester);
    expect(find.byKey(ExportPage.dirtyNoteKey), findsNothing);
  }, variant: linux);

  test('caretOffset maps a 1-based line and column, clamped', () {
    const text = 'ab\ncdef\n\ng';
    expect(caretOffset(text, 1, 1), 0);
    expect(caretOffset(text, 2, 3), 5);
    expect(caretOffset(text, 2, 99), 7);
    expect(caretOffset(text, 3, 4), 8);
    expect(caretOffset(text, 4, 1), 9);
    expect(caretOffset(text, 9, 1), text.length);
  });

  test('the notice texts', () {
    expect(
      unsupportedTemplatesNotice(1),
      '1 custom template needs changes before it can export',
    );
    expect(
      unsupportedTemplatesNotice(2),
      '2 custom templates need changes before they can export',
    );
  });
}
