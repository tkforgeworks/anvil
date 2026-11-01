/// The export pipeline (design §11.9): validation gate, context assembly and
/// rendering on a background isolate over its own read-only connection.
///
/// Ports `EXPORT_GET_TEMPLATES`, `EXPORT_PREVIEW` and the rendering half of
/// `EXPORT_EXECUTE` from 0.1.6 `src/main/ipc/export.handlers.ts`. Preview
/// and execute rendered the same thing; the file write is the app's job.
library;

import 'dart:isolate';

import '../db/project_database.dart';
import '../repositories/sqlite_template_repository.dart';
import '../validation/validate_project.dart';
import '../validation/validation_issue.dart';
import 'context_assembler.dart';
import 'export_scope.dart';
import 'presets.dart';
import 'render_isolate.dart';
import 'render_limits.dart';
import 'template_check.dart';

/// The validation gate refused the export: the project has error-severity
/// issues. [message] is 0.1.6's text.
final class ExportBlocked implements Exception {
  const ExportBlocked(this.message);

  final String message;

  @override
  String toString() => 'ExportBlocked: $message';
}

/// One entry of the export page's selector: a built-in preset or a stored
/// custom template (0.1.6 `ExportPresetInfo`, plus [unsupported]).
final class ExportSelector {
  const ExportSelector({
    required this.id,
    required this.name,
    required this.description,
    required this.format,
    required this.builtIn,
    this.unsupported,
  });

  final String id;
  final String name;
  final String description;

  /// `json` or `csv` for the presets; the stored free text for templates.
  final String format;
  final bool builtIn;

  /// For a custom template the renderer cannot run, the first problem
  /// [checkTemplate] found; the page disables such a template (design
  /// §11.5). Always null for the presets.
  final TemplateCheck? unsupported;

  @override
  bool operator ==(Object other) =>
      other is ExportSelector &&
      other.id == id &&
      other.name == name &&
      other.description == description &&
      other.format == format &&
      other.builtIn == builtIn &&
      other.unsupported == unsupported;

  @override
  int get hashCode =>
      Object.hash(id, name, description, format, builtIn, unsupported);

  @override
  String toString() =>
      'ExportSelector($id, $name, $format, builtIn: $builtIn'
      '${unsupported == null ? '' : ', unsupported: $unsupported'})';
}

/// The three built-in presets, verbatim from 0.1.6 `BUILT_IN_PRESETS`
/// (`src/main/export/renderer.ts`).
const List<ExportSelector> builtInPresets = [
  ExportSelector(
    id: 'nested-json',
    name: 'Nested JSON',
    description:
        'Hierarchical JSON with nested sub-objects for referenced records',
    format: 'json',
    builtIn: true,
  ),
  ExportSelector(
    id: 'flat-json',
    name: 'Flat JSON',
    description: 'Flat JSON with all reference fields resolved to export keys',
    format: 'json',
    builtIn: true,
  ),
  ExportSelector(
    id: 'csv',
    name: 'CSV',
    description: 'One CSV file per domain, references resolved to export keys',
    format: 'csv',
    builtIn: true,
  ),
];

/// What one export rendered.
final class ExportOutput {
  ExportOutput({
    required this.text,
    List<CsvFile> files = const [],
    required this.suggestedFileName,
  }) : files = List.unmodifiable(files);

  /// The single-file output, or for CSV the preview summary 0.1.6 showed
  /// (`--- <file> ---` before each file).
  final String text;

  /// CSV only: one file per non-empty domain; empty otherwise. 0.1.6 asked
  /// for a folder only when there was more than one file, and otherwise
  /// wrote [text] (so a one-file CSV export saved the summary).
  final List<CsvFile> files;

  /// `export.json` for the two JSON presets and `export.txt` for anything
  /// else, custom templates included whatever their format, as 0.1.6's save
  /// dialog defaulted.
  final String suggestedFileName;
}

/// The message 0.1.6's `runValidationGate` returned for [errorCount] errors.
String _blockedMessage(int errorCount) =>
    'Export blocked: $errorCount validation '
    '${errorCount == 1 ? 'error' : 'errors'} must be resolved before '
    'exporting.';

/// Runs exports off the UI isolate.
///
/// `sqlite3` handles cannot cross isolates, and the UI isolate's
/// [ProjectDatabase] is never used: each call sends only [projectPath], the
/// background isolate opens its own read-only connection, and only plain
/// values come back. Exports see committed data only.
final class ExportService {
  ExportService({
    required this.projectPath,
    this.renderLimits = const RenderLimits(),
    this.renderTimeout = const Duration(seconds: 10),
  });

  /// The project file the background isolate opens.
  final String projectPath;

  /// Caps and timeout for custom templates, passed to
  /// [renderTemplateIsolated].
  final RenderLimits renderLimits;
  final Duration renderTimeout;

  /// The built-in presets followed by the stored templates (ordered by name
  /// ignoring case), each template checked with [checkTemplate].
  Future<List<ExportSelector>> listSelectors() {
    final path = projectPath;
    final limits = renderLimits;
    return Isolate.run(() async {
      final db = ProjectDatabase.openReadOnly(path);
      try {
        final templates = await SqliteTemplateRepository(db).list();
        return [
          ...builtInPresets,
          for (final t in templates)
            ExportSelector(
              id: t.id,
              name: t.name,
              description: t.description,
              format: t.format,
              builtIn: false,
              unsupported: checkTemplate(t.templateSource, limits: limits),
            ),
        ];
      } finally {
        db.close();
      }
    });
  }

  /// Renders the preset or custom template [selectorId] for [scope].
  ///
  /// Throws [ExportBlocked] when validation reports any error;
  /// `RecordNotFound('custom_templates', id)` for an id that is neither a
  /// preset nor a stored template; for a template, its `AnvilTemplateError`
  /// (kind `unsupported` or `syntax` from parsing, `render` or `limit` from
  /// rendering) or [RenderTimeout].
  Future<ExportOutput> render(String selectorId, ExportScope scope) {
    final path = projectPath;
    final limits = renderLimits;
    final timeout = renderTimeout;
    return Isolate.run(() async {
      final Map<String, Object?> context;
      final String? templateSource;
      final db = ProjectDatabase.openReadOnly(path);
      try {
        _gate(db);
        context = db.read((tx) => assembleExportContext(tx, scope));
        final preset = _presetFor(selectorId);
        if (preset != null) {
          return _renderPreset(preset, context, scope);
        }
        templateSource = (await SqliteTemplateRepository(db).get(selectorId))
            .templateSource;
      } finally {
        db.close();
      }
      final text = await renderTemplateIsolated(
        templateSource,
        context,
        limits: limits,
        timeout: timeout,
      );
      return ExportOutput(text: text, suggestedFileName: 'export.txt');
    });
  }
}

/// 0.1.6 `runValidationGate`.
void _gate(ProjectDatabase db) {
  final errors = validateProject(db)
      .where((i) => i.severity == ValidationSeverity.error)
      .length;
  if (errors > 0) throw ExportBlocked(_blockedMessage(errors));
}

ExportSelector? _presetFor(String id) {
  for (final p in builtInPresets) {
    if (p.id == id) return p;
  }
  return null;
}

ExportOutput _renderPreset(
  ExportSelector preset,
  Map<String, Object?> context,
  ExportScope scope,
) {
  final fileName = preset.format == 'json' ? 'export.json' : 'export.txt';
  switch (preset.id) {
    case 'nested-json':
      return ExportOutput(
        text: renderNestedJson(context, fullScope: scope.isFull),
        suggestedFileName: fileName,
      );
    case 'flat-json':
      return ExportOutput(
        text: renderFlatJson(context, fullScope: scope.isFull),
        suggestedFileName: fileName,
      );
    case 'csv':
      final csv = renderCsv(context);
      return ExportOutput(
        text: csv.summary,
        files: csv.files,
        suggestedFileName: fileName,
      );
  }
  throw StateError('unknown preset ${preset.id}');
}
