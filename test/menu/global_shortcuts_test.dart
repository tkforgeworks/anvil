import 'dart:math' as math;

import 'package:anvil/app/menu/kbd_pill.dart';
import 'package:anvil/app/menu/menu_commands.dart';
import 'package:anvil/app/menu/shortcut_registry.dart';
import 'package:anvil/app/menu/shortcuts_dialog.dart';
import 'package:anvil/app/menu/ui_scale.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil/app/welcome/create_project_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../dialogs/fakes.dart';
import 'menu_harness.dart';

final editorField = find.byKey(const Key('editor-field'));
final plainField = find.byKey(const Key('plain-field'));

String fieldText(WidgetTester tester, Finder field) => tester
    .widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    )
    .controller
    .text;

/// Focuses [field] and types [text] with pauses that let the field's undo
/// history record the steps (ANVL-158 gotcha 1).
Future<void> type(WidgetTester tester, Finder field, String text) async {
  await tester.showKeyboard(field);
  await tester.pump(const Duration(milliseconds: 600));
  await tester.enterText(field, text);
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('with an editor focused, Ctrl+S, Ctrl+Z, Ctrl+Shift+Z and '
      'Ctrl+Y reach it, and the menu Save row saves it', (tester) async {
    await MenuHarness.pump(tester);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'editor');

    expect(await ctrl(tester, LogicalKeyboardKey.keyS), isTrue);
    expect(await ctrl(tester, LogicalKeyboardKey.keyZ), isTrue);
    expect(await ctrl(tester, LogicalKeyboardKey.keyZ, shift: true), isTrue);
    expect(await ctrl(tester, LogicalKeyboardKey.keyY), isTrue);
    expect(editorCalls, ['save', 'undo', 'redo', 'redo']);

    await openSection(tester, 'File');
    expect(rowWidget(tester, MenuCommand.save).onPressed, isNotNull);
    await tester.tap(row(MenuCommand.save));
    await tester.pumpAndSettle();
    expect(editorCalls, ['save', 'undo', 'redo', 'redo', 'save']);
    // Focus is back in the editor once the menu has closed.
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'editor');
  }, variant: linux);

  testWidgets('without an editor, Save, Undo and Redo are disabled: the row '
      'is greyed and the keys fall through unhandled', (tester) async {
    await MenuHarness.pump(tester, initialLocation: '/plain');

    expect(await ctrl(tester, LogicalKeyboardKey.keyS), isFalse);
    expect(await ctrl(tester, LogicalKeyboardKey.keyZ), isFalse);
    expect(await ctrl(tester, LogicalKeyboardKey.keyZ, shift: true), isFalse);
    expect(editorCalls, isEmpty);

    await openSection(tester, 'File');
    expect(rowWidget(tester, MenuCommand.save).onPressed, isNull);
    expect(commandEnabledProbe(tester, MenuCommand.undo), isFalse);
  }, variant: linux);

  testWidgets('an override {"save": "Ctrl+Shift+S"} rebinds Save from the '
      'settings file', (tester) async {
    await MenuHarness.pump(
      tester,
      settingsJson: '{"customShortcuts": {"save": "Ctrl+Shift+S"}}',
    );
    expect(await ctrl(tester, LogicalKeyboardKey.keyS, shift: true), isTrue);
    expect(editorCalls, ['save']);

    await openSection(tester, 'File');
    expect(
      rowWidget(tester, MenuCommand.save).shortcut,
      isA<SingleActivator>()
          .having((a) => a.trigger, 'trigger', LogicalKeyboardKey.keyS)
          .having((a) => a.shift, 'shift', isTrue),
    );
  }, variant: linux);

  testWidgets('an invalid override is logged and the default kept', (
    tester,
  ) async {
    final harness = await MenuHarness.pump(
      tester,
      settingsJson: '{"customShortcuts": {"zoom-in": "Hyper+Up"}}',
    );
    expect(
      bindingFor(
        harness.container!.read(shortcutBindingsProvider),
        MenuCommand.zoomIn,
      )!.binding,
      'Ctrl+=',
    );
    expect(
      harness.app.logLines.join('\n'),
      contains('Ignoring custom shortcut for zoom-in'),
    );
  }, variant: linux);

  testWidgets("a text field's own Ctrl+Z still undoes its text, inside an "
      'editor and outside one', (tester) async {
    await MenuHarness.pump(tester);
    await type(tester, editorField, 'abc');
    expect(await ctrl(tester, LogicalKeyboardKey.keyZ), isTrue);
    expect(fieldText(tester, editorField), '');
    expect(editorCalls, isEmpty);

    // Redo through the framework's text redo, too.
    expect(await ctrl(tester, LogicalKeyboardKey.keyZ, shift: true), isTrue);
    expect(fieldText(tester, editorField), 'abc');
    expect(editorCalls, isEmpty);
  }, variant: linux);

  testWidgets("a text field's own Ctrl+Z works outside an editor", (
    tester,
  ) async {
    await MenuHarness.pump(tester, initialLocation: '/plain');
    await type(tester, plainField, 'xyz');
    expect(await ctrl(tester, LogicalKeyboardKey.keyZ), isTrue);
    expect(fieldText(tester, plainField), '');
  }, variant: linux);

  testWidgets('navigation and view shortcuts run from the keyboard, but not '
      'while a text field has focus', (tester) async {
    final harness = await MenuHarness.pump(tester, initialLocation: '/plain');
    expect(await ctrl(tester, LogicalKeyboardKey.digit2), isTrue);
    expect(harness.location, '/classes');
    expect(await ctrl(tester, LogicalKeyboardKey.keyB), isTrue);
    expect(harness.container!.read(sidebarCollapsedProvider), isTrue);

    harness.router.go('/plain');
    await tester.pumpAndSettle();
    await tester.showKeyboard(plainField);
    expect(await ctrl(tester, LogicalKeyboardKey.digit4), isFalse);
    expect(harness.location, '/plain');
  }, variant: linux);

  testWidgets('Ctrl+= zooms the whole UI: the scale provider and the '
      'rendered size; Ctrl+- and Ctrl+0 step back', (tester) async {
    final harness = await MenuHarness.pump(tester, initialLocation: '/plain');
    final text = find.text('Plain page');
    final before = tester.getRect(text);

    expect(await ctrl(tester, LogicalKeyboardKey.equal), isTrue);
    final scale = harness.container!.read(uiScaleProvider);
    expect(scale, closeTo(math.pow(1.2, 0.5), 1e-9));
    final after = tester.getRect(text);
    expect(after.width / before.width, closeTo(scale, 0.01));
    expect(after.height / before.height, closeTo(scale, 0.01));

    // Hit testing follows the scale: the field still takes a tap.
    await tester.tap(plainField);
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<TextField>(),
      isNotNull,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    expect(await ctrl(tester, LogicalKeyboardKey.minus), isTrue);
    expect(await ctrl(tester, LogicalKeyboardKey.minus), isTrue);
    expect(harness.container!.read(uiScaleProvider), lessThan(1));
    expect(await ctrl(tester, LogicalKeyboardKey.digit0), isTrue);
    expect(harness.container!.read(uiScaleProvider), 1);
    expect(tester.getRect(text), before);
  }, variant: linux);

  testWidgets('Ctrl+/ opens the cheatsheet with the bindings in effect', (
    tester,
  ) async {
    await MenuHarness.pump(
      tester,
      initialLocation: '/plain',
      settingsJson: '{"customShortcuts": {"redo": "Ctrl+Y"}}',
    );
    expect(await ctrl(tester, LogicalKeyboardKey.slash), isTrue);
    expect(find.byType(ShortcutsDialog), findsOneWidget);
    // The title and the Help entry of the same name.
    expect(
      find.descendant(
        of: find.byType(ShortcutsDialog),
        matching: find.text('Keyboard Shortcuts'),
      ),
      findsNWidgets(2),
    );
    for (final group in ShortcutGroup.values) {
      expect(find.text(group.label.toUpperCase()), findsOneWidget);
    }
    for (final entry in shortcutRegistry) {
      final pill = tester.widget<KbdPill>(
        find.byKey(ValueKey('kbd-${entry.id}')),
      );
      expect(
        pill.binding,
        entry.id == 'redo' ? 'Ctrl+Y' : entry.defaultBinding,
        reason: entry.id,
      );
    }
    // Shortcuts are off while the dialog has focus; Esc closes it.
    expect(await ctrl(tester, LogicalKeyboardKey.digit2), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(ShortcutsDialog), findsNothing);
  }, variant: linux);

  testWidgets('on the welcome page Ctrl+N and Ctrl+O work and the project '
      'commands are off', (tester) async {
    final harness = LifecycleHarness.create();
    await harness.pump(tester);

    expect(await ctrl(tester, LogicalKeyboardKey.keyW), isFalse);
    expect(await ctrl(tester, LogicalKeyboardKey.digit2), isFalse);

    expect(await ctrl(tester, LogicalKeyboardKey.keyO), isTrue);
    expect(harness.dialogs.requests, ['anvil file from null']);

    expect(await ctrl(tester, LogicalKeyboardKey.keyN), isTrue);
    expect(find.byType(CreateProjectDialog), findsOneWidget);
  }, variant: linux);
}

/// Whether [command] would run from the current primary focus.
bool commandEnabledProbe(WidgetTester tester, MenuCommand command) =>
    editorCommandEnabled(command);
