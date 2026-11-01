import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../providers.dart';
import '../settings/app_settings_notifier.dart';
import '../shell/placeholder_home_page.dart';
import 'anvil_metrics.dart';

/// Renders the core controls under the current theme and switches between
/// Dark, Light and Custom through the persisted app settings. A developer
/// screen, opened from the debug-build home page.
class ThemeGalleryPage extends ConsumerStatefulWidget {
  const ThemeGalleryPage({super.key});

  @override
  ConsumerState<ThemeGalleryPage> createState() => _ThemeGalleryPageState();
}

class _ThemeGalleryPageState extends ConsumerState<ThemeGalleryPage> {
  final _pathController = TextEditingController();
  var _chipSelected = true;
  var _switchOn = true;
  var _slider = 0.6;

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  void _load() {
    final path = _pathController.text.trim();
    if (path.isEmpty) return;
    ref.read(appSettingsProvider.notifier).setCustomThemeFile(path);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final error = ref.watch(customThemeErrorProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Anvil theme gallery')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AnvilSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _modeSection(settings, error),
            const SizedBox(height: AnvilSpacing.lg),
            Wrap(
              spacing: AnvilSpacing.lg,
              runSpacing: AnvilSpacing.lg,
              children: [
                _card('Buttons & controls', _controls()),
                _card('Type', _type()),
                _card('Status', _status()),
                _card('Inputs', _inputs()),
              ],
            ),
            const SizedBox(height: AnvilSpacing.lg),
            ForgeSettingsGroup(
              label: 'Rows',
              children: const [
                ListTile(
                  title: Text('Warrior'),
                  subtitle: Text('class-warrior'),
                  trailing: ForgeTagCapsule('Class'),
                ),
                ListTile(
                  title: Text('Iron Sword'),
                  subtitle: Text('item-iron-sword'),
                  trailing: ForgeTagCapsule(
                    'Item',
                    tone: ForgeCapsuleTone.emphasis,
                  ),
                ),
                ListTile(
                  title: Text('Goblin'),
                  subtitle: Text('npc-goblin'),
                  trailing: ForgeStatusCapsule('valid', active: true),
                ),
              ],
            ),
            const SizedBox(height: AnvilSpacing.lg),
            const ForgeEmptyState(
              icon: Icon(Icons.inbox_outlined),
              title: 'No loot tables yet',
              aside: 'Create one to start assigning drops.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeSection(AppSettings settings, String? error) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AnvilSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ForgeMonoLabel('Theme'),
            const SizedBox(height: AnvilSpacing.sm),
            ThemeModeSelector(settings: settings),
            const SizedBox(height: AnvilSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: ForgeBoxedField(
                    label: 'Theme file',
                    hint: '/path/to/theme.json',
                    controller: _pathController,
                    onSubmitted: (_) => _load(),
                  ),
                ),
                const SizedBox(width: AnvilSpacing.sm),
                SizedBox(
                  width: 120,
                  child: FilledButton(
                    onPressed: _load,
                    child: const Text('Load'),
                  ),
                ),
              ],
            ),
            if (settings.customThemePath != null) ...[
              const SizedBox(height: AnvilSpacing.sm),
              Text(
                settings.customThemePath!,
                style: ForgeType.code(color: context.forge.textTertiary),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: AnvilSpacing.sm),
              ForgeErrorCard(message: error),
            ],
          ],
        ),
      ),
    );
  }

  // Wide enough for the controls row at its natural width in any font,
  // including the fixed-pitch test font: desktop-density buttons size to
  // their label, so nothing in a Row shrinks to fit.
  Widget _card(String label, Widget child) => SizedBox(
    width: 420,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AnvilSpacing.sm),
          child: ForgeMonoLabel(label),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AnvilSpacing.md),
            child: child,
          ),
        ),
      ],
    ),
  );

  Widget _controls() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FilledButton(onPressed: () {}, child: const Text('Save')),
      const SizedBox(height: AnvilSpacing.sm),
      OutlinedButton(onPressed: () {}, child: const Text('Discard')),
      const SizedBox(height: AnvilSpacing.sm),
      Row(
        children: [
          TextButton(onPressed: () {}, child: const Text('Open editor')),
          IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
          const Spacer(),
          const FilledButton(onPressed: null, child: Text('Disabled')),
        ],
      ),
      const SizedBox(height: AnvilSpacing.sm),
      Wrap(
        spacing: AnvilSpacing.sm,
        children: [
          FilterChip(
            label: const Text('Archived'),
            selected: _chipSelected,
            onSelected: (v) => setState(() => _chipSelected = v),
          ),
          FilterChip(
            label: const Text('Active'),
            selected: !_chipSelected,
            onSelected: (v) => setState(() => _chipSelected = !v),
          ),
        ],
      ),
      Row(
        children: [
          Switch(
            value: _switchOn,
            onChanged: (v) => setState(() => _switchOn = v),
          ),
          Checkbox(
            value: _switchOn,
            onChanged: (v) => setState(() => _switchOn = v ?? false),
          ),
          Expanded(
            child: Slider(
              value: _slider,
              onChanged: (v) => setState(() => _slider = v),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _type() {
    final text = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Character Classes', style: text.titleLarge),
        Text('Stat growth', style: text.titleMedium),
        Text('Warrior', style: text.titleSmall),
        const SizedBox(height: AnvilSpacing.xs),
        Text(
          'A front-line fighter with high health and defence growth.',
          style: text.bodyMedium,
        ),
        Text('Modified 3 minutes ago', style: text.bodySmall),
        const SizedBox(height: AnvilSpacing.sm),
        const ForgeMonoLabel('Export key'),
        Text('class-warrior', style: ForgeType.code()),
        const SizedBox(height: AnvilSpacing.xs),
        const ForgeMonoLabel('Formula'),
        Text(
          'floor(base_hp + level * hp_growth)',
          style: ForgeType.code(color: context.colors.primary),
        ),
        const SizedBox(height: AnvilSpacing.xs),
        Text('1,024  ·  87  ·  3,210', style: AnvilType.numeric()),
      ],
    );
  }

  Widget _status() {
    final c = context.colors;
    final x = context.forge;
    Widget banner(String text, Color fill, Color on) => Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AnvilSpacing.md,
        vertical: AnvilSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AnvilRadii.control),
      ),
      child: Text(text, style: context.text.bodyMedium!.copyWith(color: on)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        banner('2 errors block export', c.errorContainer, c.onErrorContainer),
        const SizedBox(height: AnvilSpacing.sm),
        banner(
          '1 warning: soft-deleted reference',
          x.warningContainer,
          x.onWarningContainer,
        ),
        const SizedBox(height: AnvilSpacing.sm),
        banner('Auto-save in 4 s', x.infoContainer, x.onInfoContainer),
        const SizedBox(height: AnvilSpacing.sm),
        banner('Saved', x.successContainer, x.onSuccessContainer),
        const SizedBox(height: AnvilSpacing.md),
        Wrap(
          spacing: AnvilSpacing.sm,
          runSpacing: AnvilSpacing.sm,
          children: const [
            ForgeTagCapsule('ability'),
            ForgeTagCapsule('recipe', tone: ForgeCapsuleTone.emphasis),
            ForgeStatusCapsule('saved', active: true),
            ForgeStatusCapsule('dirty'),
          ],
        ),
      ],
    );
  }

  Widget _inputs() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: const [
      ForgeBoxedField(label: 'Display name', hint: 'Warrior'),
      SizedBox(height: AnvilSpacing.md),
      ForgeBoxedField(
        label: 'Export key',
        hint: 'class-warrior',
        errorText: 'Export key is already in use',
      ),
      SizedBox(height: AnvilSpacing.md),
      TextField(decoration: InputDecoration(labelText: 'Description')),
    ],
  );
}
