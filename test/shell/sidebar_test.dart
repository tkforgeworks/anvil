import 'dart:io';

import 'package:anvil/app/shell/shell_domain.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil/app/shell/sidebar.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge_ui/forge_ui.dart';

import 'shell_harness.dart';

/// The 0.1.6 fixture's active records (one ability and one item are
/// soft-deleted).
const fixtureCounts = {
  ShellDomain.classes: 2,
  ShellDomain.abilities: 2,
  ShellDomain.items: 5,
  ShellDomain.recipes: 2,
  ShellDomain.npcs: 2,
  ShellDomain.lootTables: 1,
};

String? textOf(WidgetTester tester, Key key) {
  final found = find.descendant(
    of: find.byKey(key),
    matching: find.byType(Text),
    matchRoot: true,
  );
  return found.evaluate().isEmpty
      ? null
      : tester.widget<Text>(found.first).data;
}

Color? badgeColor(WidgetTester tester, String entry) {
  final box = tester.widget<Container>(
    find.descendant(
      of: find.byKey(Sidebar.badgeKey(entry)),
      matching: find.byType(Container),
      matchRoot: true,
    ),
  );
  return (box.decoration as BoxDecoration?)?.color;
}

String badgeText(int n) => n > 99 ? '99+' : '$n';

void main() {
  testWidgets('counts and badges match the fixture and follow a soft delete', (
    tester,
  ) async {
    final harness = await ShellHarness.pump(tester);
    await harness.openProject(tester);
    final context = tester.element(find.byType(Sidebar));

    for (final MapEntry(key: domain, value: n) in fixtureCounts.entries) {
      expect(textOf(tester, Sidebar.countKey(domain)), '$n', reason: '$domain');
    }
    expect(textOf(tester, Sidebar.badgeKey('recycle-bin')), '2');
    expect(badgeColor(tester, 'recycle-bin'), context.colors.onSurfaceVariant);

    Future<void> expectValidationBadge() async {
      final issues = await validateFile(tester, harness.path);
      final n = badgeCount(issues);
      if (n == 0) {
        expect(find.byKey(Sidebar.badgeKey('validation')), findsNothing);
        return;
      }
      expect(textOf(tester, Sidebar.badgeKey('validation')), badgeText(n));
      final hasErrors = issues.any(
        (i) => i.severity == ValidationSeverity.error,
      );
      expect(
        badgeColor(tester, 'validation'),
        hasErrors ? context.colors.error : context.forge.warning,
      );
    }

    await expectValidationBadge();

    final items = harness.container.read(itemRepositoryProvider);
    final id = (await tester.runAsync(items.list))!.first.id;
    await tester.runAsync(() => items.softDelete(id));
    harness.container.read(writeEpochProvider.notifier).bump();
    // Counts and trash re-read at once; validation after its debounce.
    await tester.pump();
    await tester.pump(ValidationIssuesNotifier.debounce);
    await harness.settleShell(tester);

    expect(textOf(tester, Sidebar.countKey(ShellDomain.items)), '4');
    expect(textOf(tester, Sidebar.badgeKey('recycle-bin')), '3');
    for (final domain in ShellDomain.values.where(
      (d) => d != ShellDomain.items,
    )) {
      expect(
        textOf(tester, Sidebar.countKey(domain)),
        '${fixtureCounts[domain]}',
      );
    }
    await expectValidationBadge();
  }, variant: linux);

  testWidgets(
    'collapse shows icons with tooltips and badge dots; expand restores it',
    (tester) async {
      final harness = await ShellHarness.pump(tester);
      await harness.openProject(tester);
      final issues = harness.container.read(validationIssuesProvider).value!;
      final hasIssues = badgeCount(issues) > 0;
      const labels = [
        'Dashboard',
        'Classes',
        'Abilities',
        'Items',
        'Recipes',
        'NPCs',
        'Loot Tables',
        'Validation',
        'Recycle Bin',
        'Export',
      ];
      Finder inSidebar(Finder f) =>
          find.descendant(of: find.byType(Sidebar), matching: f);

      expect(tester.getSize(find.byType(Sidebar)).width, 220);
      expect(find.byTooltip('Collapse sidebar'), findsOneWidget);
      for (final label in labels) {
        expect(inSidebar(find.text(label)), findsOneWidget);
        expect(find.byTooltip(label), findsNothing);
      }

      await tester.tap(find.byKey(Sidebar.toggleKey));
      // Mid-transition: content keeps its layout width and is clipped.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final mid = tester.getSize(find.byType(Sidebar)).width;
      expect(mid, inExclusiveRange(56, 220));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(Sidebar)).width, 56);
      expect(find.byTooltip('Expand sidebar'), findsOneWidget);
      for (final label in labels) {
        expect(find.byTooltip(label), findsOneWidget, reason: label);
        expect(inSidebar(find.text(label)), findsNothing, reason: label);
      }
      for (final domain in ShellDomain.values) {
        expect(find.byKey(Sidebar.countKey(domain)), findsNothing);
      }
      expect(find.byKey(Sidebar.badgeKey('recycle-bin')), findsNothing);
      expect(find.byKey(Sidebar.dotKey('recycle-bin')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(Sidebar.dotKey('recycle-bin'))),
        const Size(8, 8),
      );
      expect(
        find.byKey(Sidebar.dotKey('validation')),
        hasIssues ? findsOneWidget : findsNothing,
      );
      expect(find.byKey(Sidebar.dotKey('export')), findsNothing);
      expect(find.byKey(Sidebar.dotKey('items')), findsNothing);

      // A collapsed entry still navigates.
      await tester.tap(find.byTooltip('Items'));
      await tester.pumpAndSettle();
      expect(harness.location, '/items');

      await tester.tap(find.byKey(Sidebar.toggleKey));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(Sidebar)).width, 220);
      for (final label in labels) {
        expect(inSidebar(find.text(label)), findsOneWidget);
      }
      expect(textOf(tester, Sidebar.countKey(ShellDomain.items)), '5');
      // Session-only, as 0.1.6's ui.store: nothing was written to settings.
      expect(File(harness.app.store.filePath).existsSync(), isFalse);
    },
    variant: linux,
  );
}
