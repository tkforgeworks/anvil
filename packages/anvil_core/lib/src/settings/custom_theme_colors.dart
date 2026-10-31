import 'dart:convert';
import 'dart:io';

/// The shape of a custom theme JSON file, unchanged from Anvil 0.1.x
/// (`CustomThemeColors` in the Electron app's `settings-types.ts`): an
/// optional base mode plus eleven optional colour keys. Colours are kept as
/// the `#RRGGBB` / `#RRGGBBAA` strings the file holds; the app layer turns
/// them into `Color`s. Any key the file omits falls back to the base mode's
/// default when the theme is built.
class CustomThemeColors {
  const CustomThemeColors({
    this.mode,
    this.primary,
    this.secondary,
    this.backgroundDefault,
    this.backgroundPaper,
    this.textPrimary,
    this.textSecondary,
    this.error,
    this.warning,
    this.info,
    this.success,
    this.divider,
  });

  /// `'dark'` or `'light'`; the palette that fills in omitted keys.
  final String? mode;
  final String? primary;
  final String? secondary;
  final String? backgroundDefault;
  final String? backgroundPaper;
  final String? textPrimary;
  final String? textSecondary;
  final String? error;
  final String? warning;
  final String? info;
  final String? success;
  final String? divider;

  /// The colour keys, in the order the 0.1.x app lists them.
  static const colorKeys = [
    'primary',
    'secondary',
    'backgroundDefault',
    'backgroundPaper',
    'textPrimary',
    'textSecondary',
    'error',
    'warning',
    'info',
    'success',
    'divider',
  ];

  /// Every key a theme file may contain.
  static const validKeys = ['mode', ...colorKeys];

  /// `#RRGGBB` or `#RRGGBBAA`, as the 0.1.x validator accepts.
  static final hexColorPattern = RegExp(r'^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$');

  /// Whether [value] is a colour string the file format accepts.
  static bool isValidHex(Object? value) =>
      value is String && hexColorPattern.hasMatch(value);

  /// The value of a colour key by name, or null.
  String? operator [](String key) => switch (key) {
    'primary' => primary,
    'secondary' => secondary,
    'backgroundDefault' => backgroundDefault,
    'backgroundPaper' => backgroundPaper,
    'textPrimary' => textPrimary,
    'textSecondary' => textSecondary,
    'error' => error,
    'warning' => warning,
    'info' => info,
    'success' => success,
    'divider' => divider,
    _ => null,
  };

  /// Whether any field is set.
  bool get isEmpty => mode == null && colorKeys.every((k) => this[k] == null);

  /// The lenient normalisation the 0.1.x settings store applies when it
  /// reads persisted settings: keeps a valid `mode` and every valid colour,
  /// drops everything else, and returns null when nothing valid is left.
  static CustomThemeColors? normalize(Object? raw) {
    if (raw is! Map) return null;
    String? mode;
    if (raw['mode'] == 'dark' || raw['mode'] == 'light') {
      mode = raw['mode'] as String;
    }
    String? pick(String key) {
      final value = raw[key];
      return isValidHex(value) ? value as String : null;
    }

    final colors = CustomThemeColors(
      mode: mode,
      primary: pick('primary'),
      secondary: pick('secondary'),
      backgroundDefault: pick('backgroundDefault'),
      backgroundPaper: pick('backgroundPaper'),
      textPrimary: pick('textPrimary'),
      textSecondary: pick('textSecondary'),
      error: pick('error'),
      warning: pick('warning'),
      info: pick('info'),
      success: pick('success'),
      divider: pick('divider'),
    );
    return colors.isEmpty ? null : colors;
  }

  Map<String, String> toJson() => {
    'mode': ?mode,
    for (final key in colorKeys)
      if (this[key] != null) key: this[key]!,
  };

  @override
  bool operator ==(Object other) =>
      other is CustomThemeColors &&
      other.mode == mode &&
      colorKeys.every((k) => other[k] == this[k]);

  @override
  int get hashCode =>
      Object.hashAll([mode, for (final k in colorKeys) this[k]]);

  @override
  String toString() => 'CustomThemeColors(${toJson()})';
}

/// What reading a theme file produced: either [colors] or an [error]
/// message for the user. Never both.
class CustomThemeParseResult {
  const CustomThemeParseResult.success(CustomThemeColors this.colors)
    : error = null;

  const CustomThemeParseResult.failure(String this.error) : colors = null;

  final CustomThemeColors? colors;
  final String? error;

  bool get success => colors != null;
}

/// Reads and validates a custom theme file at [path].
///
/// The checks and messages are those of the 0.1.x
/// `parseCustomThemeFile` in `app-settings-service.ts`, in the same order,
/// so a file that worked (or failed) in Anvil 0.1.6 behaves the same here.
CustomThemeParseResult parseCustomThemeFile(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    return CustomThemeParseResult.failure('File not found: $path');
  }
  final String source;
  try {
    source = file.readAsStringSync();
  } on FileSystemException catch (e) {
    return CustomThemeParseResult.failure(
      'Invalid JSON: ${e.osError?.message ?? e.message}',
    );
  }
  return parseCustomThemeSource(source);
}

/// Validates the JSON text of a custom theme file. See [parseCustomThemeFile].
CustomThemeParseResult parseCustomThemeSource(String source) {
  final Object? raw;
  try {
    raw = jsonDecode(source);
  } on FormatException catch (e) {
    return CustomThemeParseResult.failure('Invalid JSON: ${e.message}');
  }
  // JavaScript's `typeof` calls an array an object, so 0.1.x let a JSON
  // array through to the "no valid color values" check. Same here.
  if (raw is List) {
    return const CustomThemeParseResult.failure(
      'Theme file has no valid color values.',
    );
  }
  if (raw is! Map) {
    return const CustomThemeParseResult.failure(
      'Theme file must contain a JSON object.',
    );
  }
  final invalidKeys = raw.keys
      .map((k) => k.toString())
      .where((k) => !CustomThemeColors.validKeys.contains(k))
      .toList();
  if (invalidKeys.isNotEmpty) {
    return CustomThemeParseResult.failure(
      'Unknown keys: ${invalidKeys.join(', ')}. '
      'Valid keys: ${CustomThemeColors.validKeys.join(', ')}',
    );
  }
  for (final entry in raw.entries) {
    final key = entry.key.toString();
    final value = entry.value;
    if (key == 'mode') {
      if (value != 'dark' && value != 'light') {
        return CustomThemeParseResult.failure(
          '"mode" must be "dark" or "light", got "${_jsString(value)}".',
        );
      }
      continue;
    }
    if (!CustomThemeColors.isValidHex(value)) {
      return CustomThemeParseResult.failure(
        '"$key" must be a hex color (#RRGGBB or #RRGGBBAA), '
        'got "${_jsString(value)}".',
      );
    }
  }
  final colors = CustomThemeColors.normalize(raw);
  if (colors == null) {
    return const CustomThemeParseResult.failure(
      'Theme file has no valid color values.',
    );
  }
  return CustomThemeParseResult.success(colors);
}

/// How JavaScript's `String(value)` prints a decoded JSON value, so the
/// error messages quote offending values the way 0.1.x did.
String _jsString(Object? value) => switch (value) {
  null => 'null',
  String s => s,
  bool b => b.toString(),
  int i => i.toString(),
  double d when d == d.truncateToDouble() && d.abs() < 1e21 =>
    d.toInt().toString(),
  double d => d.toString(),
  List l => l.map(_jsString).join(','),
  Map _ => '[object Object]',
  _ => value.toString(),
};
