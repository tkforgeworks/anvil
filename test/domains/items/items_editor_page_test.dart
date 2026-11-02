import 'package:anvil/app/domains/items/items_editor_controller.dart';
import 'package:anvil/app/domains/items/items_editor_page.dart';
import 'package:anvil/app/editor/widgets/custom_fields_panel.dart';
import 'package:anvil/app/editor/widgets/dirty_dot.dart';
import 'package:anvil/app/editor/widgets/validation_banner.dart';
import 'package:anvil/app/widgets/inspector_rail.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'item_fakes.dart';

Finder field(Key key) =>
    find.descendant(of: find.byKey(key), matching: find.byType(TextField));

Finder customField(String id) => find.byKey(CustomFieldsPanel.fieldKey(id));

Future<void> openTab(WidgetTester tester, ItemEditorTab tab) async {
  await tester.tap(find.byKey(tab.key));
  await tester.pumpAndSettle();
}

/// Picks [label] in the picker [key].
Future<void> pick(WidgetTester tester, Key key, String label) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

bool dot(WidgetTester tester, ItemEditorTab tab) => tester
    .widget<DirtyDot>(find.byKey(ValueKey('item-tab-dot-${tab.name}')))
    .visible;

void main() {
  late ItemHarness h;

  Future<void> pumpEditor(WidgetTester tester, [String id = swordId]) async {
    h = ItemHarness();
    await h.pump(tester, ItemEditorPage(id, onBack: () {}));
  }

  ItemDraft draft(String id) =>
      h.container.read(itemsEditorProvider(id)).requireValue.draft;

  testWidgets('shows the header, the three tabs and the Overview', (
    tester,
  ) async {
    await pumpEditor(tester);

    expect(find.text('Iron Sword'), findsWidgets);
    expect(find.text('iron-sword'), findsOneWidget);
    for (final tab in ItemEditorTab.values) {
      expect(find.byKey(tab.key), findsOneWidget);
    }
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('item-overview-description')))
          .data,
      'A plain blade.',
    );
  }, variant: linux);

  testWidgets('edits and undoes the export key, rarity and description', (
    tester,
  ) async {
    await pumpEditor(tester);
    await openTab(tester, ItemEditorTab.details);
    expect(find.byKey(const ValueKey('save-bar')), findsNothing);

    await tester.enterText(field(const ValueKey('item-export-key')), 'blade');
    await pick(tester, const ValueKey('item-rarity'), 'Rare');
    await tester.enterText(field(const ValueKey('item-description')), 'Sharp.');
    await tester.pumpAndSettle();
    expect(draft(swordId).exportKey, 'blade');
    expect(draft(swordId).rarityId, rare);
    expect(draft(swordId).description, 'Sharp.');
    expect(find.byKey(const ValueKey('save-bar')), findsOneWidget);
    expect(find.text('You have unsaved changes'), findsOneWidget);

    // Undo from outside any field steps the draft back one edit at a time.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('editor-undo')));
    await tester.pumpAndSettle();
    expect(draft(swordId).description, 'A plain blade.');
    await tester.tap(find.byKey(const ValueKey('editor-undo')));
    await tester.pumpAndSettle();
    expect(draft(swordId).rarityId, common);
    await tester.tap(find.byKey(const ValueKey('editor-undo')));
    await tester.pumpAndSettle();
    expect(draft(swordId).exportKey, 'iron-sword');
    expect(find.byKey(const ValueKey('save-bar')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('editor-redo')));
    await tester.pumpAndSettle();
    expect(draft(swordId).exportKey, 'blade');
  }, variant: linux);

  testWidgets('an empty export key blocks Save with the core message', (
    tester,
  ) async {
    await pumpEditor(tester);
    await openTab(tester, ItemEditorTab.details);

    await tester.enterText(field(const ValueKey('item-export-key')), '  ');
    await tester.pumpAndSettle();
    expect(find.text('Export key is required.'), findsWidgets);
    final save = tester.widget<FilledButton>(
      find.byKey(const ValueKey('save-bar-save')),
    );
    expect(save.onPressed, isNull);
  }, variant: linux);

  testWidgets('the Custom Fields tab edits each field type through the draft '
      'and undoes it', (tester) async {
    await pumpEditor(tester);
    await openTab(tester, ItemEditorTab.customFields);

    expect(find.text('Custom Fields'), findsWidgets);
    expect(find.text('Damage *'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(field(CustomFieldsPanel.fieldKey('field-damage')))
          .controller!
          .text,
      '12',
    );
    expect(find.text('ice'), findsOneWidget);

    await tester.enterText(
      field(CustomFieldsPanel.fieldKey('field-damage')),
      '15',
    );
    await tester.pumpAndSettle();
    expect(draft(swordId).customFieldValues['field-damage'], '15');
    expect(dot(tester, ItemEditorTab.customFields), isTrue);
    expect(dot(tester, ItemEditorTab.details), isFalse);

    await pick(tester, CustomFieldsPanel.fieldKey('field-element'), 'None');
    expect(draft(swordId).customFieldValues['field-element'], isNull);

    // An emptied text is stored as null, and a required one says so.
    await tester.enterText(
      field(CustomFieldsPanel.fieldKey('field-damage')),
      '',
    );
    await tester.pumpAndSettle();
    expect(
      draft(swordId).customFieldValues.containsKey('field-damage'),
      isTrue,
    );
    expect(draft(swordId).customFieldValues['field-damage'], isNull);
    expect(find.text(requiredFieldMessage), findsOneWidget);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(draft(swordId).customFieldValues['field-damage'], '15');
    await tester.tap(find.byKey(const ValueKey('editor-undo')));
    await tester.pumpAndSettle();
    expect(draft(swordId).customFieldValues['field-element'], 'ice');
    await tester.tap(find.byKey(const ValueKey('editor-undo')));
    await tester.pumpAndSettle();
    expect(draft(swordId).customFieldValues['field-damage'], '12');
    expect(dot(tester, ItemEditorTab.customFields), isFalse);
  }, variant: linux);

  testWidgets('a category change re-scopes the custom fields in one undo '
      'step, keeping values the new category defines', (tester) async {
    await pumpEditor(tester);
    await openTab(tester, ItemEditorTab.details);

    await pick(tester, const ValueKey('item-category'), 'Armor');
    // Damage and Element are weapon fields and go; the stored Slot value
    // is an armor field and stays; Heavy has no default and stays unset.
    expect(draft(swordId).itemCategoryId, armor);
    expect(draft(swordId).customFieldValues, {'field-slot': 'hand'});
    expect(dot(tester, ItemEditorTab.details), isTrue);
    expect(dot(tester, ItemEditorTab.customFields), isTrue);

    await openTab(tester, ItemEditorTab.customFields);
    expect(customField('field-slot'), findsOneWidget);
    expect(customField('field-heavy'), findsOneWidget);
    expect(customField('field-damage'), findsNothing);
    await tester.tap(
      find.descendant(
        of: customField('field-heavy'),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.pumpAndSettle();
    expect(draft(swordId).customFieldValues['field-heavy'], 'true');

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.byKey(const ValueKey('editor-undo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('editor-undo')));
    await tester.pumpAndSettle();
    expect(draft(swordId).itemCategoryId, weapon);
    expect(draft(swordId).customFieldValues, {
      'field-damage': '12',
      'field-element': 'ice',
      'field-slot': 'hand',
    });
    expect(customField('field-damage'), findsOneWidget);
  }, variant: linux);

  testWidgets('a new category fills its defaults where the item has no value, '
      'and loading does the same without dirtying the draft', (tester) async {
    await pumpEditor(tester, shieldId);
    // Tower Shield is armor with no value rows: Slot gets its default.
    expect(draft(shieldId).customFieldValues, {'field-slot': 'chest'});
    expect(find.byKey(const ValueKey('save-bar')), findsNothing);

    await openTab(tester, ItemEditorTab.details);
    await pick(tester, const ValueKey('item-category'), 'Weapon');
    expect(draft(shieldId).customFieldValues, {'field-element': 'fire'});
  }, variant: linux);

  testWidgets('Save writes the trimmed draft once, then shows the record '
      'validation on the banner and the field', (tester) async {
    await pumpEditor(tester);
    h.script.issues[swordId] = [
      itemIssue(swordId, 'custom:Damage', "Required field 'Damage' is empty."),
    ];
    await openTab(tester, ItemEditorTab.customFields);
    await tester.enterText(
      field(CustomFieldsPanel.fieldKey('field-damage')),
      '',
    );
    await tester.enterText(
      field(const ValueKey('editor-display-name')),
      '  Iron Sword+  ',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('save-bar-save')));
    await tester.pumpAndSettle();

    expect(h.items.calls.where((c) => c.startsWith('save')), ['save $swordId']);
    expect(h.items.saved.single.displayName, 'Iron Sword+');
    expect(h.items.saved.single.customFieldValues['field-damage'], isNull);
    expect(h.epoch, 1);
    expect(h.script.validations, 1);
    expect(find.byKey(const ValueKey('save-bar')), findsNothing);
    expect(find.byType(ValidationBanner), findsOneWidget);
    expect(find.text('Validation: 1 error'), findsOneWidget);
    expect(
      find.text("custom:Damage: Required field 'Damage' is empty."),
      findsOneWidget,
    );
    expect(draft(swordId).displayName, 'Iron Sword+');
  }, variant: linux);

  testWidgets('Ctrl+S saves and a failed save keeps the draft with the error', (
    tester,
  ) async {
    await pumpEditor(tester);
    h.items.saveError = const SaveFailed('disk full', 'io');
    await openTab(tester, ItemEditorTab.details);
    await pick(tester, const ValueKey('item-rarity'), 'Rare');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('editor-save-error')), findsOneWidget);
    expect(find.text('disk full'), findsOneWidget);
    expect(draft(swordId).rarityId, rare);
    expect(h.script.validations, 0);

    h.items.saveError = null;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(h.items.saved.single.rarityId, rare);
    expect(h.script.validations, 1);
  }, variant: linux);

  testWidgets('a reference issue after save shows on its picker', (
    tester,
  ) async {
    await pumpEditor(tester);
    h.script.issues[swordId] = [
      itemIssue(swordId, 'rarityId', "Rarity 'rarity-common' is deleted."),
    ];
    await openTab(tester, ItemEditorTab.details);
    await tester.enterText(field(const ValueKey('item-description')), 'x');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    final decorator = tester.widget<InputDecorator>(
      find.descendant(
        of: find.byKey(const ValueKey('item-rarity')),
        matching: find.byType(InputDecorator),
      ),
    );
    expect(
      decorator.decoration.errorText,
      "Rarity 'rarity-common' is deleted.",
    );
  }, variant: linux);

  testWidgets('lays out at its natural height inside a scroll view, as the '
      'editor dialog hosts it', (tester) async {
    h = ItemHarness();
    await h.pump(
      tester,
      SingleChildScrollView(child: ItemEditorPage(swordId, onBack: () {})),
    );
    expect(tester.takeException(), isNull);
    await openTab(tester, ItemEditorTab.details);
    await pick(tester, const ValueKey('item-rarity'), 'Rare');
    await tester.tap(find.byKey(const ValueKey('save-bar-save')));
    await tester.pumpAndSettle();
    expect(h.items.saved.single.rarityId, rare);
  }, variant: linux);

  testWidgets('the rail lists the recipes and loot tables that use the item', (
    tester,
  ) async {
    h = ItemHarness();
    h.items.usedByScript[swordId] = ItemUsedBy(
      recipes: const [UsedByRef('recipe-1', 'Forge Iron Sword')],
      lootTables: const [
        UsedByRef('loot-1', 'Goblin Drops'),
        UsedByRef('loot-2', 'Chest'),
      ],
    );
    await h.pump(tester, ItemEditorPage(swordId, onBack: () {}));

    expect(find.byType(InspectorRail), findsOneWidget);
    expect(find.text('Crafting Recipes'), findsOneWidget);
    expect(find.text('Loot Tables'), findsOneWidget);
    expect(find.byKey(InspectorRail.entryKey('recipe-1')), findsOneWidget);
    expect(find.byKey(InspectorRail.entryKey('loot-2')), findsOneWidget);
  }, variant: linux);

  testWidgets('an unknown item shows the not-found view', (tester) async {
    var back = 0;
    h = ItemHarness();
    await h.pump(tester, ItemEditorPage('nope', onBack: () => back++));

    expect(find.text('Item not found.'), findsOneWidget);
    await tester.tap(find.text('Back to Items'));
    expect(back, 1);
  }, variant: linux);
}
