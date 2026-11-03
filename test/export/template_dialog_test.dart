// The template dialog's draft and leave guard (ANVL-165).
import 'package:anvil/app/editor/dirty_editors.dart';
import 'package:anvil/app/editor/exit_prompt.dart';
import 'package:anvil/app/editor/save_status.dart';
import 'package:anvil/app/export/export_page.dart';
import 'package:anvil/app/export/template_dialog.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const _source = '{% for i in items %}{{ i.display_name }}\n{% endfor %}';

Future<void> _tapKey(WidgetTester tester, ExportHarness h, Key key) async {
  await tester.pump();
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await h.settle(tester);
}

bool _enabled(WidgetTester tester, Key key) =>
    tester.widget<ButtonStyleButton>(find.byKey(key)).onPressed != null;

Future<void> _escape(WidgetTester tester, ExportHarness h) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await h.settle(tester);
}

/// Opens the Edit dialog of the template named [name].
Future<void> _openEdit(
  WidgetTester tester,
  ExportHarness h,
  String name,
) async {
  await tester.ensureVisible(find.byKey(ExportPage.selectorKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ExportPage.selectorKey));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await h.settle(tester);
  await _tapKey(tester, h, ExportPage.editTemplateKey);
}

void main() {
  final dialog = find.byType(TemplateDialog);
  final prompt = find.text('Unsaved changes');
  const leaveCancel = ValueKey('leave-editor-cancel');
  const leaveDiscard = ValueKey('leave-editor-discard');
  const leaveSave = ValueKey('leave-editor-save');

  List<DirtyEditor> entries(ExportHarness h) =>
      h.container.read(dirtyEditorsProvider).entries;

  test('templateBaseline trims the stored name and description', () {
    expect(templateBaseline(null), (
      name: '',
      description: '',
      format: 'text',
      source: '',
    ));
    expect(
      templateBaseline(
        template('t', ' Book ', 'x', description: ' d ', format: 'csv'),
      ),
      (name: 'Book', description: 'd', format: 'csv', source: 'x'),
    );
  });

  testWidgets('a clean New dialog closes on Cancel and Escape with no prompt', (
    tester,
  ) async {
    final h = ExportHarness();
    await h.pump(tester);
    await _tapKey(tester, h, ExportPage.newTemplateKey);
    expect(_enabled(tester, templateSaveKey), isFalse);
    await _tapKey(tester, h, templateCancelKey);
    expect(prompt, findsNothing);
    expect(dialog, findsNothing);

    await _tapKey(tester, h, ExportPage.newTemplateKey);
    await _escape(tester, h);
    expect(prompt, findsNothing);
    expect(dialog, findsNothing);
    expect(entries(h), isEmpty);
    expect(h.templates.calls, isEmpty);
  }, variant: linux);

  testWidgets('a clean Edit dialog keeps Save disabled and closes with no '
      'prompt, writing nothing', (tester) async {
    final h = ExportHarness(
      templates: [template('tpl-1', 'Recipe Book', _source)],
    );
    await h.pump(tester);
    await _openEdit(tester, h, 'Recipe Book');
    expect(dialog, findsOneWidget);
    expect(_enabled(tester, templateSaveKey), isFalse);

    // Typing a change and typing it back is clean again.
    await tester.enterText(find.byKey(templateNameKey), 'Recipe Index');
    await tester.pump();
    expect(_enabled(tester, templateSaveKey), isTrue);
    expect(entries(h), hasLength(1));
    await tester.enterText(find.byKey(templateNameKey), 'Recipe Book');
    await tester.pump();
    expect(_enabled(tester, templateSaveKey), isFalse);
    expect(entries(h), isEmpty);

    await _tapKey(tester, h, templateCancelKey);
    expect(prompt, findsNothing);
    expect(dialog, findsNothing);
    expect(h.templates.calls, isEmpty);
    expect(h.epoch, 0);
  }, variant: linux);

  testWidgets('a dirty New dialog: Cancel prompts as New template (template); '
      'Cancel in the prompt stays, Discard closes and creates nothing', (
    tester,
  ) async {
    final h = ExportHarness();
    await h.pump(tester);
    await _tapKey(tester, h, ExportPage.newTemplateKey);
    await tester.enterText(find.byKey(templateNameKey), 'Recipe Book');
    await tester.pump();

    final entry = entries(h).single;
    expect(entry.domain, isNull);
    expect(entry.kind, 'template');
    expect(entry.displayName, 'New template');
    expect(h.container.read(saveStatusProvider), const Unsaved(1));

    await _tapKey(tester, h, templateCancelKey);
    expect(prompt, findsOneWidget);
    expect(find.text('New template (template)'), findsOneWidget);
    await _tapKey(tester, h, leaveCancel);
    expect(dialog, findsOneWidget);
    expect(find.text('Recipe Book'), findsOneWidget);

    await _escape(tester, h);
    expect(prompt, findsOneWidget);
    await _tapKey(tester, h, leaveDiscard);
    expect(dialog, findsNothing);
    expect(h.templates.calls, isEmpty);
    expect(h.epoch, 0);
    await h.settle(tester);
    expect(entries(h), isEmpty);
  }, variant: linux);

  testWidgets('a dirty New dialog without a name: the prompt disables Save', (
    tester,
  ) async {
    final h = ExportHarness();
    await h.pump(tester);
    await _tapKey(tester, h, ExportPage.newTemplateKey);
    await tester.enterText(find.byKey(templateSourceKey), _source);
    await tester.pump();
    await _escape(tester, h);
    expect(_enabled(tester, leaveSave), isFalse);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('leave-editor-problem')))
          .data,
      templateNameRequiredMessage,
    );
    await _tapKey(tester, h, leaveCancel);
    expect(dialog, findsOneWidget);
  }, variant: linux);

  testWidgets('a dirty Edit dialog: Escape, Save in the prompt updates once '
      'and closes', (tester) async {
    final h = ExportHarness(
      templates: [template('tpl-1', 'Recipe Book', _source)],
    );
    await h.pump(tester);
    await _openEdit(tester, h, 'Recipe Book');
    await tester.enterText(find.byKey(templateNameKey), 'Recipe Index');
    await tester.pump();
    expect(entries(h).single.displayName, 'Recipe Index');

    await _escape(tester, h);
    expect(find.text('Recipe Index (template)'), findsOneWidget);
    await _tapKey(tester, h, leaveSave);
    expect(prompt, findsNothing);
    expect(dialog, findsNothing);
    expect(h.templates.calls, ['update tpl-1']);
    expect(h.templates.templates.single.name, 'Recipe Index');
    expect(h.epoch, 1);
    await h.settle(tester);
    expect(entries(h), isEmpty);
  }, variant: linux);

  testWidgets('a failed save from the prompt keeps it open with the error', (
    tester,
  ) async {
    final h = ExportHarness();
    await h.pump(tester);
    h.templates.failure = SaveFailed('disk full', StateError('disk'));
    await _tapKey(tester, h, ExportPage.newTemplateKey);
    await tester.enterText(find.byKey(templateNameKey), 'X');
    await tester.pump();
    await _escape(tester, h);
    await _tapKey(tester, h, leaveSave);
    expect(prompt, findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('leave-editor-problem')))
          .data,
      'disk full',
    );
    expect(h.epoch, 0);
  }, variant: linux);

  testWidgets('the app exit prompt lists the dirty template, and Discard all '
      'resets it', (tester) async {
    final h = ExportHarness(
      templates: [template('tpl-1', 'Recipe Book', _source)],
    );
    await h.pump(tester);
    await _openEdit(tester, h, 'Recipe Book');
    await tester.enterText(find.byKey(templateDescriptionKey), 'Changed');
    await tester.pump();

    final page = find.byType(ExportPage);
    final ref = tester.state<ConsumerState<ExportPage>>(page).ref;
    final leave = confirmLeaveAll(tester.element(page), ref);
    await h.settle(tester);
    expect(find.text('Recipe Book (template)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('leave-all-discard')));
    await h.settle(tester);
    expect(await leave, isTrue);
    expect(entries(h), isEmpty);
    expect(find.text('Changed'), findsNothing);
    expect(_enabled(tester, templateSaveKey), isFalse);
    expect(h.templates.calls, isEmpty);
  }, variant: linux);
}
