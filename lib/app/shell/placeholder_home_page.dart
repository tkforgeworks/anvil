import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../providers.dart';
import '../theme/anvil_metrics.dart';
import '../theme/theme_gallery_page.dart';

/// The app's home until the welcome page and shell land. It shows the
/// persisted theme switch so the settings path can be exercised, and in
/// debug builds a way into the theme gallery.
class PlaceholderHomePage extends ConsumerWidget {
  const PlaceholderHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final text = context.text;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AnvilSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Anvil', style: text.headlineMedium),
              const SizedBox(height: AnvilSpacing.sm),
              Text(
                'The welcome page and application shell land with '
                'ANVL-184 and ANVL-185.',
                style: text.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AnvilSpacing.lg),
              const ForgeMonoLabel('Theme'),
              const SizedBox(height: AnvilSpacing.sm),
              ThemeModeSelector(settings: settings),
              if (kDebugMode) ...[
                const SizedBox(height: AnvilSpacing.lg),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ThemeGalleryPage(),
                    ),
                  ),
                  child: const Text('Open theme gallery'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Dark / Light / Custom, writing the choice to app settings. Custom is
/// offered once a theme file has been accepted.
class ThemeModeSelector extends ConsumerWidget {
  const ThemeModeSelector({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SegmentedButton<AppThemeMode>(
      segments: [
        const ButtonSegment(value: AppThemeMode.dark, label: Text('Dark')),
        const ButtonSegment(value: AppThemeMode.light, label: Text('Light')),
        ButtonSegment(
          value: AppThemeMode.custom,
          label: const Text('Custom'),
          enabled: settings.customThemeColors != null,
        ),
      ],
      selected: {settings.theme},
      onSelectionChanged: (modes) =>
          ref.read(appSettingsProvider.notifier).setTheme(modes.single),
    );
  }
}
