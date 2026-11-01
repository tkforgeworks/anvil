/// A formula that does not parse: an unexpected character or token, a
/// missing parenthesis, or an empty formula. Messages are the Electron
/// 0.1.6 strings verbatim (`src/main/formula/engine.ts`).
final class FormulaSyntaxError implements Exception {
  const FormulaSyntaxError(this.message);

  final String message;

  @override
  String toString() => 'FormulaSyntaxError: $message';
}

/// A formula that parses but cannot be evaluated with the given bindings:
/// an unknown variable or function, or a division by zero.
final class FormulaRuntimeError implements Exception {
  const FormulaRuntimeError(this.message);

  final String message;

  @override
  String toString() => 'FormulaRuntimeError: $message';
}
