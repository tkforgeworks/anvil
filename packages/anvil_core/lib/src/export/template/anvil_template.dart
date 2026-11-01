/// Anvil's custom template renderer: a purpose-built renderer of the
/// Nunjucks-compatible subset (design §11), pure Dart, with no calls into
/// host code and with resource limits.
library;

import '../render_limits.dart';
import 'ast.dart';
import 'errors.dart';
import 'evaluator.dart';
import 'parser.dart';

/// A parsed custom template.
///
/// For supported features the output is Anvil 0.1.6's byte for byte; the
/// ANVL-151 parity corpus and fixtures are the specification.
final class AnvilTemplate {
  AnvilTemplate._(this._nodes);

  /// Parses [source]. Throws [AnvilTemplateError] of kind `syntax`,
  /// `unsupported` or `limit` (nesting deeper than
  /// [RenderLimits.maxNesting]) at the first problem.
  factory AnvilTemplate.parse(
    String source, {
    RenderLimits limits = const RenderLimits(),
  }) => AnvilTemplate._(parseTemplate(source, maxNesting: limits.maxNesting));

  final List<Node> _nodes;

  /// Renders against the export [context] (the JSON-shaped map the context
  /// assembler builds; `ctx` is an alias for it). Throws [AnvilTemplateError]
  /// of kind `render` or `limit`.
  String render(
    Map<String, Object?> context, {
    RenderLimits limits = const RenderLimits(),
  }) => Evaluator(context, limits).render(_nodes);
}
