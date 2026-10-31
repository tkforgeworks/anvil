import 'package:flutter/painting.dart';

/// The Anvil palette as the Electron app shipped it: the two MUI themes in
/// `src/renderer/src/themes/` (0.1.6) plus the MUI palette defaults those
/// themes inherited for text, dividers and the status colours.
///
/// This is the only file in `lib/` that may write a colour literal. Every
/// widget reads colours through the theme (`context.colors`,
/// `context.forge`, `context.anvil`); see `.claude/CLAUDE.md`.
abstract final class AnvilPalette {
  // ---- Dark (`themes/dark.ts`) ----
  static const darkPrimary = Color(0xFF3B82F6);
  static const darkPrimaryEmphasis = Color(0xFF2563EB); // MUI primary.dark
  static const darkSecondary = Color(0xFF60A5FA);
  static const darkBackground = Color(0xFF0F172A);
  static const darkPaper = Color(0xFF1E293B);
  static const darkScrollbarThumb = Color(0xFF6B6B6B);

  // MUI dark palette defaults.
  static const darkTextPrimary = Color(0xFFFFFFFF);
  static const darkTextSecondary = Color(0xB3FFFFFF); // rgba(255,255,255,.7)
  static const darkTextDisabled = Color(0x80FFFFFF); // rgba(255,255,255,.5)
  static const darkDivider = Color(0x1FFFFFFF); // rgba(255,255,255,.12)
  static const darkError = Color(0xFFF44336); // red[500]
  static const darkWarning = Color(0xFFFFA726); // orange[400]
  static const darkInfo = Color(0xFF29B6F6); // lightBlue[400]
  static const darkSuccess = Color(0xFF66BB6A); // green[400]

  // ---- Light (`themes/light.ts`) ----
  static const lightPrimary = Color(0xFF2563EB);
  static const lightPrimaryEmphasis = Color(0xFF1D4ED8); // MUI primary.dark
  static const lightSecondary = Color(0xFF3B82F6);
  static const lightBackground = Color(0xFFF8FAFC);
  static const lightPaper = Color(0xFFFFFFFF);

  // MUI light palette defaults.
  static const lightTextPrimary = Color(0xDE000000); // rgba(0,0,0,.87)
  static const lightTextSecondary = Color(0x99000000); // rgba(0,0,0,.6)
  static const lightTextDisabled = Color(0x61000000); // rgba(0,0,0,.38)
  static const lightDivider = Color(0x1F000000); // rgba(0,0,0,.12)
  static const lightError = Color(0xFFD32F2F); // red[700]
  static const lightWarning = Color(0xFFED6C02);
  static const lightInfo = Color(0xFF0288D1); // lightBlue[700]
  static const lightSuccess = Color(0xFF2E7D32); // green[800]

  // ---- Neutral anchors the derivations blend toward ----
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
}
