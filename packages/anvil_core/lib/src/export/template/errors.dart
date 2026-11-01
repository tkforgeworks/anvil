/// Errors raised by Anvil's template renderer.
library;

enum TemplateErrorKind {
  /// The template is malformed.
  syntax,

  /// Valid Nunjucks, but outside the subset Anvil 0.2 supports (design
  /// §11.5); always raised at parse time.
  unsupported,

  /// Rendering failed, for example by outputting an undefined value.
  render,

  /// A `RenderLimits` cap (iterations, string size, string work, nesting)
  /// was hit.
  limit,
}

/// A template failed to parse or render, with the 1-based position of the
/// offending tag, token or expression.
final class AnvilTemplateError implements Exception {
  AnvilTemplateError(this.kind, this.message, {this.line, this.column});

  final TemplateErrorKind kind;
  final String message;

  /// 1-based position; every error the parser and evaluator raise has one.
  final int? line;
  final int? column;

  @override
  String toString() {
    final at = line == null ? '' : ' [Line $line, Column $column]';
    return 'Template ${kind.name} error$at: $message';
  }
}
