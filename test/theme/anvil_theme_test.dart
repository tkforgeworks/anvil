import 'dart:io';

import 'package:anvil/app/theme/anvil_colors.dart';
import 'package:anvil/app/theme/anvil_metrics.dart';
import 'package:anvil/app/theme/anvil_theme.dart';
import 'package:anvil/app/theme/color_math.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge_ui/forge_ui.dart';

/// The sample file the 0.1.x settings dialog offered users to copy.
const sampleTheme = '''{
  "mode": "dark",
  "primary": "#bb86fc",
  "secondary": "#03dac6",
  "backgroundDefault": "#121212",
  "backgroundPaper": "#1e1e1e",
  "textPrimary": "#e0e0e0",
  "textSecondary": "#a0a0a0",
  "error": "#cf6679",
  "warning": "#ffb74d",
  "info": "#64b5f6",
  "success": "#81c784",
  "divider": "#333333"
}''';

/// Anvil Dark written out as a theme file: the values of `themes/dark.ts`
/// plus the MUI dark defaults it inherited.
const darkAsFile = '''{
  "mode": "dark",
  "primary": "#3b82f6",
  "secondary": "#60a5fa",
  "backgroundDefault": "#0f172a",
  "backgroundPaper": "#1e293b",
  "textPrimary": "#ffffff",
  "textSecondary": "#ffffffb3",
  "error": "#f44336",
  "warning": "#ffa726",
  "info": "#29b6f6",
  "success": "#66bb6a",
  "divider": "#ffffff1f"
}''';

void main() {
  group('Anvil Dark', () {
    final t = anvilTheme(AnvilThemeSpec.dark);
    final c = t.colorScheme;
    final anvil = t.extension<AnvilColors>()!;
    final x = t.extension<ForgeTokens>()!;

    test('carries the Electron dark palette', () {
      expect(c.brightness, Brightness.dark);
      expect(c.primary, const Color(0xFF3B82F6));
      expect(c.secondary, const Color(0xFF60A5FA));
      expect(c.surface, const Color(0xFF0F172A)); // background.default
      expect(t.scaffoldBackgroundColor, const Color(0xFF0F172A));
      expect(c.surfaceContainerLowest, const Color(0xFF1E293B)); // paper
      expect(t.cardTheme.color, const Color(0xFF1E293B));
      expect(t.appBarTheme.backgroundColor, const Color(0xFF1E293B));
      expect(c.onSurface, const Color(0xFFFFFFFF));
      expect(c.onSurfaceVariant, const Color(0xB3FFFFFF));
      expect(c.outline, const Color(0x1FFFFFFF));
      expect(t.dividerTheme.color, const Color(0x1FFFFFFF));
      expect(c.error, const Color(0xFFF44336));
      expect(anvil.primaryEmphasis, const Color(0xFF2563EB));
      expect(anvil.warning, const Color(0xFFFFA726));
      expect(anvil.info, const Color(0xFF29B6F6));
      expect(anvil.success, const Color(0xFF66BB6A));
      expect(anvil.textDisabled, const Color(0x80FFFFFF));
    });

    test('tokens follow the palette', () {
      expect(x.link, c.primary);
      expect(x.accent, c.secondary);
      expect(x.textTertiary, c.onSurfaceVariant);
      expect(x.textGhost, anvil.textDisabled);
      expect(x.rowDivider, c.outline);
      expect(x.onSuccessContainer, anvil.success);
    });

    test('contrast text follows MUI: white on blue, dark on amber', () {
      expect(c.onPrimary, const Color(0xFFFFFFFF));
      expect(c.onError, const Color(0xFFFFFFFF));
      expect(anvil.onWarning, const Color(0xDE000000));
    });

    test('styles the scrollbar thumb like the Electron dark theme', () {
      expect(t.scrollbarTheme.thumbColor!.resolve({}), const Color(0xFF6B6B6B));
    });
  });

  group('Anvil Light', () {
    final t = anvilTheme(AnvilThemeSpec.light);
    final c = t.colorScheme;
    final anvil = t.extension<AnvilColors>()!;

    test('carries the Electron light palette', () {
      expect(c.brightness, Brightness.light);
      expect(c.primary, const Color(0xFF2563EB));
      expect(c.secondary, const Color(0xFF3B82F6));
      expect(c.surface, const Color(0xFFF8FAFC));
      expect(c.surfaceContainerLowest, const Color(0xFFFFFFFF));
      expect(c.onSurface, const Color(0xDE000000));
      expect(c.onSurfaceVariant, const Color(0x99000000));
      expect(c.outline, const Color(0x1F000000));
      expect(c.error, const Color(0xFFD32F2F));
      expect(anvil.primaryEmphasis, const Color(0xFF1D4ED8));
      expect(anvil.warning, const Color(0xFFED6C02));
      expect(anvil.info, const Color(0xFF0288D1));
      expect(anvil.success, const Color(0xFF2E7D32));
      expect(anvil.textDisabled, const Color(0x61000000));
    });

    test('leaves the scrollbar to the platform', () {
      expect(t.scrollbarTheme.thumbColor, isNull);
      expect(anvil.scrollbarThumb, isNull);
    });

    test('darkens intent text on light containers', () {
      expect(anvil.onWarningContainer, isNot(anvil.warning));
      expect(
        anvil.onWarningContainer.computeLuminance(),
        lessThan(anvil.warning.computeLuminance()),
      );
    });
  });

  group('fonts', () {
    final t = anvilTheme(AnvilThemeSpec.dark);

    test('come from forge_ui', () {
      expect(t.textTheme.bodyMedium!.fontFamily, 'packages/forge_ui/Poppins');
      expect(
        t.textTheme.labelSmall!.fontFamily,
        'packages/forge_ui/JetBrains Mono',
      );
      expect(AnvilType.code().fontFamily, 'packages/forge_ui/JetBrains Mono');
      expect(AnvilType.code().letterSpacing, 0);
      expect(AnvilType.numeric().fontFeatures, isNotEmpty);
    });

    test('the app declares none of its own', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, isNot(contains('google_fonts')));
      expect(RegExp(r'^\s+fonts:', multiLine: true).hasMatch(pubspec), isFalse);
    });
  });

  group('custom theme files', () {
    test('a mode alone is that built-in theme', () {
      expect(
        AnvilThemeSpec.custom(const CustomThemeColors(mode: 'light')),
        AnvilThemeSpec.light,
      );
      expect(
        AnvilThemeSpec.custom(const CustomThemeColors(mode: 'dark')),
        AnvilThemeSpec.dark,
      );
    });

    test('no mode means dark, as in 0.1.x', () {
      final spec = AnvilThemeSpec.custom(
        const CustomThemeColors(primary: '#ff0000'),
      );
      expect(spec.brightness, Brightness.dark);
      expect(spec.backgroundDefault, AnvilThemeSpec.dark.backgroundDefault);
      expect(spec.primary, const Color(0xFFFF0000));
    });

    test('a file repeating the dark defaults renders the dark theme', () {
      final colors = parseCustomThemeSource(darkAsFile).colors!;
      final custom = anvilTheme(AnvilThemeSpec.custom(colors));
      final dark = anvilTheme(AnvilThemeSpec.dark);
      expect(custom.colorScheme, dark.colorScheme);
      final cx = custom.extension<ForgeTokens>()!;
      final dx = dark.extension<ForgeTokens>()!;
      expect(cx.link, dx.link);
      expect(cx.textGhost, dx.textGhost);
      expect(cx.successContainer, dx.successContainer);
      final ca = custom.extension<AnvilColors>()!;
      final da = dark.extension<AnvilColors>()!;
      expect(ca.copyWith(primaryEmphasis: da.primaryEmphasis), da);
      expect(
        custom.scrollbarTheme.thumbColor!.resolve({}),
        const Color(0xFF6B6B6B),
      );
    });

    test('the documented sample maps every key', () {
      final colors = parseCustomThemeSource(sampleTheme).colors!;
      final t = anvilTheme(AnvilThemeSpec.custom(colors));
      final c = t.colorScheme;
      final anvil = t.extension<AnvilColors>()!;
      expect(c.brightness, Brightness.dark);
      expect(c.primary, const Color(0xFFBB86FC));
      expect(c.secondary, const Color(0xFF03DAC6));
      expect(c.surface, const Color(0xFF121212));
      expect(c.surfaceContainerLowest, const Color(0xFF1E1E1E));
      expect(c.onSurface, const Color(0xFFE0E0E0));
      expect(c.onSurfaceVariant, const Color(0xFFA0A0A0));
      expect(c.error, const Color(0xFFCF6679));
      expect(c.outline, const Color(0xFF333333));
      expect(anvil.warning, const Color(0xFFFFB74D));
      expect(anvil.info, const Color(0xFF64B5F6));
      expect(anvil.success, const Color(0xFF81C784));
      // Not settable from a file: derived like MUI's primary.dark,
      // `darken('#bb86fc', 0.3)` with MUI's channel truncation.
      expect(anvil.primaryEmphasis, const Color(0xFF825DB0));
      expect(t.textTheme.bodyMedium!.color, const Color(0xFFE0E0E0));
    });

    test('hex parsing handles the alpha form', () {
      expect(hexToColor('#3b82f6'), const Color(0xFF3B82F6));
      expect(hexToColor('#FFFFFF1F'), const Color(0x1FFFFFFF));
    });

    test('darken truncates channels like MUI', () {
      expect(darken(const Color(0xFFBB86FC), 0.3), const Color(0xFF825DB0));
      expect(darken(const Color(0x80FFFFFF), 0.5), const Color(0x807F7F7F));
    });
  });

  group('AnvilColors', () {
    final a = anvilTheme(AnvilThemeSpec.dark).extension<AnvilColors>()!;
    final b = anvilTheme(AnvilThemeSpec.light).extension<AnvilColors>()!;

    test('lerp moves between themes', () {
      expect(a.lerp(b, 0), a);
      expect(a.lerp(b, 1).warning, b.warning);
      expect(a.lerp(null, 0.5), a);
    });

    test('copyWith replaces only what is passed', () {
      final copy = a.copyWith(info: b.info);
      expect(copy.info, b.info);
      expect(copy.warning, a.warning);
    });
  });
}
