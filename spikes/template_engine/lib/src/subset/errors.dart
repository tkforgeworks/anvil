/// Errors raised by the purpose-built Anvil template renderer.
library;

enum TemplateErrorKind {
  /// The template is malformed.
  syntax,

  /// Valid Nunjucks, but outside the subset this renderer supports.
  unsupported,

  /// Rendering failed (for example, outputting an undefined value).
  render,

  /// A resource limit (iterations, output size, nesting) was hit.
  limit,
}

final class AnvilTemplateError implements Exception {
  AnvilTemplateError(this.kind, this.message, {this.line, this.column});

  final TemplateErrorKind kind;
  final String message;

  /// 1-based position of the offending tag or token, when known.
  final int? line;
  final int? column;

  @override
  String toString() {
    final at = line == null ? '' : ' [Line $line, Column $column]';
    return 'Template ${kind.name} error$at: $message';
  }
}
