import 'package:anvil/app/editor/widgets/number_draft_field.dart';
import 'package:anvil/app/theme/anvil_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(
  theme: anvilTheme(AnvilThemeSpec.dark),
  home: Scaffold(
    body: Center(child: SizedBox(width: 300, child: child)),
  ),
);

void main() {
  group('NumberDraftField', () {
    testWidgets('invalid text keeps the draft and shows the message', (
      tester,
    ) async {
      final seen = <double?>[];
      await tester.pumpWidget(
        _app(NumberDraftField(value: 5, onChanged: seen.add)),
      );
      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump();
      expect(find.text(NumberDraftField.invalidMessage), findsOneWidget);
      expect(seen, isEmpty);
    });

    testWidgets('empty reads as emptyValue', (tester) async {
      final seen = <double?>[];
      await tester.pumpWidget(
        _app(NumberDraftField(value: 5, emptyValue: 0, onChanged: seen.add)),
      );
      await tester.enterText(find.byType(TextField), '');
      expect(seen, [0]);
    });

    testWidgets('empty reads as null without emptyValue', (tester) async {
      final seen = <double?>[];
      await tester.pumpWidget(
        _app(NumberDraftField(value: 5, onChanged: seen.add)),
      );
      await tester.enterText(find.byType(TextField), '');
      expect(seen, [null]);
    });

    testWidgets('zeroIsEmpty reads zero as null', (tester) async {
      final seen = <double?>[];
      await tester.pumpWidget(
        _app(
          NumberDraftField(value: 5, zeroIsEmpty: true, onChanged: seen.add),
        ),
      );
      await tester.enterText(find.byType(TextField), '0');
      expect(seen, [null]);
    });

    testWidgets('a draft change rewrites the text only when the meaning '
        'differs', (tester) async {
      var value = 1.0;
      late StateSetter rebuild;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return NumberDraftField(
                value: value,
                onChanged: (v) => value = v ?? 0,
              );
            },
          ),
        ),
      );
      TextField field() => tester.widget<TextField>(find.byType(TextField));

      await tester.enterText(find.byType(TextField), '2.50');
      rebuild(() {});
      await tester.pump();
      expect(value, 2.5);
      expect(field().controller!.text, '2.50');

      rebuild(() => value = 7);
      await tester.pump();
      expect(field().controller!.text, '7');
    });
  });

  group('IntDraftField', () {
    testWidgets('accepts digits only', (tester) async {
      final seen = <int>[];
      await tester.pumpWidget(
        _app(IntDraftField(value: 1, onChanged: seen.add)),
      );
      await tester.enterText(find.byType(TextField), '1a2-');
      expect(seen.last, 12);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '12',
      );
    });

    testWidgets('empty reads as 0', (tester) async {
      final seen = <int>[];
      await tester.pumpWidget(
        _app(IntDraftField(value: 4, onChanged: seen.add)),
      );
      await tester.enterText(find.byType(TextField), '');
      expect(seen, [0]);
      expect(IntDraftField.parse(''), 0);
    });
  });
}
