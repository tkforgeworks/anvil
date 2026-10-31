/// Option 2: a purpose-built renderer for the Nunjucks subset Anvil documents
/// (plus the common idioms listed in FINDINGS.md), pure Dart, no calls into
/// host code, with resource limits.
library;

import 'ast.dart';
import 'errors.dart';
import 'evaluator.dart';
import 'parser.dart';

export 'errors.dart';
export 'evaluator.dart' show RenderLimits;

final class AnvilTemplate {
  AnvilTemplate._(this._nodes);

  /// Parses [source]; throws [AnvilTemplateError] (syntax or unsupported) with the
  /// position of the first problem.
  factory AnvilTemplate.parse(String source) =>
      AnvilTemplate._(parseTemplate(source));

  final List<Node> _nodes;

  String render(
    Map<String, Object?> context, {
    RenderLimits limits = const RenderLimits(),
  }) => Evaluator(context, limits).render(_nodes);

  /// Parse-only check, for flagging stored templates on project open.
  static AnvilTemplateError? check(String source) {
    try {
      AnvilTemplate.parse(source);
      return null;
    } on AnvilTemplateError catch (e) {
      return e;
    }
  }
}

/// Convenience matching the other engines' `render(source, context)` shape.
String renderAnvilTemplate(String source, Map<String, Object?> context) =>
    AnvilTemplate.parse(source).render(context);
