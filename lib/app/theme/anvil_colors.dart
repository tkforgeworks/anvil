import 'package:flutter/material.dart';

/// Colour roles of Anvil's own that neither [ColorScheme] nor `ForgeTokens`
/// has a slot for: the emphasised primary (MUI `primary.dark`, used for
/// hover and pressed states) and the disabled text shade. The status trio
/// (warning, info, success) and the scrollbar are `ForgeTokens` roles since
/// forge_ui 0.2.2 and are read through `context.forge`.
///
/// Read it with `context.anvil` (see [AnvilContext]) or [AnvilColors.of].
@immutable
class AnvilColors extends ThemeExtension<AnvilColors> {
  const AnvilColors({
    required this.primaryEmphasis,
    required this.textDisabled,
  });

  /// A darker primary for hover and pressed states (MUI `primary.dark`).
  final Color primaryEmphasis;

  /// Disabled text and icons (MUI `text.disabled`).
  final Color textDisabled;

  /// The roles of the nearest theme. Throws for a theme not built by
  /// `anvilTheme`, since there is no sensible fallback for these.
  static AnvilColors of(BuildContext context) =>
      Theme.of(context).extension<AnvilColors>()!;

  @override
  AnvilColors copyWith({Color? primaryEmphasis, Color? textDisabled}) =>
      AnvilColors(
        primaryEmphasis: primaryEmphasis ?? this.primaryEmphasis,
        textDisabled: textDisabled ?? this.textDisabled,
      );

  @override
  AnvilColors lerp(AnvilColors? other, double t) {
    if (other == null) return this;
    return AnvilColors(
      primaryEmphasis: Color.lerp(primaryEmphasis, other.primaryEmphasis, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AnvilColors &&
      other.primaryEmphasis == primaryEmphasis &&
      other.textDisabled == textDisabled;

  @override
  int get hashCode => Object.hash(primaryEmphasis, textDisabled);
}

/// `context.anvil.primaryEmphasis`. The scheme, text theme and shared roles
/// (including warning, info and success) are `context.colors`,
/// `context.text` and `context.forge`, from `forge_ui`.
extension AnvilContext on BuildContext {
  AnvilColors get anvil => AnvilColors.of(this);
}
