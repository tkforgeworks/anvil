import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:forge_ui/forge_ui.dart';

import 'anvil_colors.dart';
import 'anvil_palette.dart';
import 'color_math.dart';

/// The twelve colour decisions a theme is built from: the eleven roles a
/// custom theme file may set, plus the brightness they sit on. [dark] and
/// [light] are the Electron themes; [AnvilThemeSpec.custom] lays a file's
/// keys over one of them, exactly as the 0.1.x `buildCustomTheme` let MUI
/// fill omitted keys from the mode's defaults. One spec, one [anvilTheme]
/// path, so a custom file that repeats the defaults is the built-in theme.
@immutable
class AnvilThemeSpec {
  const AnvilThemeSpec({
    required this.brightness,
    required this.primary,
    required this.primaryEmphasis,
    required this.secondary,
    required this.backgroundDefault,
    required this.backgroundPaper,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.error,
    required this.warning,
    required this.info,
    required this.success,
    required this.divider,
  });

  /// Anvil Dark: `themes/dark.ts` over MUI's dark defaults.
  static const dark = AnvilThemeSpec(
    brightness: Brightness.dark,
    primary: AnvilPalette.darkPrimary,
    primaryEmphasis: AnvilPalette.darkPrimaryEmphasis,
    secondary: AnvilPalette.darkSecondary,
    backgroundDefault: AnvilPalette.darkBackground,
    backgroundPaper: AnvilPalette.darkPaper,
    textPrimary: AnvilPalette.darkTextPrimary,
    textSecondary: AnvilPalette.darkTextSecondary,
    textDisabled: AnvilPalette.darkTextDisabled,
    error: AnvilPalette.darkError,
    warning: AnvilPalette.darkWarning,
    info: AnvilPalette.darkInfo,
    success: AnvilPalette.darkSuccess,
    divider: AnvilPalette.darkDivider,
  );

  /// Anvil Light: `themes/light.ts` over MUI's light defaults.
  static const light = AnvilThemeSpec(
    brightness: Brightness.light,
    primary: AnvilPalette.lightPrimary,
    primaryEmphasis: AnvilPalette.lightPrimaryEmphasis,
    secondary: AnvilPalette.lightSecondary,
    backgroundDefault: AnvilPalette.lightBackground,
    backgroundPaper: AnvilPalette.lightPaper,
    textPrimary: AnvilPalette.lightTextPrimary,
    textSecondary: AnvilPalette.lightTextSecondary,
    textDisabled: AnvilPalette.lightTextDisabled,
    error: AnvilPalette.lightError,
    warning: AnvilPalette.lightWarning,
    info: AnvilPalette.lightInfo,
    success: AnvilPalette.lightSuccess,
    divider: AnvilPalette.lightDivider,
  );

  /// A custom theme file over the defaults of its `mode` (dark when the
  /// file names none, as in 0.1.x). A file cannot set the emphasised primary,
  /// so when it sets `primary` that is derived the way MUI did
  /// (`darken(main, 0.3)`, the dark tonal offset).
  factory AnvilThemeSpec.custom(CustomThemeColors colors) {
    final base = colors.mode == 'light' ? light : dark;
    Color pick(String key, Color fallback) {
      final hex = colors[key];
      return hex == null ? fallback : hexToColor(hex);
    }

    final primary = pick('primary', base.primary);
    return AnvilThemeSpec(
      brightness: base.brightness,
      primary: primary,
      primaryEmphasis: colors.primary == null
          ? base.primaryEmphasis
          : darken(primary, 0.3),
      secondary: pick('secondary', base.secondary),
      backgroundDefault: pick('backgroundDefault', base.backgroundDefault),
      backgroundPaper: pick('backgroundPaper', base.backgroundPaper),
      textPrimary: pick('textPrimary', base.textPrimary),
      textSecondary: pick('textSecondary', base.textSecondary),
      textDisabled: base.textDisabled,
      error: pick('error', base.error),
      warning: pick('warning', base.warning),
      info: pick('info', base.info),
      success: pick('success', base.success),
      divider: pick('divider', base.divider),
    );
  }

  final Brightness brightness;
  final Color primary;
  final Color primaryEmphasis;
  final Color secondary;
  final Color backgroundDefault;
  final Color backgroundPaper;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color error;
  final Color warning;
  final Color info;
  final Color success;
  final Color divider;

  bool get isDark => brightness == Brightness.dark;

  @override
  bool operator ==(Object other) =>
      other is AnvilThemeSpec &&
      other.brightness == brightness &&
      other.primary == primary &&
      other.primaryEmphasis == primaryEmphasis &&
      other.secondary == secondary &&
      other.backgroundDefault == backgroundDefault &&
      other.backgroundPaper == backgroundPaper &&
      other.textPrimary == textPrimary &&
      other.textSecondary == textSecondary &&
      other.textDisabled == textDisabled &&
      other.error == error &&
      other.warning == warning &&
      other.info == info &&
      other.success == success &&
      other.divider == divider;

  @override
  int get hashCode => Object.hash(
    brightness,
    primary,
    primaryEmphasis,
    secondary,
    backgroundDefault,
    backgroundPaper,
    textPrimary,
    textSecondary,
    textDisabled,
    error,
    warning,
    info,
    success,
    divider,
  );
}

/// Builds Anvil's theme from [spec] on the shared `forgeTheme` at desktop
/// density: the spec's colours become the Material [ColorScheme], the
/// `ForgeTokens` (including the warning, info and success intents) and
/// [AnvilColors]; type, shapes, the scrollbar and every component theme
/// come from `forge_ui`.
///
/// The MUI → Material 3 mapping: `background.default` is the scaffold
/// `surface`, `background.paper` is `surfaceContainerLowest` (cards, inputs,
/// the dark app bar), the hover / selected / activated state tints MUI drew
/// over paper are the `surfaceContainer` steps, `divider` is both outline
/// roles, and each MUI intent gets a tinted container with the intent colour
/// as its text, as MUI's standard alerts did.
ThemeData anvilTheme(AnvilThemeSpec spec) {
  final dark = spec.isDark;
  final paper = spec.backgroundPaper;
  // MUI action opacities for the current mode.
  final hover = dark ? 0.08 : 0.04;
  final selected = dark ? 0.16 : 0.08;
  final activated = dark ? 0.24 : 0.12;

  Color tint(Color c, double opacity) =>
      Color.alphaBlend(c.withValues(alpha: opacity), paper);
  Color onContainer(Color intent) => dark ? intent : darken(intent, 0.3);

  final scheme = ColorScheme(
    brightness: spec.brightness,
    primary: spec.primary,
    onPrimary: contrastText(spec.primary),
    primaryContainer: tint(spec.primary, selected),
    onPrimaryContainer: spec.primary,
    secondary: spec.secondary,
    onSecondary: contrastText(spec.secondary),
    secondaryContainer: tint(spec.secondary, selected),
    onSecondaryContainer: spec.secondary,
    tertiary: spec.secondary,
    onTertiary: contrastText(spec.secondary),
    tertiaryContainer: tint(spec.secondary, selected),
    onTertiaryContainer: spec.secondary,
    error: spec.error,
    onError: contrastText(spec.error),
    errorContainer: tint(spec.error, selected),
    onErrorContainer: onContainer(spec.error),
    surface: spec.backgroundDefault,
    onSurface: spec.textPrimary,
    surfaceContainerLowest: paper,
    surfaceContainerLow: spec.backgroundDefault,
    surfaceContainer: tint(spec.textPrimary, hover),
    surfaceContainerHigh: tint(spec.textPrimary, selected),
    surfaceContainerHighest: tint(spec.textPrimary, activated),
    onSurfaceVariant: spec.textSecondary,
    outline: spec.divider,
    outlineVariant: spec.divider,
    shadow: AnvilPalette.black,
    scrim: AnvilPalette.black.withValues(alpha: 0.5),
    inverseSurface: Color.alphaBlend(spec.textPrimary, paper),
    onInverseSurface: paper,
    inversePrimary: spec.secondary,
    surfaceTint: spec.primary,
  );

  final tokens = ForgeTokens(
    accent: spec.secondary,
    link: spec.primary,
    textTertiary: spec.textSecondary,
    textGhost: spec.textDisabled,
    rowDivider: spec.divider,
    successContainer: tint(spec.success, selected),
    onSuccessContainer: onContainer(spec.success),
    errorTint: tint(spec.error, selected),
    skeletonBase: scheme.surfaceContainerHigh,
    skeletonHighlight: dark
        ? scheme.surfaceContainerHighest
        : scheme.surfaceContainerLow,
    // The MUI status trio, from the spec rather than forge_ui's fixed hues,
    // so a custom theme file's warning / info / success keys apply.
    warning: spec.warning,
    onWarning: contrastText(spec.warning),
    warningContainer: tint(spec.warning, selected),
    onWarningContainer: onContainer(spec.warning),
    info: spec.info,
    onInfo: contrastText(spec.info),
    infoContainer: tint(spec.info, selected),
    onInfoContainer: onContainer(spec.info),
    success: spec.success,
    onSuccess: contrastText(spec.success),
  );

  final anvil = AnvilColors(
    primaryEmphasis: spec.primaryEmphasis,
    textDisabled: spec.textDisabled,
    chartSeries: AnvilPalette.chartSeries,
  );

  return forgeTheme(
    seed: spec.primary,
    colorScheme: scheme,
    tokens: tokens,
    extensions: [anvil],
    density: ForgeDensity.desktop,
  );
}
