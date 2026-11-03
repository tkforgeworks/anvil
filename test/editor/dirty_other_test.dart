// `DirtyEditor.other` entries (the Project Settings and template dialogs,
// ANVL-165) in the registry, the save status and both prompts.
import 'package:anvil/app/editor/dirty_editors.dart';
import 'package:anvil/app/editor/editor_state.dart';
import 'package:anvil/app/editor/exit_prompt.dart';
import 'package:anvil/app/editor/save_status.dart';
import 'package:anvil/app/theme/anvil_theme.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final linux = TargetPlatformVariant.only(TargetPlatform.linux);

void main() {
  late ProviderContainer container;
  late List<String> calls;

  setUp(() {
    container = ProviderContainer.test();
    calls = [];
  });

  DirtyEditorsNotifier registry() =>
      container.read(dirtyEditorsProvider.notifier);
  List<DirtyEditor> entries() => container.read(dirtyEditorsProvider).entries;

  DirtyEditor record() => DirtyEditor(
    domain: SaveDomain.items,
    recordId: 'item-1',
    displayName: 'Iron Sword',
    save: () async {
      calls.add('save item');
      return SaveOutcome.saved;
    },
    discard: () => calls.add('discard item'),
  );

  DirtyEditor other(
    String id,
    String name,
    String kind, {
    List<SaveBlocker> blockers = const [],
  }) => DirtyEditor.other(
    recordId: id,
    displayName: name,
    kindLabel: kind,
    save: () async {
      calls.add('save $id');
      return SaveOutcome.saved;
    },
    discard: () => calls.add('discard $id'),
    blockers: blockers,
  );

  test('an other entry is keyed by its id alone and counts as unsaved', () {
    registry()
      ..put(record())
      ..put(other('item-1', 'Project Settings', 'settings'));
    expect(entries(), hasLength(2));
    expect(entries().last.domain, isNull);
    expect(entries().last.kind, 'settings');
    expect(entries().first.kind, 'item');
    expect(container.read(saveStatusProvider), const Unsaved(2));
    expect(
      findDirtyEditor(container.read(dirtyEditorsProvider), null, 'item-1'),
      entries().last,
    );

    registry().remove(null, 'item-1');
    expect(entries().single.domain, SaveDomain.items);
  });

  group('prompts', () {
    late BuildContext context;
    late WidgetRef ref;

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: anvilTheme(AnvilThemeSpec.dark),
            home: Scaffold(
              body: Consumer(
                builder: (c, r, _) {
                  context = c;
                  ref = r;
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('confirmLeaveAll lists record and other entries with their '
        'kinds, and Save all saves each', (tester) async {
      await pump(tester);
      registry()
        ..put(record())
        ..put(other('project-settings', 'Project Settings', 'settings'))
        ..put(other('template:tpl-1', 'Recipe Book', 'template'));

      final leave = confirmLeaveAll(context, ref);
      await tester.pumpAndSettle();
      expect(find.text('There are unsaved changes:'), findsOneWidget);
      expect(find.text('Iron Sword (item)'), findsOneWidget);
      expect(find.text('Project Settings (settings)'), findsOneWidget);
      expect(find.text('Recipe Book (template)'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('leave-all-settings-project-settings')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('leave-all-save')));
      await tester.pumpAndSettle();
      expect(await leave, isTrue);
      expect(calls, [
        'save item',
        'save project-settings',
        'save template:tpl-1',
      ]);
    }, variant: linux);

    testWidgets('confirmLeaveEditor over an other entry: blocked Save is '
        'disabled, Discard discards', (tester) async {
      await pump(tester);
      final entry = other(
        'project-settings',
        'Project Settings',
        'settings',
        blockers: const [SaveBlocker('', 'Game title is required.')],
      );
      registry().put(entry);

      final leave = confirmLeaveEditor(context, entry);
      await tester.pumpAndSettle();
      expect(find.text('There are unsaved changes:'), findsOneWidget);
      expect(find.text('Project Settings (settings)'), findsOneWidget);
      expect(
        tester
            .widget<ButtonStyleButton>(
              find.byKey(const ValueKey('leave-editor-save')),
            )
            .enabled,
        isFalse,
      );
      await tester.tap(find.byKey(const ValueKey('leave-editor-discard')));
      await tester.pumpAndSettle();
      expect(await leave, isTrue);
      expect(calls, ['discard project-settings']);
    }, variant: linux);
  });
}
