import 'dart:async';

import 'package:anvil/app/project/project_lifecycle.dart';
import 'package:anvil/app/providers.dart';
import 'package:anvil/app/shell/app_router.dart';
import 'package:anvil/app/shell/app_shell.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil/main.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_bootstrap_test.dart' show AppHarness;
import '../dialogs/fakes.dart';

final linux = TargetPlatformVariant.only(TargetPlatform.linux);

/// The app as `main()` mounts it, with the real `ProjectService` on a
/// temporary support directory and a copy of the 0.1.6 fixture to open.
/// Every session it sees opened is closed at tear-down.
class ShellHarness {
  ShellHarness._(this.app, this.path, this.container);

  /// Pumps the app at 1400×1000 on the welcome page.
  static Future<ShellHarness> pump(
    WidgetTester tester, {
    String? settingsJson,
    List<ProviderObserver> observers = const [],
  }) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = AppHarness.create(settingsJson: settingsJson);
    final path = copyFixture();
    await tester.pumpWidget(
      ProviderScope(
        overrides: app.overrides,
        observers: observers,
        retry: (_, _) => null,
        child: const AnvilApp(),
      ),
    );
    final harness = ShellHarness._(app, path, appContainer(tester));
    addTearDown(harness._closeSessions);
    return harness;
  }

  final AppHarness app;

  /// The fixture copy [openProject] opens.
  final String path;
  final ProviderContainer container;
  final _sessions = <ProjectSession>[];

  late final service = ProjectService(supportDirectory: app.directory.path);

  /// The router's current location.
  String get location => container
      .read(routerProvider)
      .routerDelegate
      .currentConfiguration
      .uri
      .toString();

  /// Opens [path] through the lifecycle notifier, as the welcome page does,
  /// and waits for the shell with its counts, trash count and first
  /// validation pass.
  Future<void> openProject(WidgetTester tester) async {
    unawaited(container.read(projectLifecycleProvider.notifier).openPath(path));
    await pumpUntil(tester, () => find.byType(AppShell).evaluate().isNotEmpty);
    track(container.read(projectSessionProvider)!);
    await settleShell(tester);
  }

  /// Closes [session] at tear-down if still open.
  void track(ProjectSession session) => _sessions.add(session);

  /// Waits until the sidebar's three async sources hold settled values.
  Future<void> settleShell(WidgetTester tester) => pumpUntil(tester, () {
    final sources = [
      container.read(recordCountsProvider),
      container.read(trashCountProvider),
      container.read(validationIssuesProvider),
    ];
    return sources.every((s) => s.hasValue && !s.isLoading);
  });

  Future<void> _closeSessions() async {
    for (final session in _sessions) {
      if (session.isOpen) await service.close(session);
    }
  }
}

/// Errors plus warnings, the sidebar's validation badge.
int badgeCount(List<ValidationIssue> issues) => issues
    .where(
      (i) =>
          i.severity == ValidationSeverity.error ||
          i.severity == ValidationSeverity.warning,
    )
    .length;

/// The project pass run directly on the file, outside the app.
Future<List<ValidationIssue>> validateFile(
  WidgetTester tester,
  String path,
) async => (await tester.runAsync(
  () => ValidationService(projectPath: path).runProject(),
))!;
