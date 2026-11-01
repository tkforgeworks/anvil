import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

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
