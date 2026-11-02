import 'package:anvil/app/lists/undo_snackbar.dart';
import 'package:anvil/app/theme/anvil_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final linux = TargetPlatformVariant.only(TargetPlatform.linux);

/// A scaffold whose button calls [onPressed] with its context.
Future<void> pumpHost(
  WidgetTester tester,
  void Function(BuildContext context) onPressed,
) => tester.pumpWidget(
  MaterialApp(
    theme: anvilTheme(AnvilThemeSpec.dark),
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => onPressed(context),
          child: const Text('act'),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('shows the message with Undo, which runs the inverse and '
      'closes the snackbar', (tester) async {
    var undone = 0;
    await pumpHost(
      tester,
      (context) => showUndoSnackBar(
        context,
        message: 'Deleted "Fireball"',
        undo: () async => undone++,
      ),
    );
    await tester.tap(find.text('act'));
    await tester.pumpAndSettle();

    expect(find.byKey(undoSnackBarKey), findsOneWidget);
    expect(find.text('Deleted "Fireball"'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(undoSnackBarActionKey),
        matching: find.text('Undo'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(undoSnackBarActionKey));
    await tester.pumpAndSettle();
    expect(undone, 1);
    expect(find.byKey(undoSnackBarKey), findsNothing);
  }, variant: linux);

  testWidgets('closes by itself after five seconds although it has an '
      'action', (tester) async {
    expect(undoSnackBarDuration, const Duration(seconds: 5));
    var undone = 0;
    await pumpHost(
      tester,
      (context) => showUndoSnackBar(
        context,
        message: 'Restored "Fireball"',
        undo: () async => undone++,
      ),
    );
    await tester.tap(find.text('act'));
    await tester.pumpAndSettle();
    expect(find.byKey(undoSnackBarKey), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    expect(find.byKey(undoSnackBarKey), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byKey(undoSnackBarKey), findsNothing);
    expect(undone, 0);
  }, variant: linux);

  testWidgets('only the latest action is undoable', (tester) async {
    final undone = <String>[];
    var n = 0;
    await pumpHost(tester, (context) {
      final name = 'action ${++n}';
      showUndoSnackBar(
        context,
        message: name,
        undo: () async => undone.add(name),
      );
    });
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('act'));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.byKey(undoSnackBarKey), findsOneWidget);
    expect(find.text('action 3'), findsOneWidget);
    await tester.tap(find.byKey(undoSnackBarActionKey));
    await tester.pumpAndSettle();
    expect(undone, ['action 3']);
    // Nothing earlier comes back from the queue.
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.byKey(undoSnackBarKey), findsNothing);
  }, variant: linux);

  testWidgets('does nothing without a ScaffoldMessenger', (tester) async {
    Object? result = 'unset';
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) {
            result = showUndoSnackBar(
              context,
              message: 'Deleted "Fireball"',
              undo: () async {},
            );
            return const SizedBox();
          },
        ),
      ),
    );
    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });
}
