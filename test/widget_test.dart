import 'package:anvil/app/theme/theme_controller.dart';
import 'package:anvil/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AnvilApp renders the theme gallery', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(AnvilApp(controller: ThemeController()));

    expect(find.text('Anvil theme gallery'), findsOneWidget);
  });
}
