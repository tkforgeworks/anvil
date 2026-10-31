import 'package:anvil/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AnvilApp renders its placeholder', (tester) async {
    await tester.pumpWidget(const AnvilApp());

    expect(find.text('Anvil'), findsOneWidget);
  });
}
