import 'package:anvil/app/welcome/recent_projects_list.dart';
import 'package:anvil/app/widgets/formatting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatFileSize (FileSizeDisplay.tsx)', () {
    test('bytes below 1 KiB', () {
      expect(formatFileSize(0), '0 B');
      expect(formatFileSize(1), '1 B');
      expect(formatFileSize(1023), '1023 B');
    });

    test('KB, MB and GB with one decimal, rounded as toFixed(1)', () {
      expect(formatFileSize(1024), '1.0 KB');
      expect(formatFileSize(1280), '1.3 KB'); // 1.25, a tie: rounds up
      expect(formatFileSize(1075), '1.0 KB'); // 1.0498…
      expect(formatFileSize(1048064), '1023.5 KB');
      expect(formatFileSize(1024 * 1024), '1.0 MB');
      expect(formatFileSize(2621440), '2.5 MB');
      expect(formatFileSize(1024 * 1024 * 1024), '1.0 GB');
      expect(formatFileSize(3 * 1024 * 1024 * 1024 ~/ 2), '1.5 GB');
    });
  });

  group('formatRelativeTimestamp (RelativeTimestamp.tsx)', () {
    final now = DateTime.utc(2026, 11, 1, 12);
    String ago(Duration d) =>
        formatRelativeTimestamp(now.subtract(d), now: now);

    test('under a minute and the future are just now', () {
      expect(ago(Duration.zero), 'just now');
      expect(ago(const Duration(seconds: 59)), 'just now');
      expect(
        formatRelativeTimestamp(now.add(const Duration(hours: 1)), now: now),
        'just now',
      );
    });

    test('minutes, hours and days', () {
      expect(ago(const Duration(seconds: 60)), '1 minute ago');
      expect(ago(const Duration(minutes: 2)), '2 minutes ago');
      expect(ago(const Duration(minutes: 59, seconds: 59)), '59 minutes ago');
      expect(ago(const Duration(hours: 1)), '1 hour ago');
      expect(ago(const Duration(hours: 23, minutes: 59)), '23 hours ago');
      expect(ago(const Duration(hours: 24)), 'yesterday');
      expect(ago(const Duration(hours: 47)), 'yesterday');
      expect(ago(const Duration(days: 2)), '2 days ago');
      expect(ago(const Duration(days: 6, hours: 23)), '6 days ago');
      expect(ago(const Duration(days: 7)), 'last week');
      expect(ago(const Duration(days: 13)), 'last week');
    });

    test('two weeks and older is the local date', () {
      final then = DateTime(2026, 10, 11, 9);
      expect(
        formatRelativeTimestamp(then, now: then.add(const Duration(days: 14))),
        'Oct 11, 2026',
      );
      final older = DateTime(2025, 1, 3, 9);
      expect(formatRelativeTimestamp(older, now: now), 'Jan 3, 2025');
    });
  });

  group('formatRecordSummary (countSummary in WelcomePage.tsx)', () {
    test('non-zero counts in 0.1.6 order', () {
      expect(
        formatRecordSummary(
          items: 6,
          abilities: 3,
          classes: 2,
          npcs: 2,
          recipes: 2,
          lootTables: 1,
        ),
        '6 items · 3 abilities · 2 classes · 2 NPCs · 2 recipes · '
        '1 loot tables',
      );
      expect(
        formatRecordSummary(
          items: 0,
          abilities: 0,
          classes: 1,
          npcs: 0,
          recipes: 0,
          lootTables: 0,
        ),
        '1 classes',
      );
    });

    test('all zero is empty', () {
      expect(
        formatRecordSummary(
          items: 0,
          abilities: 0,
          classes: 0,
          npcs: 0,
          recipes: 0,
          lootTables: 0,
        ),
        '',
      );
    });
  });

  test('initials as getInitials in ProjectInitialsMark.tsx', () {
    expect(ProjectInitialsMark.initialsOf('Spike Fixture'), 'SF');
    expect(ProjectInitialsMark.initialsOf('  forge   and fable '), 'FA');
    expect(ProjectInitialsMark.initialsOf('anvil'), 'A');
    expect(ProjectInitialsMark.initialsOf('   '), '?');
  });
}
