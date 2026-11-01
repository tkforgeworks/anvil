/// Resource caps for custom template rendering (design §11.4).
library;

/// Caps that keep a hostile or runaway template from hanging the app or
/// exhausting memory.
///
/// A template has no calls, macros, includes or `range`, and every loop
/// iterates a finite value from the export context, so these bound the total
/// work. Memory is bounded by the string caps, not by the render isolate:
/// isolates in one group share a heap. A `.anvil` file is shareable, so the
/// templates stored in it are untrusted input.
final class RenderLimits {
  const RenderLimits({
    this.maxIterations = defaultMaxIterations,
    this.maxOutputChars = defaultMaxOutputChars,
    this.maxWorkChars = defaultMaxWorkChars,
    this.maxNesting = defaultMaxNesting,
  });

  /// 5,000,000 loop iterations per render.
  static const defaultMaxIterations = 5000000;

  /// 32 Mi characters per output or intermediate string.
  static const defaultMaxOutputChars = 32 * 1024 * 1024;

  /// 256 Mi characters of string work per render.
  static const defaultMaxWorkChars = 256 * 1024 * 1024;

  /// Parser nesting depth of 200 (blocks, brackets, prefix operators).
  static const defaultMaxNesting = 200;

  /// Total loop iterations across the render.
  final int maxIterations;

  /// Size of the rendered output and of any single intermediate string.
  final int maxOutputChars;

  /// Total characters produced by string operations during the render.
  final int maxWorkChars;

  /// How deeply blocks and expressions may nest; checked at parse time, so a
  /// template that exceeds it fails `checkTemplate` as well.
  final int maxNesting;
}
