/// Builds colours from theme-file values and derives shades the way MUI did,
/// so a custom file renders the colours it rendered in Anvil 0.1.x. These
/// construct `Color`s from computed channels, not literals; the palette's
/// literal check exempts this file for that reason.
library;

import 'package:flutter/painting.dart';

import 'anvil_palette.dart';

/// `#RRGGBB` or `#RRGGBBAA` (as `CustomThemeColors` validates) to a [Color].
Color hexToColor(String hex) {
  final digits = hex.substring(1);
  assert(digits.length == 6 || digits.length == 8, 'not a theme colour: $hex');
  final rgb = int.parse(digits.substring(0, 6), radix: 16);
  final alpha = digits.length == 8
      ? int.parse(digits.substring(6, 8), radix: 16)
      : 0xFF;
  return Color((alpha << 24) | rgb);
}

/// MUI's `darken(color, coefficient)`: each 8-bit channel scaled by
/// `1 - coefficient` and truncated (its `recomposeColor` used `parseInt`),
/// alpha kept.
Color darken(Color c, double coefficient) {
  final argb = c.toARGB32();
  int channel(int shift) =>
      (((argb >> shift) & 0xFF) * (1 - coefficient)).truncate();
  return Color.fromARGB(
    (argb >> 24) & 0xFF,
    channel(16),
    channel(8),
    channel(0),
  );
}

/// MUI's `getContrastText`: white when it reaches 3:1 on [background],
/// otherwise the light-mode primary text (black at 87%).
Color contrastText(Color background) =>
    contrastRatio(background, AnvilPalette.white) >= 3
    ? AnvilPalette.darkTextPrimary
    : AnvilPalette.lightTextPrimary;

/// WCAG contrast ratio of two colours, alpha ignored as MUI ignores it.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
