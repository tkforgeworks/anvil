import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// Holds the app settings (design §8.1, §14.1). The file is the source of
/// truth: every change goes through [AppSettingsStore.update], which merges
/// over what is on disk, normalises and writes, and the state is set from
/// what the store returns. Each change logs one info line, as 0.1.6 logged
/// "App settings updated". A failed write throws and leaves the state as it
/// was.
class AppSettingsNotifier extends Notifier<AppSettings> {
  /// Watches only the root-overridden value `main()` read before the first
  /// frame, which never changes, so this runs once per container.
  @override
  AppSettings build() => ref.watch(initialAppSettingsProvider);

  AppSettingsStore get _store => ref.read(appSettingsStoreProvider);

  AppLogger get _logger => ref.read(appLoggerProvider);

  /// Switches between Dark, Light and Custom. Custom with no colours loaded
  /// shows dark, as 0.1.x did. Clears a previous theme-file error.
  void setTheme(AppThemeMode mode) {
    ref.read(customThemeErrorProvider.notifier).clear();
    _change('theme', (s) => s.copyWith(theme: mode));
  }

  /// Reads and validates the theme file at [path] with the core parser. On
  /// success the custom theme is applied and stored with its path, and null
  /// is returned. On failure the settings are unchanged, and the parser's
  /// message is returned and held in [customThemeErrorProvider].
  String? setCustomThemeFile(String path) {
    final result = parseCustomThemeFile(path);
    final errors = ref.read(customThemeErrorProvider.notifier);
    if (!result.success) {
      errors._set(result.error);
      // The message can carry the full path, so log only its tail.
      _logger.warn('Custom theme file rejected: ${anonymizePath(path)}');
      return result.error;
    }
    errors.clear();
    _change(
      'custom theme',
      (s) => s.copyWith(
        theme: AppThemeMode.custom,
        customThemePath: path,
        customThemeColors: result.colors,
      ),
    );
    return null;
  }

  void setEditingMode(EditingMode mode) =>
      _change('editing mode', (s) => s.copyWith(editingMode: mode));

  /// The create-project dialog's starting folder; null clears it.
  void setDefaultSaveLocation(String? path) => _change(
    'default save location',
    (s) => path == null
        ? s.copyWith(clearDefaultSaveLocation: true)
        : s.copyWith(defaultSaveLocation: path),
  );

  /// Overrides the binding of the registry entry [id] with [binding], or
  /// removes the override when [binding] is null. A map left empty is
  /// stored as null, as 0.1.6 did.
  void setCustomShortcut(String id, String? binding) =>
      _change('shortcut $id', (s) {
        final next = {...?s.customShortcuts};
        if (binding == null) {
          next.remove(id);
        } else {
          next[id] = binding;
        }
        return next.isEmpty
            ? s.copyWith(clearCustomShortcuts: true)
            : s.copyWith(customShortcuts: next);
      });

  /// Removes every shortcut override (0.1.6's Reset All).
  void clearCustomShortcuts() =>
      _change('shortcuts reset', (s) => s.copyWith(clearCustomShortcuts: true));

  void _change(String what, AppSettings Function(AppSettings) change) {
    state = _store.update(change);
    _logger.info('App settings updated: $what');
  }
}

/// The last rejected theme file's message, shown until the next attempt or
/// theme change; the theme itself is unchanged by a failed load, as in 0.1.x.
final customThemeErrorProvider =
    NotifierProvider<CustomThemeErrorNotifier, String?>(
      CustomThemeErrorNotifier.new,
    );

class CustomThemeErrorNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void _set(String? message) => state = message;

  void clear() => state = null;
}
