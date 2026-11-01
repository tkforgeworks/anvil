import 'package:anvil_core/anvil_core.dart';
import 'package:test/test.dart';

AbilityDraft _valid() => AbilityDraft(
  displayName: 'Slash',
  exportKey: 'slash',
  statModifiers: const {'strength': 2, 'odd': double.nan},
);

void main() {
  test('a valid draft has no blockers', () {
    expect(abilitySaveBlockers(_valid()), isEmpty);
  });

  test('an empty or blank display name blocks', () {
    for (final name in ['', '  ']) {
      expect(abilitySaveBlockers(_valid().copyWith(displayName: name)), [
        const SaveBlocker('displayName', 'Display name is required.'),
      ]);
    }
  });

  test('an empty or blank export key blocks', () {
    for (final key in ['', '\n']) {
      expect(abilitySaveBlockers(_valid().copyWith(exportKey: key)), [
        const SaveBlocker('exportKey', 'Export key is required.'),
      ]);
    }
  });

  test('both identity rules are reported together', () {
    expect(
      abilitySaveBlockers(_valid().copyWith(displayName: '', exportKey: '')),
      [
        const SaveBlocker('displayName', 'Display name is required.'),
        const SaveBlocker('exportKey', 'Export key is required.'),
      ],
    );
  });
}
