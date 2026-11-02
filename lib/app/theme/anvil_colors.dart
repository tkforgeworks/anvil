import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

/// Colour roles of Anvil's own that neither [ColorScheme] nor `ForgeTokens`
/// has a slot for: the emphasised primary (MUI `primary.dark`, used for
/// hover and pressed states), the disabled text shade and the chart series
/// colours (0.1.6 `STAT_COLORS`). The status trio
/// (warning, info, success) and the scrollbar are `ForgeTokens` roles since
/// forge_ui 0.2.2 and are read through `context.forge`.
///
/// Read it with `context.anvil` (see [AnvilContext]) or [AnvilColors.of].
@immutable
class AnvilColors extends ThemeExtension<AnvilColors> {
  const AnvilColors({
    required this.primaryEmphasis,
    required this.textDisabled,
    required this.chartSeries,
  });

  /// A darker primary for hover and pressed states (MUI `primary.dark`).
  final Color primaryEmphasis;

  /// Disabled text and icons (MUI `text.disabled`).
  final Color textDisabled;

  /// The colours of a chart's series, in order: series `i` uses
  /// `chartSeries[i % chartSeries.length]` ([seriesColor]).
  final List<Color> chartSeries;

  /// The colour of series [index]; the primary emphasis when the theme
  /// defines no series colours.
  Color seriesColor(int index) => chartSeries.isEmpty
      ? primaryEmphasis
      : chartSeries[index % chartSeries.length];

  /// The roles of the nearest theme. Throws for a theme not built by
  /// `anvilTheme`, since there is no sensible fallback for these.
  static AnvilColors of(BuildContext context) =>
      Theme.of(context).extension<AnvilColors>()!;

  @override
  AnvilColors copyWith({
    Color? primaryEmphasis,
    Color? textDisabled,
    List<Color>? chartSeries,
  }) => AnvilColors(
    primaryEmphasis: primaryEmphasis ?? this.primaryEmphasis,
    textDisabled: textDisabled ?? this.textDisabled,
    chartSeries: chartSeries ?? this.chartSeries,
  );

  @override
  AnvilColors lerp(AnvilColors? other, double t) {
    if (other == null) return this;
    return AnvilColors(
      primaryEmphasis: Color.lerp(primaryEmphasis, other.primaryEmphasis, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      chartSeries: _lerpSeries(chartSeries, other.chartSeries, t),
    );
  }

  /// Element-wise; lists of different lengths cannot be blended, so the
  /// result switches from [a] to [b] at `t = 0.5`.
  static List<Color> _lerpSeries(List<Color> a, List<Color> b, double t) {
    if (a.length != b.length) return t < 0.5 ? a : b;
    return [for (var i = 0; i < a.length; i++) Color.lerp(a[i], b[i], t)!];
  }

  @override
  bool operator ==(Object other) =>
      other is AnvilColors &&
      other.primaryEmphasis == primaryEmphasis &&
      other.textDisabled == textDisabled &&
      listEquals(other.chartSeries, chartSeries);

  @override
  int get hashCode =>
      Object.hash(primaryEmphasis, textDisabled, Object.hashAll(chartSeries));
}

/// `context.anvil.primaryEmphasis`. The scheme, text theme and shared roles
/// (including warning, info and success) are `context.colors`,
/// `context.text` and `context.forge`, from `forge_ui`.
extension AnvilContext on BuildContext {
  AnvilColors get anvil => AnvilColors.of(this);
}
