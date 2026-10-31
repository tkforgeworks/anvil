import 'package:flutter/material.dart';

/// Colour roles of Anvil's own that neither [ColorScheme] nor `ForgeTokens`
/// has a slot for: the MUI status trio (warning, info, success) that
/// validation severities, status tags and badges use, the disabled text
/// shade, the emphasised primary (MUI `primary.dark`, used for hover and
/// pressed states) and the desktop scrollbar thumb.
///
/// Read it with `context.anvil` (see [AnvilContext]) or [AnvilColors.of].
@immutable
class AnvilColors extends ThemeExtension<AnvilColors> {
  const AnvilColors({
    required this.primaryEmphasis,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.success,
    required this.onSuccess,
    required this.textDisabled,
    required this.scrollbarThumb,
  });

  /// A darker primary for hover and pressed states (MUI `primary.dark`).
  final Color primaryEmphasis;

  /// Warning severity: validation warnings, caution badges.
  final Color warning;
  final Color onWarning;

  /// Tinted fill behind a warning banner; text on it is [onWarningContainer].
  final Color warningContainer;
  final Color onWarningContainer;

  /// Informational highlights.
  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color onInfoContainer;

  /// Success indicators. The tinted container pair lives in
  /// `ForgeTokens.successContainer` / `onSuccessContainer`.
  final Color success;
  final Color onSuccess;

  /// Disabled text and icons (MUI `text.disabled`).
  final Color textDisabled;

  /// The scrollbar thumb. Null keeps the platform default.
  final Color? scrollbarThumb;

  /// The roles of the nearest theme. Throws for a theme not built by
  /// `anvilTheme`, since there is no sensible fallback for these.
  static AnvilColors of(BuildContext context) =>
      Theme.of(context).extension<AnvilColors>()!;

  @override
  AnvilColors copyWith({
    Color? primaryEmphasis,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? onInfoContainer,
    Color? success,
    Color? onSuccess,
    Color? textDisabled,
    Color? scrollbarThumb,
  }) => AnvilColors(
    primaryEmphasis: primaryEmphasis ?? this.primaryEmphasis,
    warning: warning ?? this.warning,
    onWarning: onWarning ?? this.onWarning,
    warningContainer: warningContainer ?? this.warningContainer,
    onWarningContainer: onWarningContainer ?? this.onWarningContainer,
    info: info ?? this.info,
    onInfo: onInfo ?? this.onInfo,
    infoContainer: infoContainer ?? this.infoContainer,
    onInfoContainer: onInfoContainer ?? this.onInfoContainer,
    success: success ?? this.success,
    onSuccess: onSuccess ?? this.onSuccess,
    textDisabled: textDisabled ?? this.textDisabled,
    scrollbarThumb: scrollbarThumb ?? this.scrollbarThumb,
  );

  @override
  AnvilColors lerp(AnvilColors? other, double t) {
    if (other == null) return this;
    return AnvilColors(
      primaryEmphasis: Color.lerp(primaryEmphasis, other.primaryEmphasis, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      scrollbarThumb: Color.lerp(scrollbarThumb, other.scrollbarThumb, t),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AnvilColors &&
      other.primaryEmphasis == primaryEmphasis &&
      other.warning == warning &&
      other.onWarning == onWarning &&
      other.warningContainer == warningContainer &&
      other.onWarningContainer == onWarningContainer &&
      other.info == info &&
      other.onInfo == onInfo &&
      other.infoContainer == infoContainer &&
      other.onInfoContainer == onInfoContainer &&
      other.success == success &&
      other.onSuccess == onSuccess &&
      other.textDisabled == textDisabled &&
      other.scrollbarThumb == scrollbarThumb;

  @override
  int get hashCode => Object.hash(
    primaryEmphasis,
    warning,
    onWarning,
    warningContainer,
    onWarningContainer,
    info,
    onInfo,
    infoContainer,
    onInfoContainer,
    success,
    onSuccess,
    textDisabled,
    scrollbarThumb,
  );
}

/// `context.anvil.warning`. The scheme, text theme and shared roles are
/// `context.colors`, `context.text` and `context.forge`, from `forge_ui`.
extension AnvilContext on BuildContext {
  AnvilColors get anvil => AnvilColors.of(this);
}
