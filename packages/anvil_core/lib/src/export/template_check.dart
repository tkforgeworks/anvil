/// Detecting stored templates that Anvil 0.2 cannot render (design §11.5).
library;

import 'render_limits.dart';
import 'template/anvil_template.dart';
import 'template/errors.dart';

/// Why a template cannot be used, with the 1-based position to show in the
/// warning and to open the editor at.
final class TemplateCheck {
  const TemplateCheck(this.kind, this.message, this.line, this.column);

  /// `unsupported` for valid Nunjucks outside the subset, `syntax` for a
  /// malformed template, `limit` for nesting deeper than
  /// [RenderLimits.maxNesting].
  final TemplateErrorKind kind;
  final String message;
  final int line;
  final int column;

  @override
  bool operator ==(Object other) =>
      other is TemplateCheck &&
      other.kind == kind &&
      other.message == message &&
      other.line == line &&
      other.column == column;

  @override
  int get hashCode => Object.hash(kind, message, line, column);

  @override
  String toString() =>
      'TemplateCheck(${kind.name}, line $line, column $column: $message)';
}

/// Parses [source] without rendering it: null when Anvil can render it,
/// otherwise the first problem. Never modifies anything; run it on every
/// `custom_templates.template_source` when a project opens and when the
/// export page loads its templates.
TemplateCheck? checkTemplate(
  String source, {
  RenderLimits limits = const RenderLimits(),
}) {
  try {
    AnvilTemplate.parse(source, limits: limits);
    return null;
  } on AnvilTemplateError catch (e) {
    return TemplateCheck(e.kind, e.message, e.line ?? 1, e.column ?? 1);
  }
}
