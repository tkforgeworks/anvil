import 'dart:async';

import 'package:anvil/app/validation/last_checked.dart';
import 'package:anvil/app/validation/validation_page.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../dashboard/dashboard_fakes.dart';

const _e = ValidationSeverity.error;
const _w = ValidationSeverity.warning;

List<ValidationIssue> _sample() => [
  issue(
    ValidationDomain.items,
    'item-axe',
    'Bronze Axe',
    _w,
    'References soft-deleted rarity',
    field: 'rarityId',
  ),
  issue(
    ValidationDomain.classes,
    'class-warrior',
    'Warrior',
    _w,
    "Formula for 'Max HP' failed at level 1: Unknown variable 'constitution'",
    field: 'derivedStat:Max HP',
  ),
  issue(
    ValidationDomain.items,
    'item-sword',
    'Iron Sword',
    _e,
    'This field is required.',
    field: 'custom:damage',
  ),
  issue(
    ValidationDomain.derivedStats,
    'ds-hp',
    'Max HP',
    _e,
    'Formula syntax error: Unexpected token',
    field: 'formula',
  ),
];

Finder _inRow(ValidationDomain domain, int index, String text) =>
    find.descendant(
      of: find.byKey(ValidationPage.rowKey(domain, index)),
      matching: find.text(text),
    );

void main() {
  testWidgets(
    'issues are grouped by domain in 0.1.6 order with errors first, with '
    'the count chips and the Last checked line',
    (tester) async {
      final harness = PageHarness(issues: _sample());
      await harness.pump(tester, const ValidationPage());

      expect(find.text('Validation'), findsOneWidget);
      expect(
        find.text('Last checked: ${formatLastChecked(testNow)}'),
        findsOneWidget,
      );
      expect(find.text('Re-run'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(ValidationPage.errorChipKey),
          matching: find.text('2 errors'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(ValidationPage.warningChipKey),
          matching: find.text('2 warnings'),
        ),
        findsOneWidget,
      );

      final headings = [
        for (final d in [
          ValidationDomain.classes,
          ValidationDomain.items,
          ValidationDomain.derivedStats,
        ])
          tester.getTopLeft(find.byKey(ValidationPage.groupKey(d))).dy,
      ];
      expect(headings, orderedEquals([...headings]..sort()));
      expect(find.text('Classes'), findsOneWidget);
      expect(find.text('Items'), findsOneWidget);
      expect(find.text('Derived Stats'), findsOneWidget);
      expect(find.text('Abilities'), findsNothing);
      expect(find.text('Record'), findsNWidgets(3));
      expect(find.text('Field'), findsNWidgets(3));
      expect(find.text('Message'), findsNWidgets(3));

      // The error is listed before the warning that came first.
      expect(_inRow(ValidationDomain.items, 0, 'Iron Sword'), findsOneWidget);
      expect(
        _inRow(ValidationDomain.items, 0, 'custom:damage'),
        findsOneWidget,
      );
      expect(
        _inRow(ValidationDomain.items, 0, 'This field is required.'),
        findsOneWidget,
      );
      expect(_inRow(ValidationDomain.items, 1, 'Bronze Axe'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(ValidationPage.rowKey(ValidationDomain.items, 0)),
          matching: find.byIcon(Icons.error),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(ValidationPage.rowKey(ValidationDomain.items, 1)),
          matching: find.byIcon(Icons.warning),
        ),
        findsOneWidget,
      );
    },
    variant: linux,
  );

  testWidgets(
    'a row click opens the record editor at /items/<id> in full page mode',
    (tester) async {
      final harness = PageHarness(issues: _sample());
      await harness.pump(tester, const ValidationPage());

      await tester.tap(
        find.byKey(ValidationPage.rowKey(ValidationDomain.items, 1)),
      );
      await tester.pumpAndSettle();

      expect(harness.location, '/items/item-axe');
      expect(find.text('page /items/item-axe'), findsOneWidget);
    },
    variant: linux,
  );

  testWidgets(
    'a derived stat row opens nothing without a session and does not throw',
    (tester) async {
      final harness = PageHarness(issues: _sample());
      await harness.pump(tester, const ValidationPage());

      await tester.tap(
        find.byKey(ValidationPage.rowKey(ValidationDomain.derivedStats, 0)),
      );
      await tester.pumpAndSettle();

      expect(harness.location, '/');
      expect(tester.takeException(), isNull);
    },
    variant: linux,
  );

  testWidgets(
    'Re-run calls refresh(), shows Running... and keeps the previous list '
    'until the run completes',
    (tester) async {
      final harness = PageHarness(issues: _sample());
      await harness.pump(tester, const ValidationPage());
      expect(harness.script.runs, 1);

      final gate = Completer<void>();
      harness.script
        ..gate = gate
        ..issues = [_sample().first];
      await tester.tap(find.byKey(ValidationPage.rerunKey));
      await tester.pump();

      expect(harness.script.refreshes, 1);
      expect(harness.script.runs, 2);
      expect(find.text('Running...'), findsOneWidget);
      final button = tester.widget<OutlinedButton>(
        find.byKey(ValidationPage.rerunKey),
      );
      expect(button.onPressed, isNull);
      // The previous list stays on screen while the run is in flight.
      expect(find.text('Iron Sword'), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.text('Re-run'), findsOneWidget);
      expect(find.text('Iron Sword'), findsNothing);
      expect(find.text('Bronze Axe'), findsOneWidget);
      expect(find.byKey(ValidationPage.errorChipKey), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(ValidationPage.warningChipKey),
          matching: find.text('1 warning'),
        ),
        findsOneWidget,
      );
    },
    variant: linux,
  );

  testWidgets('no issues shows the empty state', (tester) async {
    final harness = PageHarness();
    await harness.pump(tester, const ValidationPage());

    expect(find.byKey(ValidationPage.emptyKey), findsOneWidget);
    expect(find.text('No issues found'), findsOneWidget);
    expect(find.text('All records passed validation checks.'), findsOneWidget);
    expect(find.byKey(ValidationPage.errorChipKey), findsNothing);
    expect(find.byKey(ValidationPage.warningChipKey), findsNothing);
  }, variant: linux);

  testWidgets('before the first run completes: a spinner, no Last checked', (
    tester,
  ) async {
    final harness = PageHarness();
    harness.script.gate = Completer<void>();
    await harness.pump(tester, const ValidationPage(), settle: false);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Running...'), findsOneWidget);
    expect(find.textContaining('Last checked'), findsNothing);

    harness.script.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('No issues found'), findsOneWidget);
    expect(find.textContaining('Last checked: '), findsOneWidget);
  }, variant: linux);
}
