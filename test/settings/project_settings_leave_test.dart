// The Project Settings dialog's leave guard and registry entry, and the
// custom field delete confirmation (ANVL-165).
import 'package:anvil/app/editor/dirty_editors.dart';
import 'package:anvil/app/editor/exit_prompt.dart';
import 'package:anvil/app/editor/save_status.dart';
import 'package:anvil/app/settings/project/project_settings_controller.dart';
import 'package:anvil/app/settings/project/project_settings_dialog.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../dialogs/fakes.dart' show copyFixture;
import 'fakes.dart';

final linux = TargetPlatformVariant.only(TargetPlatform.linux);

void main() {
  late FakeMetaRepository meta;
  late FakeCustomFieldRepository fields;
  late ProviderContainer container;
  late EpochCounter epoch;

  /// The page under the dialog, captured so a test can run
  /// `confirmLeaveAll` as the app exit does.
  late BuildContext pageContext;
  late WidgetRef pageRef;

  ProviderContainer makeContainer(MetaRepository repository) =>
      ProviderContainer.test(
        overrides: [
          for (final o in settingsOverrides(meta, fields))
            if (o.origin != metaRepositoryProvider) o,
          metaRepositoryProvider.overrideWithValue(repository),
        ],
        retry: (_, _) => null,
      );

  setUp(() {
    meta = FakeMetaRepository();
    fields = FakeCustomFieldRepository();
    container = makeContainer(meta);
    epoch = EpochCounter(container);
  });

  final dialog = find.byType(ProjectSettingsDialog);
  final prompt = find.text('Unsaved changes');
  Finder key(String k) => find.byKey(ValueKey(k));

  Future<void> open(
    WidgetTester tester, {
    ProjectSettingsTab initialTab = ProjectSettingsTab.general,
  }) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      settingsTestApp(
        container,
        Consumer(
          builder: (context, ref, _) {
            pageContext = context;
            pageRef = ref;
            return TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ProjectSettingsDialog(initialTab: initialTab),
              ),
              child: const Text('Open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> editTitle(WidgetTester tester, String title) async {
    await tester.enterText(key('settings-game-title'), title);
    await tester.pump();
  }

  Future<void> escape(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
  }

  List<DirtyEditor> entries() => container.read(dirtyEditorsProvider).entries;

  testWidgets('a clean dialog closes on Escape, the close button and Cancel '
      'with no prompt', (tester) async {
    await open(tester);
    await escape(tester);
    expect(prompt, findsNothing);
    expect(dialog, findsNothing);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(prompt, findsNothing);
    expect(dialog, findsNothing);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(key('project-settings-cancel'));
    await tester.pumpAndSettle();
    expect(prompt, findsNothing);
    expect(dialog, findsNothing);
    expect(entries(), isEmpty);
  }, variant: linux);

  testWidgets('dirty: the draft registers as Project Settings (settings), '
      'counts as unsaved, and leaves the registry when clean again', (
    tester,
  ) async {
    await open(tester);
    await editTitle(tester, 'Changed');
    final entry = entries().single;
    expect(entry.domain, isNull);
    expect(entry.recordId, projectSettingsDirtyId);
    expect(entry.displayName, 'Project Settings');
    expect(entry.kind, 'settings');
    expect(container.read(saveStatusProvider), const Unsaved(1));

    await editTitle(tester, '');
    expect(entries().single.blockers.single.message, 'Game title is required.');

    await editTitle(tester, 'Forge & Fable');
    expect(entries(), isEmpty);
    expect(container.read(saveStatusProvider), const AllSaved());
  }, variant: linux);

  testWidgets('dirty: Escape, the close button and the barrier prompt; '
      'Cancel in the prompt keeps the dialog and the edit', (tester) async {
    await open(tester);
    await editTitle(tester, 'Changed');

    await escape(tester);
    expect(prompt, findsOneWidget);
    expect(find.text('Project Settings (settings)'), findsOneWidget);
    await tester.tap(key('leave-editor-cancel'));
    await tester.pumpAndSettle();
    expect(dialog, findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(prompt, findsOneWidget);
    await tester.tap(key('leave-editor-cancel'));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(prompt, findsOneWidget);
    await tester.tap(key('leave-editor-cancel'));
    await tester.pumpAndSettle();

    expect(dialog, findsOneWidget);
    expect(
      find.descendant(
        of: key('settings-game-title'),
        matching: find.text('Changed'),
      ),
      findsOneWidget,
    );
    expect(meta.saved, isEmpty);
    expect(entries(), hasLength(1));
  }, variant: linux);

  testWidgets('dirty and blocked: the prompt disables Save and shows the '
      'blocker', (tester) async {
    await open(tester);
    await editTitle(tester, '');
    await escape(tester);
    expect(
      tester.widget<ButtonStyleButton>(key('leave-editor-save')).enabled,
      isFalse,
    );
    expect(
      tester.widget<Text>(key('leave-editor-problem')).data,
      'Game title is required.',
    );
    await tester.tap(key('leave-editor-discard'));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    expect(meta.saved, isEmpty);
    expect(entries(), isEmpty);
  }, variant: linux);

  testWidgets('dirty: Save in the prompt commits once and closes', (
    tester,
  ) async {
    await open(tester);
    await editTitle(tester, 'Changed');
    await escape(tester);
    await tester.tap(key('leave-editor-save'));
    await tester.pumpAndSettle();
    expect(prompt, findsNothing);
    expect(dialog, findsNothing);
    expect(meta.saved.single.gameTitle, 'Changed');
    expect(epoch.bumps, 1);
    expect(entries(), isEmpty);
  }, variant: linux);

  testWidgets('a failed save from the prompt keeps the prompt open with the '
      'error', (tester) async {
    meta.saveError = SaveFailed('disk full', StateError('disk'));
    await open(tester);
    await editTitle(tester, 'Changed');
    await escape(tester);
    await tester.tap(key('leave-editor-save'));
    await tester.pumpAndSettle();
    expect(prompt, findsOneWidget);
    expect(tester.widget<Text>(key('leave-editor-problem')).data, 'disk full');
    expect(epoch.bumps, 0);
  }, variant: linux);

  testWidgets('the app exit prompt lists the dirty settings, and Discard all '
      'drops the edit', (tester) async {
    await open(tester);
    await editTitle(tester, 'Changed');

    final leave = confirmLeaveAll(pageContext, pageRef);
    await tester.pumpAndSettle();
    expect(find.text('Project Settings (settings)'), findsOneWidget);
    expect(find.text('There are unsaved changes:'), findsOneWidget);
    await tester.tap(key('leave-all-discard'));
    await tester.pumpAndSettle();
    expect(await leave, isTrue);
    expect(entries(), isEmpty);
    expect(
      find.descendant(
        of: key('settings-game-title'),
        matching: find.text('Forge & Fable'),
      ),
      findsOneWidget,
    );
    expect(meta.saved, isEmpty);
  }, variant: linux);

  group('custom field delete', () {
    Future<void> tapDelete(WidgetTester tester) async {
      await tester.tap(
        find.descendant(
          of: key('field-row-field-damage'),
          matching: find.byTooltip('Delete'),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('asks first; Cancel deletes nothing', (tester) async {
      await open(tester, initialTab: ProjectSettingsTab.customFields);
      await tapDelete(tester);
      expect(find.text('Delete field "damage"?'), findsOneWidget);
      expect(find.text('This cannot be undone.'), findsOneWidget);
      await tester.tap(key('delete-field-cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Delete field "damage"?'), findsNothing);
      expect(fields.calls, isNot(contains('deleteDefinition field-damage')));
      expect(key('field-row-field-damage'), findsOneWidget);
      expect(epoch.bumps, 0);
      // The confirm dialog's Escape did not close Project Settings.
      expect(dialog, findsOneWidget);
    }, variant: linux);

    testWidgets('Delete in the confirm deletes the field', (tester) async {
      await open(tester, initialTab: ProjectSettingsTab.customFields);
      await tapDelete(tester);
      await tester.tap(key('delete-field-confirm'));
      await tester.pumpAndSettle();
      expect(fields.calls, contains('deleteDefinition field-damage'));
      expect(key('field-row-field-damage'), findsNothing);
    }, variant: linux);
  });

  group('over SqliteMetaRepository on a fixture copy', () {
    late ProjectDatabase db;

    setUp(() {
      db = ProjectDatabase.open(copyFixture());
      addTearDown(db.close);
      container = makeContainer(SqliteMetaRepository(db));
      epoch = EpochCounter(container);
    });

    testWidgets('dirty, Escape, Discard writes nothing', (tester) async {
      final before = readRecentSaves(db).length;
      await open(tester);
      await editTitle(tester, 'Forge & Fable II');
      await escape(tester);
      await tester.tap(key('leave-editor-discard'));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
      expect(readRecentSaves(db).length, before);
      final stored = await SqliteMetaRepository(db).loadProjectSettings();
      expect(stored.gameTitle, isNot('Forge & Fable II'));
      expect(epoch.bumps, 0);
    }, variant: linux);

    testWidgets('dirty, Escape, Save writes exactly one history row', (
      tester,
    ) async {
      final before = readRecentSaves(db);
      await open(tester);
      await editTitle(tester, 'Forge & Fable II');
      await escape(tester);
      await tester.tap(key('leave-editor-save'));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
      final after = readRecentSaves(db);
      expect(after.length, before.length + 1);
      expect(after.first.description, 'Project settings changed');
      final stored = await SqliteMetaRepository(db).loadProjectSettings();
      expect(stored.gameTitle, 'Forge & Fable II');
      expect(epoch.bumps, 1);
    }, variant: linux);
  });
}
