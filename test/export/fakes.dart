/// In-memory fakes for the export page tests: an `ExportService` over a
/// `TemplateRepository` fake (the presets, then the stored templates checked
/// with the real `checkTemplate`), scripted renders, two domain
/// repositories (only `list`), and a harness at the app's 1400×800 with the
/// sidebar's width taken. No SQLite.
library;

import 'dart:async';
import 'dart:io';

import 'package:anvil/app/dialogs/file_dialogs.dart';
import 'package:anvil/app/export/export_controller.dart';
import 'package:anvil/app/export/export_page.dart';
import 'package:anvil/app/providers.dart';
import 'package:anvil/app/shell/app_router.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil/app/theme/anvil_metrics.dart';
import 'package:anvil/app/theme/anvil_theme.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../dialogs/fakes.dart' show FakeFileDialogs;

final linux = TargetPlatformVariant.only(TargetPlatform.linux);

const _ts = '2026-11-01T10:00:00.000Z';

/// Templates kept in a list, in name order as the real repository lists
/// them. Every call is logged.
class FakeTemplateRepository implements TemplateRepository {
  FakeTemplateRepository([List<CustomTemplate>? templates])
    : templates = [...?templates];

  final List<CustomTemplate> templates;
  final calls = <String>[];
  var _next = 1;

  /// Thrown by the next write when set.
  Object? failure;

  CustomTemplate _find(String id) => templates.firstWhere(
    (t) => t.id == id,
    orElse: () => throw RecordNotFound('custom_templates', id),
  );

  @override
  Future<List<CustomTemplate>> list() async =>
      [...templates]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  @override
  Future<CustomTemplate> get(String id) async => _find(id);

  @override
  Future<CustomTemplate> create(CreateTemplateInput input) async {
    calls.add('create ${input.name}');
    if (failure case final error?) {
      failure = null;
      throw error;
    }
    final t = CustomTemplate(
      id: 'tpl-new-${_next++}',
      name: input.name,
      description: input.description,
      templateSource: input.templateSource,
      format: input.format,
      createdAt: _ts,
      updatedAt: _ts,
    );
    templates.add(t);
    return t;
  }

  @override
  Future<CustomTemplate> update(String id, UpdateTemplateInput input) async {
    calls.add('update $id');
    final old = _find(id);
    final t = CustomTemplate(
      id: id,
      name: input.name ?? old.name,
      description: input.description ?? old.description,
      templateSource: input.templateSource ?? old.templateSource,
      format: input.format ?? old.format,
      createdAt: old.createdAt,
      updatedAt: _ts,
    );
    templates[templates.indexOf(old)] = t;
    return t;
  }

  @override
  Future<void> delete(String id) async {
    calls.add('delete $id');
    templates.remove(_find(id));
  }
}

CustomTemplate template(
  String id,
  String name,
  String source, {
  String description = '',
  String format = 'text',
}) => CustomTemplate(
  id: id,
  name: name,
  description: description,
  templateSource: source,
  format: format,
  createdAt: _ts,
  updatedAt: _ts,
);

/// One render request the page made.
typedef RenderCall = ({String selectorId, ExportScope scope});

/// An [ExportService] whose selectors come from [templates] and whose
/// renders answer from [onRender] (default: a text naming the request).
class FakeExportService extends ExportService {
  FakeExportService(this.templates) : super(projectPath: 'fake.anvil');

  final FakeTemplateRepository templates;
  final renders = <RenderCall>[];
  var listCount = 0;

  FutureOr<ExportOutput> Function(String id, ExportScope scope)? onRender;

  @override
  Future<List<ExportSelector>> listSelectors() async {
    listCount++;
    return [
      ...builtInPresets,
      for (final t in await templates.list())
        ExportSelector(
          id: t.id,
          name: t.name,
          description: t.description,
          format: t.format,
          builtIn: false,
          unsupported: checkTemplate(t.templateSource),
        ),
    ];
  }

  @override
  Future<ExportOutput> render(String selectorId, ExportScope scope) async {
    renders.add((selectorId: selectorId, scope: scope));
    if (onRender case final handler?) return handler(selectorId, scope);
    return ExportOutput(
      text: 'rendered $selectorId $scope',
      suggestedFileName: 'export.json',
    );
  }
}

/// Items and classes for the record scopes.
class FakeItems extends Fake implements ItemRepository {
  FakeItems(this.names);

  /// id → display name, in list order.
  final Map<String, String> names;

  @override
  Future<List<ItemRecord>> list({
    RecordListMode mode = RecordListMode.active,
  }) async {
    expect(mode, RecordListMode.active);
    return [
      for (final MapEntry(key: id, value: name) in names.entries)
        ItemRecord(
          id: id,
          displayName: name,
          exportKey: id,
          description: '',
          itemCategoryId: 'cat',
          rarityId: 'rar',
          createdAt: _ts,
          updatedAt: _ts,
          deletedAt: null,
        ),
    ];
  }
}

class FakeClasses extends Fake implements ClassRepository {
  FakeClasses(this.names);

  final Map<String, String> names;

  @override
  Future<List<ClassRecord>> list({
    RecordListMode mode = RecordListMode.active,
  }) async => [
    for (final MapEntry(key: id, value: name) in names.entries)
      ClassRecord(
        id: id,
        displayName: name,
        exportKey: id,
        description: '',
        resourceMultiplier: 1,
        createdAt: _ts,
        updatedAt: _ts,
        deletedAt: null,
      ),
  ];
}

/// The export page in a `GoRouter` at `/export` beside a `/validation`
/// stand-in, at the app's minimum width with the sidebar's 220 px taken.
class ExportHarness {
  ExportHarness({
    List<CustomTemplate>? templates,
    Map<String, String>? items,
    Map<String, String>? classes,
  }) : templates = FakeTemplateRepository(templates),
       items = FakeItems(
         items ?? const {'i-1': 'Bronze Axe', 'i-2': 'Iron Sword'},
       ),
       classes = FakeClasses(classes ?? const {'c-1': 'Mage'});

  final FakeTemplateRepository templates;
  late final service = FakeExportService(templates);
  final FakeItems items;
  final FakeClasses classes;
  final dialogs = FakeFileDialogs();
  late ProviderContainer container;
  late Directory dir;
  late AppLogger logger;

  /// The project's exports folder the dialogs start in (not created yet).
  String get exportsDir => '${dir.path}/Project/exports';

  int get epoch => container.read(writeEpochProvider);

  ExportPageState get state => container.read(exportPageProvider).value!;

  /// [state], or null while the first listing runs.
  ExportPageState? get loaded => container.read(exportPageProvider).value;

  /// The log file's lines.
  List<String> get logLines {
    final file = File('${dir.path}/logs/anvil.log');
    return file.existsSync() ? file.readAsLinesSync() : const [];
  }

  String get location => container
      .read(routerProvider)
      .routerDelegate
      .currentConfiguration
      .uri
      .toString();

  Future<void> pump(
    WidgetTester tester, {
    List<Override> overrides = const [],
    bool projectFolder = true,
    ExportService? exportService,
    TemplateRepository? templateRepository,
  }) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    dir = Directory.systemTemp.createTempSync('anvil-export');
    addTearDown(() => dir.deleteSync(recursive: true));
    logger = AppLogger(
      directory: '${dir.path}/logs',
      minimumLevel: LogLevel.debug,
    );
    final router = GoRouter(
      initialLocation: '/export',
      routes: [
        GoRoute(
          path: '/export',
          builder: (_, _) => const Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: AnvilLayout.sidebarWidth),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(AnvilSpacing.lg),
                    child: ExportPage(),
                  ),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/validation',
          builder: (_, _) => const Scaffold(body: Text('Validation stand-in')),
        ),
      ],
    );
    addTearDown(router.dispose);
    container = ProviderContainer(
      overrides: [
        exportServiceProvider.overrideWithValue(exportService ?? service),
        templateRepositoryProvider.overrideWithValue(
          templateRepository ?? templates,
        ),
        itemRepositoryProvider.overrideWithValue(items),
        classRepositoryProvider.overrideWithValue(classes),
        fileDialogsProvider.overrideWithValue(dialogs),
        exportDirectoryProvider.overrideWithValue(
          projectFolder ? exportsDir : null,
        ),
        appLoggerProvider.overrideWithValue(logger),
        routerProvider.overrideWithValue(router),
        ...overrides,
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
    await settle(tester);
  }

  /// Lets Riverpod's zero-length refresh timers and the fakes' futures run.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
  }
}
