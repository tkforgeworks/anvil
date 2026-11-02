import 'package:anvil/app/dashboard/count_tile.dart';
import 'package:anvil/app/dashboard/dashboard_card.dart';
import 'package:anvil/app/dashboard/dashboard_page.dart';
import 'package:anvil/app/dashboard/dashboard_providers.dart';
import 'package:anvil/app/dashboard/quick_add.dart';
import 'package:anvil/app/dashboard/save_history_feed.dart';
import 'package:anvil/app/dashboard/status_tag.dart';
import 'package:anvil/app/dashboard/validation_tile.dart';
import 'package:anvil/app/domains/abilities/create_ability_dialog.dart';
import 'package:anvil/app/editor/save_status.dart';
import 'package:anvil/app/shell/shell_domain.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil/app/theme/anvil_theme.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge_ui/forge_ui.dart';

import '../domains/abilities/fakes.dart' show FakeAbilityRepository;
import 'dashboard_fakes.dart';

Finder _inTile(ShellDomain domain, String text) => find.descendant(
  of: find.byKey(CountTile.keyOf(domain)),
  matching: find.text(text),
);

void main() {
  group('pure rules', () {
    test('weekly delta labels', () {
      expect(formatWeeklyDelta(2), '+2 this wk');
      expect(formatWeeklyDelta(-1), '-1 this wk');
      expect(formatWeeklyDelta(0), 'stable');
    });

    test('a 0.1.6 auto-save row without description reads Auto-save', () {
      final old = sampleHistory[1];
      expect(saveEntryTitle(old), 'Auto-save');
      expect(saveEntryKind(old), 'Auto-save');
      final current = sampleHistory[0];
      expect(saveEntryTitle(current), 'Fireball - Ability changed');
      expect(saveEntryKind(current), 'Manual save');
      const manual = SaveHistoryEntry(
        id: 3,
        savedAt: '2026-11-01T11:00:00Z',
        description: '',
        isAutoSave: false,
      );
      expect(saveEntryTitle(manual), 'Manual save');
    });

    test('validation tile texts', () {
      expect(validationTileTitle(0), 'No issues');
      expect(validationTileTitle(1), '1 issue');
      expect(validationTileTitle(3), '3 issues');
      expect(validationTileDetail(0, 0), '');
      expect(validationTileDetail(1, 2), '1 error, 2 warnings');
      expect(validationTileDetail(0, 1), '1 warning');
      expect(validationTileDetail(2, 0), '2 errors');
    });

    test('status tag labels are 0.1.6 StatusTag ones', () {
      expect(StatusTag.labelOf(const AllSaved()), 'saved');
      expect(StatusTag.labelOf(const Saving()), 'saving…');
      expect(StatusTag.labelOf(const Unsaved(2)), 'unsaved');
      expect(StatusTag.labelOf(const SaveError('x')), 'error');
    });
  });

  testWidgets(
    'the hero shows the project, the save status, the last save and the '
    'folder with the file size',
    (tester) async {
      final harness = PageHarness();
      await harness.pump(tester, const DashboardPage());

      final hero = find.byKey(DashboardPage.heroKey);
      Finder inHero(String text) =>
          find.descendant(of: hero, matching: find.text(text));
      expect(inHero('Spike Fixture'), findsOneWidget);
      expect(inHero('SF'), findsOneWidget);
      expect(inHero('saved'), findsOneWidget);
      // The newest save history row, an hour before the test clock.
      expect(inHero('Last saved 1 hour ago'), findsOneWidget);
      expect(inHero('/projects/Spike Fixture · 200.0 KB'), findsOneWidget);
      expect(find.byKey(QuickAddButton.buttonKey), findsOneWidget);
    },
    variant: linux,
  );

  testWidgets('with no save history the hero falls back to the file time', (
    tester,
  ) async {
    final harness = PageHarness(history: const []);
    await harness.pump(tester, const DashboardPage());

    expect(find.text('Last saved 2 days ago'), findsOneWidget);
    expect(find.text('No saves recorded yet.'), findsOneWidget);
    expect(find.text('last 0 saves'), findsOneWidget);
  }, variant: linux);

  testWidgets(
    'the six tiles show counts and weekly deltas and open their lists',
    (tester) async {
      final harness = PageHarness();
      await harness.pump(tester, const DashboardPage());

      expect(_inTile(ShellDomain.classes, 'CLASSES'), findsOneWidget);
      expect(_inTile(ShellDomain.classes, '2'), findsOneWidget);
      expect(_inTile(ShellDomain.classes, '+2 this wk'), findsOneWidget);
      expect(_inTile(ShellDomain.abilities, '-1 this wk'), findsOneWidget);
      expect(_inTile(ShellDomain.items, '5'), findsOneWidget);
      expect(_inTile(ShellDomain.items, 'stable'), findsOneWidget);
      expect(_inTile(ShellDomain.lootTables, 'LOOT TABLES'), findsOneWidget);
      expect(_inTile(ShellDomain.lootTables, '1'), findsOneWidget);
      expect(find.text('stable'), findsNWidgets(4));

      // All six on one row at the minimum window with the sidebar open.
      final tops = {
        for (final d in ShellDomain.values)
          tester.getTopLeft(find.byKey(CountTile.keyOf(d))).dy,
      };
      expect(tops, hasLength(1));

      await tester.tap(find.byKey(CountTile.keyOf(ShellDomain.lootTables)));
      await tester.pumpAndSettle();
      expect(harness.location, '/loot-tables');
    },
    variant: linux,
  );

  testWidgets('the tiles wrap onto a second row instead of squeezing', (
    tester,
  ) async {
    final harness = PageHarness();
    await harness.pump(
      tester,
      const Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 500, child: DashboardPage()),
      ),
    );

    final tops = {
      for (final d in ShellDomain.values)
        tester.getTopLeft(find.byKey(CountTile.keyOf(d))).dy,
    };
    expect(tops.length, greaterThan(1));
    for (final d in ShellDomain.values) {
      expect(
        tester.getSize(find.byKey(CountTile.keyOf(d))).width,
        greaterThanOrEqualTo(CountTiles.minTileWidth),
      );
    }
  }, variant: linux);

  testWidgets('the save history shows a 0.2.0 row and a 0.1.6 auto-save row', (
    tester,
  ) async {
    final harness = PageHarness();
    await harness.pump(tester, const DashboardPage());

    expect(harness.saveHistory.limits, [dashboardSaveHistoryLimit]);
    expect(find.text('Save history'), findsOneWidget);
    expect(find.text('last 2 saves'), findsOneWidget);

    Finder inRow(int i, String text) => find.descendant(
      of: find.byKey(SaveHistoryFeed.rowKey(i)),
      matching: find.text(text),
    );
    expect(inRow(0, 'Fireball - Ability changed'), findsOneWidget);
    expect(inRow(0, 'Manual save'), findsOneWidget);
    expect(inRow(0, '1 hour ago'), findsOneWidget);
    // The 0.1.6 row has no description: its kind is the only line.
    expect(inRow(1, 'Auto-save'), findsOneWidget);
    expect(inRow(1, 'Manual save'), findsNothing);
    expect(inRow(1, 'last week'), findsNothing);
    expect(inRow(1, 'Oct 11, 2026'), findsOneWidget);
  }, variant: linux);

  group('validation tile', () {
    Future<DashboardCard> pumpWith(
      WidgetTester tester,
      List<ValidationIssue> issues,
    ) async {
      final harness = PageHarness(issues: issues);
      await harness.pump(tester, const DashboardPage());
      return tester.widget<DashboardCard>(find.byKey(ValidationTile.tileKey));
    }

    testWidgets('no issues', (tester) async {
      final tile = await pumpWith(tester, const []);
      expect(find.text('No issues'), findsOneWidget);
      expect(tile.borderColor, isNull);
    }, variant: linux);

    testWidgets('warnings only: warning border', (tester) async {
      final tile = await pumpWith(tester, [
        issue(
          ValidationDomain.items,
          'i',
          'Axe',
          ValidationSeverity.warning,
          'w1',
        ),
        issue(
          ValidationDomain.items,
          'j',
          'Bow',
          ValidationSeverity.warning,
          'w2',
        ),
        issue(ValidationDomain.items, 'k', 'Cap', ValidationSeverity.info, 'i'),
      ]);
      expect(find.text('2 issues'), findsOneWidget);
      expect(find.text('2 warnings'), findsOneWidget);
      final context = tester.element(find.byKey(ValidationTile.tileKey));
      expect(tile.borderColor, context.forge.warning);
    }, variant: linux);

    testWidgets('an error: error border, then a tap opens Validation', (
      tester,
    ) async {
      final harness = PageHarness(
        issues: [
          issue(
            ValidationDomain.items,
            'i',
            'Axe',
            ValidationSeverity.error,
            'e',
          ),
          issue(
            ValidationDomain.npcs,
            'n',
            'Orc',
            ValidationSeverity.warning,
            'w',
          ),
          issue(
            ValidationDomain.npcs,
            'm',
            'Elf',
            ValidationSeverity.warning,
            'w',
          ),
        ],
      );
      await harness.pump(tester, const DashboardPage());
      final tile = tester.widget<DashboardCard>(
        find.byKey(ValidationTile.tileKey),
      );
      expect(find.text('3 issues'), findsOneWidget);
      expect(find.text('1 error, 2 warnings'), findsOneWidget);
      final context = tester.element(find.byKey(ValidationTile.tileKey));
      expect(tile.borderColor, context.colors.error);

      await tester.tap(find.byKey(ValidationTile.tileKey));
      await tester.pumpAndSettle();
      expect(harness.location, '/validation');
    }, variant: linux);
  });

  testWidgets('Quick add from the hero menu creates an ability and opens it', (
    tester,
  ) async {
    final abilities = FakeAbilityRepository([]);
    final harness = PageHarness();
    await harness.pump(
      tester,
      const DashboardPage(),
      overrides: [abilityRepositoryProvider.overrideWithValue(abilities)],
    );
    final deltaReads = harness.lifecycle.reads;

    await tester.tap(find.byKey(QuickAddButton.buttonKey));
    await tester.pumpAndSettle();
    for (final d in ShellDomain.values) {
      expect(find.byKey(QuickAddButton.itemKey(d)), findsOneWidget);
    }
    for (final d in ShellDomain.values) {
      expect(
        tester
            .widget<MenuItemButton>(find.byKey(QuickAddButton.itemKey(d)))
            .onPressed,
        isNotNull,
      );
    }
    await tester.tap(find.byKey(QuickAddButton.itemKey(ShellDomain.abilities)));
    await tester.pumpAndSettle();

    expect(find.byType(CreateAbilityDialog), findsOneWidget);
    await tester.enterText(find.byKey(CreateAbilityDialog.nameKey), 'Blink');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(CreateAbilityDialog.createKey));
    await tester.pumpAndSettle();

    expect(abilities.calls, contains('create Blink blink'));
    expect(harness.location, '/abilities/ability-new-1');
    // The create bumped the epoch once: the deltas were re-read.
    expect(harness.container.read(writeEpochProvider), 1);
    expect(harness.lifecycle.reads, greaterThan(deltaReads));
  }, variant: linux);

  testWidgets(
    'Quick add chips: every domain is enabled; cancelling opens nothing',
    (tester) async {
      final abilities = FakeAbilityRepository([]);
      final harness = PageHarness();
      await harness.pump(
        tester,
        const DashboardPage(),
        overrides: [abilityRepositoryProvider.overrideWithValue(abilities)],
      );

      for (final d in ShellDomain.values) {
        expect(
          tester
              .widget<ActionChip>(find.byKey(QuickAddCard.chipKey(d)))
              .onPressed,
          isNotNull,
        );
      }
      for (final d in ShellDomain.values) {
        expect(
          find.descendant(
            of: find.byKey(QuickAddCard.chipKey(d)),
            matching: find.text(d.singular),
          ),
          findsOneWidget,
        );
      }

      await tester.tap(find.byKey(QuickAddCard.chipKey(ShellDomain.abilities)));
      await tester.pumpAndSettle();
      expect(find.byType(CreateAbilityDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(CreateAbilityDialog), findsNothing);
      expect(harness.location, '/');
      expect(abilities.calls, isEmpty);
    },
    variant: linux,
  );

  testWidgets('a write anywhere re-reads the deltas and the history', (
    tester,
  ) async {
    final harness = PageHarness();
    await harness.pump(tester, const DashboardPage());
    harness.saveHistory.rows = [
      const SaveHistoryEntry(
        id: 3,
        savedAt: '2026-11-01T11:59:30Z',
        description: 'Iron Sword - Item changed',
        isAutoSave: false,
      ),
      ...sampleHistory,
    ];
    harness.lifecycle.deltas = const RecordCounts(items: 3);

    harness.container.read(writeEpochProvider.notifier).bump();
    await tester.pumpAndSettle();

    expect(find.text('Iron Sword - Item changed'), findsOneWidget);
    expect(find.text('last 3 saves'), findsOneWidget);
    expect(find.text('Last saved just now'), findsOneWidget);
    expect(_inTile(ShellDomain.items, '+3 this wk'), findsOneWidget);
    expect(_inTile(ShellDomain.classes, 'stable'), findsOneWidget);
  }, variant: linux);

  testWidgets('nothing renders with no project open', (tester) async {
    final harness = PageHarness(metadata: null);
    await harness.pump(tester, const DashboardPage());
    expect(find.byKey(DashboardPage.heroKey), findsNothing);
    expect(find.byType(CountTile), findsNothing);
  }, variant: linux);

  testWidgets('the status tag in each state', (tester) async {
    for (final (status, label) in [
      (const AllSaved(), 'saved'),
      (const Saving(), 'saving…'),
      (const Unsaved(1), 'unsaved'),
      (const SaveError('disk full'), 'error'),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: anvilTheme(AnvilThemeSpec.dark),
          home: Scaffold(body: Center(child: StatusTag(status))),
        ),
      );
      expect(find.text(label), findsOneWidget);
      expect(
        find.byType(CircularProgressIndicator),
        status is Saving ? findsOneWidget : findsNothing,
      );
      if (status is Saving) {
        expect(
          tester.getSize(find.byType(CircularProgressIndicator)),
          const Size.square(StatusTag.ringSize),
        );
      }
    }
  });
}
