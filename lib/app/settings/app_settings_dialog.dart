/// The Application Settings dialog (design §13.5, §14.1): 0.1.6's
/// `AppSettingsModal.tsx` with its four tabs, General, Appearance, Editor
/// and Shortcuts. Every control writes through [AppSettingsNotifier] at
/// once, as 0.1.6 applied each change immediately; there is no Save
/// button. The auto-save controls 0.1.6 had on General are gone, since
/// 0.2.0 has no project-level auto-save.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../dialogs/file_dialogs.dart';
import '../providers.dart';
import '../theme/anvil_metrics.dart';
import 'app_settings_notifier.dart';
import 'shortcut_overrides_section.dart';

/// The dialog's tabs, in 0.1.6's order.
enum AppSettingsTab { general, appearance, editor, shortcuts }

/// Opens the dialog and completes when it closes. Needs no project, so it
/// works from the welcome page as from the shell. A theme-file message
/// left from an earlier attempt is cleared first, as 0.1.6 reset it on
/// open.
Future<void> showAppSettingsDialog(
  BuildContext context,
  WidgetRef ref, {
  AppSettingsTab initialTab = AppSettingsTab.general,
}) {
  ref.read(customThemeErrorProvider.notifier).clear();
  return showDialog<void>(
    context: context,
    builder: (_) => AppSettingsDialog(initialTab: initialTab),
  );
}

/// The dialog itself; Escape, the close button and a click outside close
/// it, and nothing is pending when they do.
class AppSettingsDialog extends StatelessWidget {
  const AppSettingsDialog({
    super.key,
    this.initialTab = AppSettingsTab.general,
  });

  /// MUI `maxWidth="sm"` with `fullWidth`, as 0.1.6 opened it.
  static const width = 600.0;

  /// The tallest the dialog grows; the Shortcuts tab scrolls inside it.
  static const maxHeight = 720.0;

  /// 0.1.6's `maxWidth: 500` for the General, Appearance and Editor tabs.
  static const contentMaxWidth = 500.0;

  final AppSettingsTab initialTab;

  @override
  Widget build(BuildContext context) {
    final height = math.min(
      MediaQuery.sizeOf(context).height * 0.85,
      maxHeight,
    );
    return Dialog(
      insetPadding: const EdgeInsets.all(AnvilSpacing.xl),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: width,
        height: height,
        child: DefaultTabController(
          length: AppSettingsTab.values.length,
          initialIndex: initialTab.index,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AnvilSpacing.lg,
                  AnvilSpacing.sm,
                  AnvilSpacing.sm,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Application Settings',
                        style: context.text.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: EdgeInsets.symmetric(horizontal: AnvilSpacing.md),
                tabs: [
                  Tab(text: 'General'),
                  Tab(text: 'Appearance'),
                  Tab(text: 'Editor'),
                  Tab(text: 'Shortcuts'),
                ],
              ),
              const Divider(height: 1),
              const Expanded(
                child: TabBarView(
                  physics: NeverScrollableScrollPhysics(),
                  children: [
                    _TabScroll(narrow: true, child: _GeneralTab()),
                    _TabScroll(narrow: true, child: _AppearanceTab()),
                    _TabScroll(narrow: true, child: _EditorTab()),
                    _TabScroll(child: ShortcutOverridesSection()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabScroll extends StatelessWidget {
  const _TabScroll({required this.child, this.narrow = false});

  final Widget child;
  final bool narrow;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(AnvilSpacing.lg),
    child: Align(
      alignment: Alignment.topLeft,
      child: narrow
          ? ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSettingsDialog.contentMaxWidth,
              ),
              child: child,
            )
          : child,
    ),
  );
}

/// A setting's heading (MUI `subtitle2` with `gutterBottom`).
class _SettingLabel extends StatelessWidget {
  const _SettingLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AnvilSpacing.sm),
    child: Text(text, style: context.text.titleSmall),
  );
}

TextStyle? _secondary(BuildContext context) =>
    context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant);

class _GeneralTab extends ConsumerWidget {
  const _GeneralTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(
      appSettingsProvider.select((s) => s.defaultSaveLocation),
    );
    final notifier = ref.read(appSettingsProvider.notifier);

    Future<void> browse() async {
      final folder = await ref
          .read(fileDialogsProvider)
          .pickDirectory(initialDirectory: location);
      if (folder != null) notifier.setDefaultSaveLocation(folder);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SettingLabel('Default Save Location'),
        Row(
          children: [
            Expanded(
              child: Text(
                location ?? 'Not set — uses system default',
                key: const ValueKey('settings-default-save-location'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ForgeType.code(
                  size: 13,
                  color: location == null
                      ? context.colors.onSurfaceVariant
                      : context.colors.onSurface,
                ),
              ),
            ),
            const SizedBox(width: AnvilSpacing.sm),
            OutlinedButton.icon(
              key: const ValueKey('settings-browse-folder'),
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('Browse'),
              onPressed: browse,
            ),
            if (location != null) ...[
              const SizedBox(width: AnvilSpacing.sm),
              TextButton(
                key: const ValueKey('settings-clear-folder'),
                onPressed: () => notifier.setDefaultSaveLocation(null),
                child: const Text('Clear'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _AppearanceTab extends ConsumerWidget {
  const _AppearanceTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appSettingsProvider.select((s) => s.theme));
    final path = ref.watch(
      appSettingsProvider.select((s) => s.customThemePath),
    );
    final error = ref.watch(customThemeErrorProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    Future<void> selectFile() async {
      ref.read(customThemeErrorProvider.notifier).clear();
      final file = await ref.read(fileDialogsProvider).pickThemeFile();
      if (file != null) notifier.setCustomThemeFile(file);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SettingLabel('UI Theme'),
        RadioGroup<AppThemeMode>(
          groupValue: theme,
          onChanged: (mode) {
            if (mode != null) notifier.setTheme(mode);
          },
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RadioListTile<AppThemeMode>(
                key: ValueKey('settings-theme-dark'),
                value: AppThemeMode.dark,
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('Dark'),
              ),
              RadioListTile<AppThemeMode>(
                key: ValueKey('settings-theme-light'),
                value: AppThemeMode.light,
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('Light'),
              ),
              RadioListTile<AppThemeMode>(
                key: ValueKey('settings-theme-custom'),
                value: AppThemeMode.custom,
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('Custom'),
              ),
            ],
          ),
        ),
        if (theme == AppThemeMode.custom)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.only(left: AnvilSpacing.sm),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: context.colors.outlineVariant,
                  width: 2,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('settings-theme-file'),
                  icon: const Icon(Icons.upload, size: 18),
                  label: Text(
                    path == null ? 'Select Theme File' : 'Change Theme File',
                  ),
                  onPressed: selectFile,
                ),
                if (path != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AnvilSpacing.xs),
                    child: Text(
                      path,
                      key: const ValueKey('settings-theme-path'),
                      style: ForgeType.code(
                        size: 12,
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AnvilSpacing.sm),
                    child: ForgeErrorCard(
                      key: const ValueKey('settings-theme-error'),
                      message: error,
                    ),
                  ),
                const SizedBox(height: 12),
                const _CustomThemeGuide(),
              ],
            ),
          ),
      ],
    );
  }
}

/// 0.1.6's `SAMPLE_THEME`.
const sampleThemeFile = '''{
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

/// 0.1.6's `THEME_KEY_DESCRIPTIONS`.
const _themeKeyDescriptions = [
  ('mode', '"dark" or "light" — base palette that fills in any keys you omit'),
  ('primary', 'Main accent color (buttons, links, active indicators)'),
  ('secondary', 'Secondary accent (less prominent highlights)'),
  ('backgroundDefault', 'Page background'),
  ('backgroundPaper', 'Cards, dialogs, and elevated surfaces'),
  ('textPrimary', 'Main body text'),
  ('textSecondary', 'Muted / helper text'),
  ('error', 'Error indicators and destructive actions'),
  ('warning', 'Warning banners and badges'),
  ('info', 'Informational highlights'),
  ('success', 'Success indicators'),
  ('divider', 'Lines between sections'),
];

/// The collapsible theme file reference with the copyable sample (0.1.6
/// `CustomThemeGuide`).
class _CustomThemeGuide extends StatefulWidget {
  const _CustomThemeGuide();

  @override
  State<_CustomThemeGuide> createState() => _CustomThemeGuideState();
}

class _CustomThemeGuideState extends State<_CustomThemeGuide> {
  var _copied = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(const ClipboardData(text: sampleThemeFile));
    if (!mounted) return;
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final caption = _secondary(context);
    final code = ForgeType.code(size: 12, color: colors.onSurface);
    final shape = RoundedRectangleBorder(
      side: BorderSide(color: colors.outlineVariant),
      borderRadius: BorderRadius.circular(AnvilRadii.control),
    );
    return ExpansionTile(
      key: const ValueKey('settings-theme-guide'),
      shape: shape,
      collapsedShape: shape,
      dense: true,
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      title: Text(
        'Theme file reference & sample',
        style: context.text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      children: [
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Create a '),
              TextSpan(text: '.json', style: code),
              const TextSpan(
                text:
                    ' file with any combination of the keys below. All color '
                    'values must be hex format (',
              ),
              TextSpan(text: '#RRGGBB', style: code),
              const TextSpan(text: ' or '),
              TextSpan(text: '#RRGGBBAA', style: code),
              const TextSpan(
                text:
                    '). Any key you omit will use the default from the '
                    'chosen ',
              ),
              const TextSpan(
                text: 'mode',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const TextSpan(text: '.'),
            ],
          ),
          style: caption,
        ),
        const SizedBox(height: 12),
        for (final (key, description) in _themeKeyDescriptions)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 140,
                  child: Text(
                    key,
                    style: code.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: AnvilSpacing.sm),
                Expanded(child: Text(description, style: caption)),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Text(
          'Sample theme (Material Dark variant)',
          style: context.text.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AnvilSpacing.xs),
        Stack(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border.all(color: colors.outlineVariant),
                borderRadius: BorderRadius.circular(AnvilRadii.control),
              ),
              child: SelectableText(sampleThemeFile, style: code),
            ),
            Positioned(
              top: AnvilSpacing.sm,
              right: AnvilSpacing.sm,
              child: Tooltip(
                message: _copied ? 'Copied!' : 'Copy to clipboard',
                child: OutlinedButton.icon(
                  key: const ValueKey('settings-theme-copy'),
                  icon: const Icon(Icons.content_copy, size: 14),
                  label: Text(_copied ? 'Copied' : 'Copy'),
                  onPressed: _copy,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EditorTab extends ConsumerWidget {
  const _EditorTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appSettingsProvider.select((s) => s.editingMode));
    final notifier = ref.read(appSettingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SettingLabel('Preferred Editing Mode'),
        Text(
          'Controls how record editors open when clicking a record in any '
          'domain list view.',
          style: _secondary(context),
        ),
        const SizedBox(height: 12),
        RadioGroup<EditingMode>(
          groupValue: mode,
          onChanged: (m) {
            if (m != null) notifier.setEditingMode(m);
          },
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RadioListTile<EditingMode>(
                key: ValueKey('settings-editing-modal'),
                value: EditingMode.modal,
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('Modal'),
                subtitle: Text(
                  'Opens the editor in a dialog overlay on top of the list '
                  'view.',
                ),
              ),
              RadioListTile<EditingMode>(
                key: ValueKey('settings-editing-full-page'),
                value: EditingMode.fullPage,
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('Full Page'),
                subtitle: Text('Navigates to a dedicated editor page.'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
