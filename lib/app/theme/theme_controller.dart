import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';

import 'anvil_theme.dart';

/// The three theme settings the Electron app offered.
enum AnvilThemeMode { dark, light, custom }

/// Which theme is on, and for custom mode, the file it came from.
///
/// This is in-memory for now; persisting it in app settings is part of the
/// data core epic (ANVL-147). The shape mirrors the 0.1.x `AppSettings`
/// fields `theme`, `customThemePath` and `customThemeColors`.
@immutable
class ThemeSelection {
  const ThemeSelection._({
    required this.mode,
    this.customPath,
    this.customColors,
    this.customError,
  });

  const ThemeSelection.dark() : this._(mode: AnvilThemeMode.dark);

  const ThemeSelection.light() : this._(mode: AnvilThemeMode.light);

  const ThemeSelection.custom({required CustomThemeColors colors, String? path})
    : this._(
        mode: AnvilThemeMode.custom,
        customPath: path,
        customColors: colors,
      );

  final AnvilThemeMode mode;

  /// Where the custom colours were loaded from, when they came from a file.
  final String? customPath;

  /// The custom colours; set whenever a custom file has been accepted, even
  /// while another mode is showing, so switching back to Custom is instant.
  final CustomThemeColors? customColors;

  /// The last failed load's message, shown until the next attempt or mode
  /// change; the theme itself is unchanged by a failed load, as in 0.1.x.
  final String? customError;

  /// The spec the selection resolves to. Custom without colours falls back
  /// to dark, as the Electron `main.tsx` did.
  AnvilThemeSpec get spec => switch (mode) {
    AnvilThemeMode.dark => AnvilThemeSpec.dark,
    AnvilThemeMode.light => AnvilThemeSpec.light,
    AnvilThemeMode.custom =>
      customColors == null
          ? AnvilThemeSpec.dark
          : AnvilThemeSpec.custom(customColors!),
  };

  ThemeData get themeData => anvilTheme(spec);

  ThemeSelection _with({
    AnvilThemeMode? mode,
    String? customPath,
    CustomThemeColors? customColors,
    String? customError,
    bool clearError = false,
  }) => ThemeSelection._(
    mode: mode ?? this.mode,
    customPath: customPath ?? this.customPath,
    customColors: customColors ?? this.customColors,
    customError: clearError ? null : (customError ?? this.customError),
  );

  @override
  bool operator ==(Object other) =>
      other is ThemeSelection &&
      other.mode == mode &&
      other.customPath == customPath &&
      other.customColors == customColors &&
      other.customError == customError;

  @override
  int get hashCode => Object.hash(mode, customPath, customColors, customError);
}

/// Holds the current [ThemeSelection] and switches it. A plain
/// [ValueNotifier] until the app shell (ANVL-148) settles on its state
/// layer; nothing here depends on the choice.
class ThemeController extends ValueNotifier<ThemeSelection> {
  ThemeController([super.initial = const ThemeSelection.dark()]);

  void selectDark() =>
      value = value._with(mode: AnvilThemeMode.dark, clearError: true);

  void selectLight() =>
      value = value._with(mode: AnvilThemeMode.light, clearError: true);

  /// Switches to the loaded custom colours. Does nothing when none have
  /// been loaded yet; use [loadCustomFile] first.
  void selectCustom() {
    if (value.customColors == null) return;
    value = value._with(mode: AnvilThemeMode.custom, clearError: true);
  }

  /// Applies already-validated colours (for example from persisted settings).
  void applyCustom(CustomThemeColors colors, {String? path}) =>
      value = ThemeSelection.custom(colors: colors, path: path);

  /// Reads and validates the theme file at [path]. On success the custom
  /// theme is applied and null is returned; on failure the theme is left as
  /// it was and the message is returned (and kept in `customError`).
  String? loadCustomFile(String path) {
    final result = parseCustomThemeFile(path);
    if (!result.success) {
      value = value._with(customError: result.error);
      return result.error;
    }
    applyCustom(result.colors!, path: path);
    return null;
  }
}
