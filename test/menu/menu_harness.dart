import 'package:anvil/app/editor/editor_shortcuts.dart';
import 'package:anvil/app/menu/external_links.dart';
import 'package:anvil/app/menu/menu_commands.dart';
import 'package:anvil/app/providers.dart';
import 'package:anvil/app/shell/app_router.dart';
import 'package:anvil/app/shell/app_shell.dart';
import 'package:anvil/main.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../app_bootstrap_test.dart' show AppHarness;
import '../dialogs/fakes.dart';

final linux = TargetPlatformVariant.only(TargetPlatform.linux);

/// What the fake editor's shortcut callbacks received.
final editorCalls = <String>[];

/// A record editor stand-in: the real `RecordEditorShortcuts` with
/// recording callbacks around an autofocus `FocusScope`, as
/// `RecordEditorScope` composes them, with one text field.
class FakeEditor extends StatelessWidget {
  const FakeEditor({super.key});

  @override
  Widget build(BuildContext context) => RecordEditorShortcuts(
    onSave: () => editorCalls.add('save'),
    onUndo: () => editorCalls.add('undo'),
    onRedo: () => editorCalls.add('redo'),
    child: FocusScope(
      debugLabel: 'editor',
      autofocus: true,
      child: const Column(
        children: [
          Text('Fake editor'),
          TextField(key: Key('editor-field')),
        ],
      ),
    ),
  );
}

/// A shell page with a text field and no editor.
class PlainPage extends StatelessWidget {
  const PlainPage({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    children: [
      Text('Plain page'),
      TextField(key: Key('plain-field')),
    ],
  );
}

/// The locations the test router knows besides `/` and `/plain`.
const otherLocations = [
  '/classes',
  '/abilities',
  '/items',
  '/recipes',
  '/npcs',
  '/loot-tables',
  '/validation',
  '/recycle-bin',
  '/export',
];

/// The app as `main()` mounts it (`AnvilApp`, so the global shortcuts and
/// the zoom are in place), with the 0.1.6 fixture open and a router whose
/// shell shows the [FakeEditor] at `/` and a [PlainPage] at `/plain`.
class MenuHarness {
  MenuHarness._(this.app, this.service, this.container);

  static Future<MenuHarness> pump(
    WidgetTester tester, {
    String? settingsJson,
    String initialLocation = '/',
    List<Override> overrides = const [],
  }) async {
    editorCalls.clear();
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = AppHarness.create(settingsJson: settingsJson);
    final service = FakeProjectService(supportDirectory: app.directory.path);
    final path = copyFixture();
    final opened = await tester.runAsync(() => service.open(path));
    final session = (opened! as ProjectOpened).session;
    final harness = MenuHarness._(app, service, null);
    harness._sessions.add(session);
    addTearDown(harness._closeSessions);

    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: welcomeLocation,
          builder: (_, _) => const Text('Welcome'),
        ),
        ShellRoute(
          builder: (_, _, child) => AppShell(child: child),
          routes: [
            GoRoute(path: '/', builder: (_, _) => const FakeEditor()),
            GoRoute(path: '/plain', builder: (_, _) => const PlainPage()),
            for (final location in otherLocations)
              GoRoute(path: location, builder: (_, _) => Text('At $location')),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...app.overrides,
          projectServiceProvider.overrideWithValue(service),
          routerProvider.overrideWithValue(router),
          urlLauncherProvider.overrideWithValue(harness._launch),
          exitApplicationProvider.overrideWithValue(() async {
            harness.exitRequests++;
          }),
          ...overrides,
        ],
        retry: (_, _) => null,
        child: const AnvilApp(),
      ),
    );
    harness.container = appContainer(tester);
    // Every session the app sees (a Save As copy, say) is closed at tear-down.
    harness.container!.listen(projectSessionProvider, (_, next) {
      if (next != null) harness._sessions.add(next);
    });
    harness.container!.read(projectSessionProvider.notifier).set(session);
    await tester.pumpAndSettle();
    return harness;
  }

  final AppHarness app;
  final FakeProjectService service;
  ProviderContainer? container;
  final _sessions = <ProjectSession>[];

  /// The URLs the fake launcher received.
  final launched = <Uri>[];
  var exitRequests = 0;

  Future<bool> _launch(Uri uri) async {
    launched.add(uri);
    return true;
  }

  GoRouter get router => container!.read(routerProvider);

  String get location =>
      router.routerDelegate.currentConfiguration.uri.toString();

  /// Closes [session] at tear-down if still open.
  void track(ProjectSession session) => _sessions.add(session);

  Future<void> _closeSessions() async {
    for (final session in _sessions) {
      if (session.isOpen) await service.close(session);
    }
  }
}

/// Opens the hamburger menu.
Future<void> openMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Menu'));
  await tester.pumpAndSettle();
}

/// The first row of each section, which shows when the section is open.
const _firstRows = {
  'File': 'New Project…',
  'View': 'Toggle Sidebar',
  'Project': 'Project Settings',
  'Data': 'Dashboard',
  'Help': 'Documentation',
};

/// Opens the hamburger menu and the section [label].
Future<void> openSection(WidgetTester tester, String label) async {
  await openMenu(tester);
  await showSection(tester, label);
}

/// Opens section [label] of the open menu, unless it is open already (the
/// menu opens with focus on File, which opens File).
Future<void> showSection(WidgetTester tester, String label) async {
  final firstRow = find.descendant(
    of: find.byType(MenuItemButton),
    matching: find.text(_firstRows[label]!),
  );
  if (firstRow.hitTestable().evaluate().isNotEmpty) return;
  await tester.tap(find.byKey(ValueKey('menu-section-$label')));
  await tester.pumpAndSettle();
}

/// The row for [command] in the open menu.
Finder row(MenuCommand command) => find.byKey(ValueKey('menu-${command.id}'));

MenuItemButton rowWidget(WidgetTester tester, MenuCommand command) =>
    tester.widget<MenuItemButton>(row(command));

/// Presses [key] with Control (and Shift) held; returns whether the key
/// press was handled.
Future<bool> ctrl(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool shift = false,
}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  final handled = await tester.sendKeyDownEvent(key);
  await tester.sendKeyUpEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
  return handled;
}
