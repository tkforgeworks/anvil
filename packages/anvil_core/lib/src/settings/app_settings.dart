import 'custom_theme_colors.dart';

/// The theme choice, stored as `dark`, `light` or `custom`.
enum AppThemeMode {
  dark('dark'),
  light('light'),
  custom('custom');

  const AppThemeMode(this.json);

  /// The string 0.1.x writes to `app-settings.json`.
  final String json;
}

/// How records open from a list: in a dialog or on their own page.
enum EditingMode {
  modal('modal'),
  fullPage('full-page');

  const EditingMode(this.json);

  /// The string 0.1.x writes to `app-settings.json`.
  final String json;
}

/// Application-level settings, the contents of `app-settings.json`.
///
/// Same keys and normalisation as 0.1.6 (`app-settings-service.ts`): an
/// unknown or wrong-typed value falls back to its default.
class AppSettings {
  const AppSettings({
    this.theme = AppThemeMode.dark,
    this.editingMode = EditingMode.modal,
    this.autoSaveEnabled = true,
    this.autoSaveIntervalMs = defaultAutoSaveIntervalMs,
    this.defaultSaveLocation,
    this.customThemePath,
    this.customThemeColors,
    this.customShortcuts,
  });

  static const defaultAutoSaveIntervalMs = 5000;
  static const minAutoSaveIntervalMs = 1000;

  final AppThemeMode theme;
  final EditingMode editingMode;

  /// Preserved from 0.1.x files and written back unchanged; 0.2.0 has no
  /// project-level auto-save, so nothing reads it.
  final bool autoSaveEnabled;

  /// Preserved like [autoSaveEnabled]; unused in 0.2.0. Minimum 1000.
  final int autoSaveIntervalMs;

  /// The create-project dialog's starting folder.
  final String? defaultSaveLocation;
  final String? customThemePath;
  final CustomThemeColors? customThemeColors;

  /// Per-shortcut overrides, by shortcut id.
  final Map<String, String>? customShortcuts;

  /// Builds settings from decoded JSON, reproducing 0.1.6's
  /// `normalizeSettings`. Any value that is missing or of the wrong type
  /// takes its default. A bad hex colour drops only that colour; the theme
  /// colours object is dropped (null) when nothing valid is left.
  factory AppSettings.normalize(Map<dynamic, dynamic> json) {
    final interval = json['autoSaveIntervalMs'];
    final location = json['defaultSaveLocation'];
    final themePath = json['customThemePath'];
    return AppSettings(
      theme: switch (json['theme']) {
        'light' => AppThemeMode.light,
        'custom' => AppThemeMode.custom,
        _ => AppThemeMode.dark,
      },
      editingMode: json['editingMode'] == 'full-page'
          ? EditingMode.fullPage
          : EditingMode.modal,
      autoSaveEnabled: json['autoSaveEnabled'] is bool
          ? json['autoSaveEnabled'] as bool
          : true,
      autoSaveIntervalMs: interval is num && interval.isFinite
          ? interval.truncate() < minAutoSaveIntervalMs
                ? minAutoSaveIntervalMs
                : interval.truncate()
          : defaultAutoSaveIntervalMs,
      defaultSaveLocation: location is String && location.isNotEmpty
          ? location
          : null,
      customThemePath: themePath is String && themePath.isNotEmpty
          ? themePath
          : null,
      customThemeColors: CustomThemeColors.normalize(json['customThemeColors']),
      customShortcuts: _normalizeShortcuts(json['customShortcuts']),
    );
  }

  factory AppSettings.fromJson(Map<dynamic, dynamic> json) =>
      AppSettings.normalize(json);

  static Map<String, String>? _normalizeShortcuts(Object? raw) {
    if (raw is! Map) return null;
    final result = <String, String>{
      for (final e in raw.entries)
        if (e.key is String &&
            e.value is String &&
            (e.value as String).isNotEmpty)
          e.key as String: e.value as String,
    };
    return result.isEmpty ? null : result;
  }

  /// Keys in the order 0.1.6 writes them.
  Map<String, Object?> toJson() => {
    'theme': theme.json,
    'editingMode': editingMode.json,
    'autoSaveEnabled': autoSaveEnabled,
    'autoSaveIntervalMs': autoSaveIntervalMs,
    'defaultSaveLocation': defaultSaveLocation,
    'customThemePath': customThemePath,
    'customThemeColors': customThemeColors?.toJson(),
    'customShortcuts': customShortcuts,
  };

  /// A copy with the given fields replaced. A nullable field cannot be set
  /// to null by passing null; use its `clear...` flag.
  AppSettings copyWith({
    AppThemeMode? theme,
    EditingMode? editingMode,
    bool? autoSaveEnabled,
    int? autoSaveIntervalMs,
    String? defaultSaveLocation,
    bool clearDefaultSaveLocation = false,
    String? customThemePath,
    bool clearCustomThemePath = false,
    CustomThemeColors? customThemeColors,
    bool clearCustomThemeColors = false,
    Map<String, String>? customShortcuts,
    bool clearCustomShortcuts = false,
  }) => AppSettings(
    theme: theme ?? this.theme,
    editingMode: editingMode ?? this.editingMode,
    autoSaveEnabled: autoSaveEnabled ?? this.autoSaveEnabled,
    autoSaveIntervalMs: autoSaveIntervalMs ?? this.autoSaveIntervalMs,
    defaultSaveLocation: clearDefaultSaveLocation
        ? null
        : defaultSaveLocation ?? this.defaultSaveLocation,
    customThemePath: clearCustomThemePath
        ? null
        : customThemePath ?? this.customThemePath,
    customThemeColors: clearCustomThemeColors
        ? null
        : customThemeColors ?? this.customThemeColors,
    customShortcuts: clearCustomShortcuts
        ? null
        : customShortcuts ?? this.customShortcuts,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.theme == theme &&
      other.editingMode == editingMode &&
      other.autoSaveEnabled == autoSaveEnabled &&
      other.autoSaveIntervalMs == autoSaveIntervalMs &&
      other.defaultSaveLocation == defaultSaveLocation &&
      other.customThemePath == customThemePath &&
      other.customThemeColors == customThemeColors &&
      _shortcutsEqual(other.customShortcuts, customShortcuts);

  static bool _shortcutsEqual(Map<String, String>? a, Map<String, String>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    return a.entries.every((e) => b[e.key] == e.value);
  }

  @override
  int get hashCode => Object.hash(
    theme,
    editingMode,
    autoSaveEnabled,
    autoSaveIntervalMs,
    defaultSaveLocation,
    customThemePath,
    customThemeColors,
    customShortcuts == null
        ? null
        : Object.hashAllUnordered(
            customShortcuts!.entries.map((e) => Object.hash(e.key, e.value)),
          ),
  );

  @override
  String toString() => 'AppSettings(${toJson()})';
}
