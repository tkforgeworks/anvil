/// In-memory stand-ins for the dashboard and validation page tests: the
/// lifecycle and save history repositories, a scripted project validation
/// pass, and an app with a test router at the 1400×800 minimum with the
/// 220 px sidebar taken.
library;

import 'dart:async';

import 'package:anvil/app/dashboard/dashboard_providers.dart';
import 'package:anvil/app/editor/clock.dart';
import 'package:anvil/app/providers.dart';
import 'package:anvil/app/shell/app_router.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil/app/theme/anvil_theme.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final linux = TargetPlatformVariant.only(TargetPlatform.linux);

/// The fixed wall clock of every test: 2026-11-01 12:00 UTC.
final testNow = DateTime.utc(2026, 11, 1, 12);

const sampleMetadata = ProjectMetadata(
  projectName: 'Spike Fixture',
  gameTitle: 'Forge & Fable',
  filePath: '/projects/Spike Fixture/database/Spike Fixture.anvil',
  projectFolder: ProjectFolderPaths(
    root: '/projects/Spike Fixture',
    database: '/projects/Spike Fixture/database',
    exports: '/projects/Spike Fixture/exports',
    temp: '/projects/Spike Fixture/temp',
    logs: '/projects/Spike Fixture/logs',
  ),
  schemaVersion: 7,
  lastModifiedAt: '2026-10-30T12:00:00.000Z',
  fileSize: 204800,
  recordCounts: RecordCounts(),
);

/// A 0.2.0 row and a 0.1.6 auto-save row with no description.
const sampleHistory = [
  SaveHistoryEntry(
    id: 2,
    savedAt: '2026-11-01T11:00:00Z',
    description: 'Fireball - Ability changed',
    isAutoSave: false,
  ),
  SaveHistoryEntry(
    id: 1,
    savedAt: '2026-10-11T09:00:00Z',
    description: '',
    isAutoSave: true,
  ),
];

/// Answers [weeklyDeltas] only, counting the reads.
class FakeLifecycle implements LifecycleRepository {
  FakeLifecycle(this.deltas);

  RecordCounts deltas;
  var reads = 0;

  @override
  Future<RecordCounts> weeklyDeltas() async {
    reads++;
    return deltas;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeLifecycle: ${invocation.memberName}');
}

/// Answers [recent] from [rows], recording each limit asked for.
class FakeSaveHistory implements SaveHistoryRepository {
  FakeSaveHistory(this.rows);

  List<SaveHistoryEntry> rows;
  final limits = <int>[];

  @override
  Future<List<SaveHistoryEntry>> recent({int limit = saveHistoryLimit}) async {
    limits.add(limit);
    return rows.take(limit).toList();
  }
}

/// What the scripted project pass answers: [issues], after [gate] completes
/// when one is set; [refreshes] counts the Re-run calls.
class IssueScript {
  IssueScript([this.issues = const []]);

  List<ValidationIssue> issues;
  Completer<void>? gate;
  var refreshes = 0;
  var runs = 0;
}

class FakeValidationIssues extends ValidationIssuesNotifier {
  FakeValidationIssues(this.script);

  final IssueScript script;

  @override
  Future<List<ValidationIssue>> build() async {
    script.runs++;
    if (script.gate case final gate?) await gate.future;
    return script.issues;
  }

  @override
  Future<List<ValidationIssue>> refresh() {
    script.refreshes++;
    return super.refresh();
  }
}

ValidationIssue issue(
  ValidationDomain domain,
  String recordId,
  String name,
  ValidationSeverity severity,
  String message, {
  String? field,
}) => ValidationIssue(
  domain: domain,
  recordId: recordId,
  recordDisplayName: name,
  field: field,
  severity: severity,
  message: message,
);

/// [child] at `/` of a test router that also has every location the pages
/// navigate to, each showing `page <location>`.
class PageHarness {
  PageHarness({
    this.counts = const RecordCounts(
      classes: 2,
      abilities: 2,
      items: 5,
      recipes: 2,
      npcs: 2,
      lootTables: 1,
    ),
    RecordCounts deltas = const RecordCounts(classes: 2, abilities: -1),
    List<SaveHistoryEntry> history = sampleHistory,
    List<ValidationIssue> issues = const [],
    this.metadata = sampleMetadata,
  }) : lifecycle = FakeLifecycle(deltas),
       saveHistory = FakeSaveHistory(history),
       script = IssueScript(issues);

  final RecordCounts counts;
  final ProjectMetadata? metadata;
  final FakeLifecycle lifecycle;
  final FakeSaveHistory saveHistory;
  final IssueScript script;
  late ProviderContainer container;
  late GoRouter router;

  String get location =>
      router.routerDelegate.currentConfiguration.uri.toString();

  Future<void> pump(
    WidgetTester tester,
    Widget page, {
    EditingMode editingMode = EditingMode.fullPage,
    List overrides = const [],
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Widget shelled(Widget child) => Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(width: 220),
          Expanded(
            child: Padding(padding: const EdgeInsets.all(24), child: child),
          ),
        ],
      ),
    );
    router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => shelled(page)),
        GoRoute(
          path: '/:segment',
          builder: (_, s) => shelled(Text('page ${s.uri.path}')),
        ),
        GoRoute(
          path: '/:segment/:id',
          builder: (_, s) => shelled(Text('page ${s.uri.path}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    container = ProviderContainer(
      overrides: [
        initialAppSettingsProvider.overrideWithValue(
          AppSettings(editingMode: editingMode),
        ),
        clockProvider.overrideWithValue(() => testNow),
        routerProvider.overrideWithValue(router),
        dashboardProjectProvider.overrideWithValue(metadata),
        recordCountsProvider.overrideWith((ref) async {
          ref.watch(writeEpochProvider);
          return counts;
        }),
        lifecycleRepositoryProvider.overrideWithValue(lifecycle),
        saveHistoryRepositoryProvider.overrideWithValue(saveHistory),
        validationIssuesProvider.overrideWith(
          () => FakeValidationIssues(script),
        ),
        ...overrides.cast(),
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: anvilTheme(AnvilThemeSpec.dark),
          routerConfig: router,
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }
}
