import 'package:anvil/app/editor/widgets/validation_banner.dart';
import 'package:anvil/app/theme/anvil_theme.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ValidationIssue issue(
  ValidationSeverity severity,
  String message, {
  String? field,
}) => ValidationIssue(
  domain: ValidationDomain.items,
  recordId: 'item-1',
  recordDisplayName: 'Iron Sword',
  field: field,
  severity: severity,
  message: message,
);

void main() {
  Future<void> pump(WidgetTester tester, List<ValidationIssue> issues) =>
      tester.pumpWidget(
        MaterialApp(
          theme: anvilTheme(AnvilThemeSpec.dark),
          home: Scaffold(body: ValidationBanner(issues)),
        ),
      );

  final banner = find.byKey(const ValueKey('validation-banner'));

  testWidgets('builds nothing without issues', (tester) async {
    await pump(tester, const []);
    expect(banner, findsNothing);
    expect(find.textContaining('Validation'), findsNothing);
  });

  testWidgets('lists errors before warnings with the 0.1.6 title', (
    tester,
  ) async {
    await pump(tester, [
      issue(
        ValidationSeverity.warning,
        'Rarity is archived',
        field: 'rarityId',
      ),
      issue(ValidationSeverity.error, 'Category is missing'),
      issue(ValidationSeverity.warning, 'Second warning'),
      issue(ValidationSeverity.error, 'Value required', field: 'custom:damage'),
    ]);
    expect(banner, findsOneWidget);
    expect(find.text('Validation: 2 errors, 2 warnings'), findsOneWidget);

    final lines = [
      'Category is missing',
      'custom:damage: Value required',
      'rarityId: Rarity is archived',
      'Second warning',
    ];
    final tops = [
      for (final line in lines) tester.getTopLeft(find.text(line)).dy,
    ];
    expect([...tops]..sort(), tops);
  });

  testWidgets('singular counts, and a warning-only banner', (tester) async {
    await pump(tester, [issue(ValidationSeverity.warning, 'Only one')]);
    expect(find.text('Validation: 1 warning'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber), findsOneWidget);

    await pump(tester, [issue(ValidationSeverity.error, 'Only one')]);
    expect(find.text('Validation: 1 error'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  test('fieldIssueText returns the first issue on a field', () {
    final issues = [
      issue(ValidationSeverity.error, 'First', field: 'rarityId'),
      issue(ValidationSeverity.warning, 'Second', field: 'rarityId'),
      issue(ValidationSeverity.error, 'No field'),
    ];
    expect(fieldIssueText(issues, 'rarityId'), 'First');
    expect(fieldIssue(issues, 'rarityId')!.severity, ValidationSeverity.error);
    expect(fieldIssueText(issues, 'itemCategoryId'), isNull);
  });
}
