import 'package:anvil/app/editor/widgets/draft_picker.dart';
import 'package:anvil/app/theme/anvil_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge_ui/forge_ui.dart';

const _options = <PickerOption<String>>[
  (value: 'a', label: 'Alpha'),
  (value: 'b', label: 'Beta'),
];

Future<void> _pump(WidgetTester tester, DraftPicker<String> picker) =>
    tester.pumpWidget(
      MaterialApp(
        theme: anvilTheme(AnvilThemeSpec.dark),
        home: Scaffold(
          body: Center(child: SizedBox(width: 300, child: picker)),
        ),
      ),
    );

void main() {
  testWidgets('shows a known value by its label', (tester) async {
    await _pump(
      tester,
      DraftPicker<String>(
        label: 'Kind',
        value: 'b',
        options: _options,
        onChanged: (_) {},
      ),
    );
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);
  });

  testWidgets('shows an unknown value as an extra option', (tester) async {
    await _pump(
      tester,
      DraftPicker<String>(
        label: 'Kind',
        value: 'gone',
        options: _options,
        onChanged: (_) {},
      ),
    );
    expect(find.text('gone'), findsOneWidget);
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('gone'), findsWidgets);
  });

  testWidgets('marks a required picker and reports a choice', (tester) async {
    String? chosen;
    await _pump(
      tester,
      DraftPicker<String>(
        label: 'Kind',
        isRequired: true,
        value: 'a',
        options: _options,
        onChanged: (v) => chosen = v,
      ),
    );
    expect(find.text('Kind *'), findsOneWidget);
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beta').last);
    await tester.pumpAndSettle();
    expect(chosen, 'b');
  });

  testWidgets('is disabled when onChanged is null', (tester) async {
    await _pump(
      tester,
      const DraftPicker<String>(
        label: 'Kind',
        value: 'a',
        options: _options,
        onChanged: null,
      ),
    );
    final dropdown = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );
    expect(dropdown.onChanged, isNull);
  });

  testWidgets('shows the error instead of the helper', (tester) async {
    await _pump(
      tester,
      DraftPicker<String>(
        label: 'Kind',
        value: 'a',
        options: _options,
        onChanged: (_) {},
        errorText: 'Pick one.',
        helperText: 'Hint',
      ),
    );
    expect(find.text('Pick one.'), findsOneWidget);
    expect(find.text('Hint'), findsNothing);
  });

  testWidgets('a warning helper uses the warning colour', (tester) async {
    await _pump(
      tester,
      DraftPicker<String>(
        label: 'Kind',
        value: 'a',
        options: _options,
        onChanged: (_) {},
        helperText: 'Careful',
        helperIsWarning: true,
      ),
    );
    final text = tester.widget<Text>(find.text('Careful'));
    final context = tester.element(find.text('Careful'));
    expect(text.style?.color, context.forge.warning);
  });
}
