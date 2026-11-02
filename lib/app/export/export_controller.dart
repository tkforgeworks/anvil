/// The state behind the Export page (design §11.5, §11.9; 0.1.6
/// `ExportPage.tsx` and `export.handlers.ts`): the preset and template
/// selector, the scope, the record checklist, preview and execute through
/// `ExportService`, and the template writes through `TemplateRepository`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dialogs/file_dialogs.dart';
import '../lists/record_list_controller.dart' show listErrorMessage;
import '../providers.dart';
import '../shell/shell_domain.dart';
import '../shell/shell_providers.dart';

/// The export pipeline over the open project's file. Tests override it with
/// a fake.
final exportServiceProvider = Provider<ExportService>(
  (ref) =>
      ExportService(projectPath: ref.watch(requireSessionProvider).filePath),
);

/// The open project's `exports/` folder, or null for a project without the
/// folder structure; the dialogs start there (0.1.6 `getDefaultExportDir`).
final exportDirectoryProvider = Provider<String?>(
  (ref) => ref.watch(projectSessionProvider)?.metadata.projectFolder?.exports,
);

/// Whether this session's unsupported-templates notice has been shown.
/// Not auto-disposed, so it survives leaving the export page; it resets
/// when the session is replaced or cleared because [build] watches it.
final unsupportedTemplatesNoticeProvider =
    NotifierProvider<UnsupportedTemplatesNotice, bool>(
      UnsupportedTemplatesNotice.new,
    );

class UnsupportedTemplatesNotice extends Notifier<bool> {
  @override
  bool build() {
    ref.watch(projectSessionProvider);
    return false;
  }

  /// True the first time it is called for the current session.
  bool claim() {
    if (state) return false;
    state = true;
    return true;
  }
}

/// The notice for [count] custom templates the renderer cannot run.
String unsupportedTemplatesNotice(int count) => count == 1
    ? '1 custom template needs changes before it can export'
    : '$count custom templates need changes before they can export';

/// The warning shown beneath the selector for one unsupported template.
String unsupportedTemplateWarning(String name, TemplateCheck check) =>
    '$name: ${check.message} (line ${check.line}, column ${check.column}), '
    'which Anvil 0.2 does not support. Edit the template to export with it.';

/// 0.1.6's three scope modes.
enum ExportScopeMode {
  full('Full Project'),
  domain('Single Domain'),
  selection('Record Selection');

  const ExportScopeMode(this.label);

  final String label;
}

/// The label 0.1.6's `DOMAIN_OPTIONS` gave [domain], which is the sidebar
/// label.
String exportDomainLabel(ExportDomain domain) => _shellDomain(domain).label;

ShellDomain _shellDomain(ExportDomain domain) => switch (domain) {
  ExportDomain.classes => ShellDomain.classes,
  ExportDomain.abilities => ShellDomain.abilities,
  ExportDomain.items => ShellDomain.items,
  ExportDomain.recipes => ShellDomain.recipes,
  ExportDomain.npcs => ShellDomain.npcs,
  ExportDomain.lootTables => ShellDomain.lootTables,
};

/// One record of the selection checklist.
typedef ExportRecordRef = ({String id, String displayName});

/// What the page shows.
class ExportPageState {
  const ExportPageState({
    required this.selectors,
    required this.selectedId,
    required this.mode,
    required this.domain,
    required this.records,
    required this.recordsLoaded,
    required this.checked,
    required this.preview,
    required this.busy,
    required this.error,
    required this.blockedByValidation,
    required this.success,
    required this.notice,
  });

  /// The presets, then the stored templates.
  final List<ExportSelector> selectors;
  final String? selectedId;
  final ExportScopeMode mode;

  /// The domain of the domain and selection scopes; null until chosen.
  final ExportDomain? domain;

  /// The active records of [domain], in the repository's order.
  final List<ExportRecordRef> records;

  /// [records] reflect [domain] (false while they load).
  final bool recordsLoaded;
  final Set<String> checked;

  /// The last preview's text; cleared by any change of selector or scope.
  final String? preview;

  /// A preview, an export or a template write is in flight.
  final bool busy;
  final String? error;

  /// [error] is the validation gate's message.
  final bool blockedByValidation;
  final String? success;

  /// The one-time unsupported-templates notice for this session, set by the
  /// listing that claimed it; the page shows it as a snackbar.
  final String? notice;

  ExportSelector? get selected {
    for (final s in selectors) {
      if (s.id == selectedId) return s;
    }
    return null;
  }

  /// The custom templates the renderer cannot run.
  List<ExportSelector> get unsupported => [
    for (final s in selectors)
      if (s.unsupported != null) s,
  ];

  /// 0.1.6's `canPreview`: a selector, and a domain unless the scope is the
  /// full project. Preview and Export to File also wait for [busy].
  bool get canRun =>
      !busy &&
      selected != null &&
      selected!.unsupported == null &&
      (mode == ExportScopeMode.full || domain != null);

  /// 0.1.6's `buildScope`: a selection with nothing checked exports the
  /// whole domain.
  ExportScope get scope {
    final domain = this.domain;
    if (mode == ExportScopeMode.selection &&
        domain != null &&
        checked.isNotEmpty) {
      return ExportScope.selection(domain, [
        for (final r in records)
          if (checked.contains(r.id)) r.id,
      ]);
    }
    if (mode != ExportScopeMode.full && domain != null) {
      return ExportScope.domain(domain);
    }
    return const ExportScope.full();
  }
}

/// The export page's controller.
final exportPageProvider =
    AsyncNotifierProvider.autoDispose<ExportPageController, ExportPageState>(
      ExportPageController.new,
      name: 'exportPage',
    );

/// Lists the selectors in [build], which watches [writeEpochProvider] and
/// the nullable `projectSessionProvider`, so a template write (or any other
/// write) re-lists them while the page's choices survive in fields. The
/// selected entry falls back to the first supported selector when it
/// disappears or cannot run, as 0.1.6's `loadPresets` fell back to the
/// first. The domain's records are re-read on every build and the checked
/// ids pruned to them.
class ExportPageController extends AsyncNotifier<ExportPageState> {
  var _selectors = <ExportSelector>[];
  String? _selectedId;
  var _mode = ExportScopeMode.full;
  ExportDomain? _domain;
  var _records = <ExportRecordRef>[];
  var _recordsLoaded = false;
  var _checked = <String>{};
  String? _preview;
  var _busy = false;
  String? _error;
  var _blocked = false;
  String? _success;
  String? _notice;

  /// Bumped whenever the mode or domain changes, so a slow record load for
  /// an earlier choice is dropped.
  var _recordsGeneration = 0;

  @override
  Future<ExportPageState> build() async {
    ref.watch(writeEpochProvider);
    ref.watch(projectSessionProvider);
    _notice = null;
    try {
      final selectors = await ref.read(exportServiceProvider).listSelectors();
      if (!ref.mounted) return _snapshot();
      _selectors = List.unmodifiable(selectors);
      _selectedId = _pick(_selectedId);
      final unsupported = _selectors.where((s) => s.unsupported != null);
      if (unsupported.isNotEmpty &&
          ref.read(unsupportedTemplatesNoticeProvider.notifier).claim()) {
        final message = unsupportedTemplatesNotice(unsupported.length);
        _notice = message;
        ref.read(appLoggerProvider).warn(message);
      }
    } catch (error) {
      if (!ref.mounted) return _snapshot();
      _error = listErrorMessage(error, 'Failed to load export templates.');
    }
    await _reloadRecords(clear: false);
    return _snapshot();
  }

  /// [current] when it is listed and can run, else the first selector that
  /// can.
  String? _pick(String? current) {
    for (final s in _selectors) {
      if (s.id == current && s.unsupported == null) return current;
    }
    for (final s in _selectors) {
      if (s.unsupported == null) return s.id;
    }
    return null;
  }

  void select(String id) {
    if (id == _selectedId) return;
    final entry = _selectors.where((s) => s.id == id).firstOrNull;
    if (entry == null || entry.unsupported != null) return;
    _selectedId = id;
    _preview = null;
    _emit();
  }

  Future<void> setMode(ExportScopeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    _preview = null;
    await _reloadRecords(clear: true);
  }

  Future<void> setDomain(ExportDomain? domain) async {
    if (domain == _domain) return;
    _domain = domain;
    _preview = null;
    await _reloadRecords(clear: true);
  }

  void toggleRecord(String id) {
    final next = {..._checked};
    if (!next.remove(id)) next.add(id);
    _checked = next;
    _preview = null;
    _emit();
  }

  /// 0.1.6's `toggleAll`: clears the checklist when every record is
  /// checked, else checks every record.
  void toggleAll() {
    _checked = _checked.length == _records.length
        ? {}
        : {for (final r in _records) r.id};
    _preview = null;
    _emit();
  }

  /// Dismisses the error line.
  void clearError() {
    _error = null;
    _blocked = false;
    _emit();
  }

  void clearSuccess() {
    _success = null;
    _emit();
  }

  /// Loads the records of the domain scopes. [clear] empties the checklist
  /// first, as 0.1.6 did on every mode or domain change; a reload after a
  /// write keeps the checked ids that still exist.
  Future<void> _reloadRecords({required bool clear}) async {
    final generation = clear ? ++_recordsGeneration : _recordsGeneration;
    final domain = _domain;
    if (clear) {
      _records = [];
      _checked = {};
    }
    if (_mode == ExportScopeMode.full || domain == null) {
      _records = [];
      _checked = {};
      _recordsLoaded = true;
      if (clear) _emit();
      return;
    }
    if (clear) {
      _recordsLoaded = false;
      _emit();
    }
    try {
      final records = await _list(domain);
      if (!ref.mounted || generation != _recordsGeneration) return;
      _records = List.unmodifiable(records);
      final ids = {for (final r in records) r.id};
      _checked = _checked.where(ids.contains).toSet();
    } catch (error) {
      if (!ref.mounted || generation != _recordsGeneration) return;
      _records = [];
      _checked = {};
      _error = listErrorMessage(
        error,
        'Failed to load ${exportDomainLabel(domain).toLowerCase()}.',
      );
    }
    _recordsLoaded = true;
    if (clear) _emit();
  }

  Future<List<ExportRecordRef>> _list(ExportDomain domain) async {
    ExportRecordRef row(String id, String name) => (id: id, displayName: name);
    return switch (domain) {
      ExportDomain.classes => [
        for (final r in await ref.read(classRepositoryProvider).list())
          row(r.id, r.displayName),
      ],
      ExportDomain.abilities => [
        for (final r in await ref.read(abilityRepositoryProvider).list())
          row(r.id, r.displayName),
      ],
      ExportDomain.items => [
        for (final r in await ref.read(itemRepositoryProvider).list())
          row(r.id, r.displayName),
      ],
      ExportDomain.recipes => [
        for (final r in await ref.read(recipeRepositoryProvider).list())
          row(r.id, r.displayName),
      ],
      ExportDomain.npcs => [
        for (final r in await ref.read(npcRepositoryProvider).list())
          row(r.id, r.displayName),
      ],
      ExportDomain.lootTables => [
        for (final r in await ref.read(lootTableRepositoryProvider).list())
          row(r.id, r.displayName),
      ],
    };
  }

  /// Renders the selection for the preview panel.
  Future<void> preview() async {
    final current = _snapshot();
    if (!current.canRun) return;
    _start(clearPreview: true);
    try {
      final out = await ref
          .read(exportServiceProvider)
          .render(current.selectedId!, current.scope);
      if (!ref.mounted) return;
      _preview = out.text;
    } catch (error) {
      if (!ref.mounted) return;
      _fail(error, 'Preview failed.');
    } finally {
      _finish();
    }
  }

  /// Renders the selection and writes it where the user picks: a folder for
  /// more than one CSV file (every file written into it), else one file.
  /// Both dialogs start in the project's `exports/` folder, created if
  /// missing. Files are written as UTF-8.
  Future<void> execute() async {
    final current = _snapshot();
    if (!current.canRun) return;
    _start(clearPreview: false);
    try {
      final out = await ref
          .read(exportServiceProvider)
          .render(current.selectedId!, current.scope);
      if (!ref.mounted) return;
      final dialogs = ref.read(fileDialogsProvider);
      final initial = await _exportDirectory();
      if (!ref.mounted) return;
      final String path;
      if (out.files.length > 1) {
        final folder = await dialogs.pickDirectory(initialDirectory: initial);
        if (!ref.mounted) return;
        if (folder == null) {
          _error = 'Export canceled.';
          return;
        }
        await Directory(folder).create(recursive: true);
        for (final file in out.files) {
          await File('$folder${Platform.pathSeparator}${file.filename}')
              .writeAsString(file.content, encoding: utf8, flush: true);
        }
        path = folder;
      } else {
        final target = await dialogs.pickSaveLocation(
          initialDirectory: initial,
          suggestedName: out.suggestedFileName,
        );
        if (!ref.mounted) return;
        if (target == null) {
          _error = 'Export canceled.';
          return;
        }
        await File(target).writeAsString(out.text, encoding: utf8, flush: true);
        path = target;
      }
      if (!ref.mounted) return;
      ref.read(appLoggerProvider).info('Export completed');
      _success = 'Exported to $path';
    } catch (error, stack) {
      if (!ref.mounted) return;
      final log = ref.read(appLoggerProvider);
      if (error is ExportBlocked) {
        log.info('Export blocked by validation errors');
      } else {
        log.error('Export failed', error, stack);
      }
      _fail(error, 'Export failed.');
    } finally {
      _finish();
    }
  }

  /// The project's exports folder, created if missing; null when the
  /// project has none or it cannot be created.
  Future<String?> _exportDirectory() async {
    final dir = ref.read(exportDirectoryProvider);
    if (dir == null) return null;
    try {
      await Directory(dir).create(recursive: true);
      return dir;
    } on FileSystemException {
      return null;
    }
  }

  void _start({required bool clearPreview}) {
    _busy = true;
    _error = null;
    _blocked = false;
    _success = null;
    if (clearPreview) _preview = null;
    _emit();
  }

  void _finish() {
    if (!ref.mounted) return;
    _busy = false;
    _emit();
  }

  void _fail(Object error, String fallback) {
    switch (error) {
      case ExportBlocked(:final message):
        _error = message;
        _blocked = true;
      case AnvilTemplateError():
        _error = error.toString();
      case RenderTimeout():
        _error = 'Export timed out after 10 s.';
      default:
        _error = fallback;
    }
  }

  /// The stored template behind selector [id], for the edit dialog.
  Future<CustomTemplate> loadTemplate(String id) =>
      ref.read(templateRepositoryProvider).get(id);

  /// Stores a new template and selects it (when it can run). Bumps the
  /// write epoch once, which re-lists the selectors.
  Future<CustomTemplate> createTemplate(CreateTemplateInput input) async {
    final created = await ref.read(templateRepositoryProvider).create(input);
    if (!ref.mounted) return created;
    _selectedId = created.id;
    _preview = null;
    ref.read(writeEpochProvider.notifier).bump();
    return created;
  }

  /// Overwrites template [id]. Bumps the write epoch once.
  Future<CustomTemplate> updateTemplate(
    String id,
    UpdateTemplateInput input,
  ) async {
    final updated = await ref
        .read(templateRepositoryProvider)
        .update(id, input);
    if (!ref.mounted) return updated;
    if (id == _selectedId) _preview = null;
    ref.read(writeEpochProvider.notifier).bump();
    return updated;
  }

  /// Deletes template [id]; a deleted selected template falls back to the
  /// first selector. Bumps the write epoch once. Failures go to the error
  /// line.
  Future<bool> deleteTemplate(String id) async {
    if (_busy) return false;
    _busy = true;
    _error = null;
    _blocked = false;
    _success = null;
    _emit();
    try {
      await ref.read(templateRepositoryProvider).delete(id);
      if (!ref.mounted) return false;
      if (_selectedId == id) {
        _selectedId = null;
        _preview = null;
      }
      ref.read(writeEpochProvider.notifier).bump();
      return true;
    } catch (error) {
      if (!ref.mounted) return false;
      _error = listErrorMessage(error, 'Failed to delete template.');
      return false;
    } finally {
      _finish();
    }
  }

  void _emit() => state = AsyncData(_snapshot());

  ExportPageState _snapshot() => ExportPageState(
    selectors: _selectors,
    selectedId: _selectedId ?? _pick(null),
    mode: _mode,
    domain: _domain,
    records: _records,
    recordsLoaded: _recordsLoaded,
    checked: Set.unmodifiable(_checked),
    preview: _preview,
    busy: _busy,
    error: _error,
    blockedByValidation: _blocked,
    success: _success,
    notice: _notice,
  );
}
