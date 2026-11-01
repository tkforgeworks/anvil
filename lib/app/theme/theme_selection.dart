import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'anvil_theme.dart';

/// The spec the settings' theme choice resolves to. Custom without colours
/// falls back to dark, as the Electron `main.tsx` did.
AnvilThemeSpec themeSpecFor(AppSettings settings) => switch (settings.theme) {
  AppThemeMode.dark => AnvilThemeSpec.dark,
  AppThemeMode.light => AnvilThemeSpec.light,
  AppThemeMode.custom => switch (settings.customThemeColors) {
    null => AnvilThemeSpec.dark,
    final colors => AnvilThemeSpec.custom(colors),
  },
};

/// The app theme, rebuilt only when the resolved spec changes (not on, say,
/// an editing-mode change).
final themeDataProvider = Provider<ThemeData>(
  (ref) => anvilTheme(ref.watch(appSettingsProvider.select(themeSpecFor))),
);
